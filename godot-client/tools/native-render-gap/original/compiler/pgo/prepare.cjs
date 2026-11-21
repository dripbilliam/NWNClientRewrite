'use strict';
// Run only after the root releases its measured-client CPU reservation.
const fs=require('node:fs'),path=require('node:path'),cp=require('node:child_process'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const project=path.resolve(__dirname,'../../../../..'),hash=f=>crypto.createHash('sha256').update(fs.readFileSync(f)).digest('hex');
const [label,buildArg,expectedBaseline]=process.argv.slice(2);assert(/^[a-z0-9-]+$/.test(label||''),'Fresh label required');assert(buildArg&&/^[0-9a-f]{64}$/.test(expectedBaseline||''),'Root-selected baseline build directory and exact SHA required');
const out=path.join(project,'.cache/native-render-gap/original/compiler/pgo',label);assert(!fs.existsSync(out),'Retain prior evidence');fs.mkdirSync(out,{recursive:true});
const build=path.resolve(buildArg);assert(build.startsWith(path.join(project,'.cache/native-render-gap/engine/build-')),'Expected private retained build');const invocationFile=path.join(build,'invocation.json'),invocation=JSON.parse(fs.readFileSync(invocationFile,'utf8').replace(/^\ufeff/,'')),baselineReceiptFile=path.join(build,'receipt.json'),baselineReceipt=JSON.parse(fs.readFileSync(baselineReceiptFile,'utf8').replace(/^\ufeff/,''));assert(baselineReceipt.exitCode===0&&baselineReceipt.sourceUnchanged===true);assert.equal(baselineReceipt.outputSha256,expectedBaseline);
const source=invocation.source,compiler=invocation.compiler,python=invocation.python,toolDir=path.dirname(compiler),baseline=path.join(build,'godot.windows.template_release.x86_64.exe');
assert.equal(hash(baseline),expectedBaseline);assert.equal(hash(compiler),invocation.compilerSha256);assert.equal(hash(python),invocation.pythonSha256);
const selected=['dictionary','variant'].map(name=>({name,sourceFile:path.join(source,'core/variant',name+'.cpp'),object:path.join(source,'bin/obj/core/variant',name+'.windows.template_release.x86_64.o')}));
const profile=path.join(out,'capture-profile.py'),commandFile=path.join(out,'compile-command.json'),map=path.join(out,'capture-unused.map');
const profileCode=`def _capture_pgo(_targets, _sources, _env):
    import json
    from pathlib import Path
    import SCons.Tool.compilation_db as db
    selected = set(${JSON.stringify(selected.map(x=>x.object))})
    rows = []
    for target, source, env, action in db.__COMPILATION_DB_ENTRIES:
        if target.get_abspath() not in selected:
            continue
        commands = env.subst_list("$CXXCOM", target=[target], source=[source], overrides={"TEMPFILE": db.CompDBTEMPFILE})
        rows.append(dict(target=target.get_abspath(), source=source.get_abspath(), arguments=[[str(a) for a in command] for command in commands]))
    if len(rows) != 2:
        raise RuntimeError("Expected exactly two targeted PGO compile rows: " + str(len(rows)))
    with open(${JSON.stringify(commandFile)}, "x", encoding="utf-8") as stream:
        json.dump(dict(version=1, sourceOnly=True, directory=str(Path.cwd()), rows=rows), stream, indent=2)
__import__("SCons.Tool.compilation_db", fromlist=["write_compilation_db"]).write_compilation_db = _capture_pgo
`;
fs.writeFileSync(profile,profileCode,{flag:'wx'});
const actions=[];function run(name,args){const started=Date.now(),r=cp.spawnSync(python,args,{cwd:source,windowsHide:true,encoding:'utf8',timeout:60000,maxBuffer:8*1024*1024,env:{...process.env,PATH:toolDir+';'+process.env.PATH}});fs.writeFileSync(path.join(out,name+'.stdout.log'),r.stdout||'',{flag:'wx'});fs.writeFileSync(path.join(out,name+'.stderr.log'),r.stderr||'',{flag:'wx'});actions.push({name,tool:python,args,cwd:source,exit:r.status,error:r.error?.message,wallMs:Date.now()-started});assert.equal(r.status,0,name+' failed: '+r.stderr);return r.stdout;}
let result={version:1,success:false,out,source,baseline,baselineSha256:expectedBaseline,baselineReceiptFile,baselineReceiptSha256:hash(baselineReceiptFile),build,compiler,compilerSha256:hash(compiler),python,pythonSha256:hash(python),invocationFile,invocationSha256:hash(invocationFile),selected,profile,commandFile,actions};
try{
 const captureArgs=[...invocation.arguments,'profile='+profile,'compiledb=yes','compiledb_gen_only=yes','verbose=yes',...selected.map(x=>path.relative(source,x.object).replaceAll('\\','/')),'--dry-run'];
 run('capture',captureArgs);const command=JSON.parse(fs.readFileSync(commandFile));assert.equal(command.rows.length,2);
 for(const item of selected){const row=command.rows.find(x=>path.resolve(x.target)===item.object);assert(row&&row.arguments.length===1);assert.equal(path.resolve(row.source),item.sourceFile);const argv=row.arguments[0];assert.equal(argv[0],'x86_64-w64-mingw32-g++');for(const flag of['-O3','-ffp-contract=off','-fno-exceptions','-c'])assert(argv.includes(flag),'Missing baseline '+flag);assert(!argv.some(x=>/^-flto|fast-math|Ofast|unsafe-math|fno-gcse|fprofile-/.test(x)));item.sourceSha256=hash(item.sourceFile);item.objectSha256=hash(item.object);}
 const linkText=run('link-dry-run',[...invocation.arguments,'linkflags=-Wl,-Map='+path.relative(source,map).replaceAll('\\','/'),'verbose=yes','bin/godot.windows.template_release.x86_64.exe','--dry-run']);
 const lines=linkText.split(/\r?\n/),commands=lines.filter(x=>x.startsWith('x86_64-w64-mingw32-g++ '));assert.equal(commands.length,1,'Dry-run must contain only main link');assert(commands[0].startsWith('x86_64-w64-mingw32-g++ -o '));assert(!/["'\t]/.test(commands[0]),'Unexpected quoted shell argv');const linkArgs=commands[0].split(/ +/).slice(1);assert(!linkArgs.includes('-c'));assert(linkArgs.some(x=>x.startsWith('-Wl,-Map=')));
 const archive=path.join(source,'bin/obj/core/libcore.windows.template_release.x86_64.a');assert.equal(linkArgs.filter(x=>path.resolve(source,x)===archive).length,1);assert.equal(fs.readFileSync(archive).toString('ascii',0,8),'!<thin>\n');
 Object.assign(result,{archive,archiveSha256:hash(archive),commandSha256:hash(commandFile),profileSha256:hash(profile),linkArgs,linkLog:path.join(out,'link-dry-run.stdout.log'),linkLogSha256:hash(path.join(out,'link-dry-run.stdout.log')),scope:'Metadata-only selected compilation DB expansion and main-link dry-run. No compiler, archive or link executed. Root-selected exact source/build epoch, strict original flags, no VM GCSE change.'});
 assert.equal(hash(baseline),expectedBaseline);for(const item of selected){assert.equal(hash(item.object),item.objectSha256);assert.equal(hash(item.sourceFile),item.sourceSha256);}result.success=true;
}catch(error){result.error=error.stack;process.exitCode=1;}
fs.writeFileSync(path.join(out,'plan.json'),JSON.stringify(result,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({success:result.success,out,planSha256:hash(path.join(out,'plan.json')),error:result.error}));
