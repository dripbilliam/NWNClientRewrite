'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),{spawnSync}=require('node:child_process');
const project=path.resolve(__dirname,'../..'),[label,variant,outputLabel]=process.argv.slice(2);
if(!/^[a-z0-9-]+$/.test(label??'')||!['control','candidate'].includes(variant)||!/^[a-z0-9-]+$/.test(outputLabel??''))throw Error('Explicit experiment, variant and fresh output label required');
const root=path.join(project,'.cache/native-presentation-parity/root/fps-max-v1','particle-loop-'+label),folder=path.join(root,variant);
const manifestFile=path.join(folder,'test-manifest.json'),m=JSON.parse(fs.readFileSync(manifestFile));
const hash=b=>crypto.createHash('sha256').update(b).digest('hex');
const engineMode=process.argv[5]??'verified';if(!['verified','official'].includes(engineMode))throw Error('Unsupported engine mode');
const engine=engineMode==='official'?{executable:path.join(project,'.tools/Godot_v4.7.2-stable_win64.exe'),executableSha256:'ab1824f85bfd8e0e4128182c000c4003a3e042245b2967848d089b2a04b22424'}:m.engine;
// The editor also enforces test-script warnings. Keep frozen graphical stages
// intact and use the explicitly typed external test fixture for this mode.
const compatibilityFixture=engineMode==='official'?{file:path.join(__dirname,'bookkeeping_test.gd'),sha256:hash(fs.readFileSync(path.join(__dirname,'bookkeeping_test.gd')))}:null;
function verify(){for(const pin of m.pins)if(hash(fs.readFileSync(path.join(m.project,pin.relative)))!==pin.sha256)throw Error('Private stage changed: '+pin.relative);if(hash(fs.readFileSync(engine.executable))!==engine.executableSha256||hash(fs.readFileSync(m.oracle.file))!==m.oracle.sha256||compatibilityFixture&&hash(fs.readFileSync(compatibilityFixture.file))!==compatibilityFixture.sha256)throw Error('Engine/oracle/compatibility fixture changed');}
verify();const output=path.join(folder,'focused-'+outputLabel);if(fs.existsSync(output))throw Error('Existing evidence preserved');fs.mkdirSync(output);
const scripts=['tools/native-particle-loop/bookkeeping_test.gd','tests/native_particle_presentation_test.gd','tests/native_particle_presentation_order_test.gd','tests/native_particle_presentation_lifetime_test.gd','tests/native_particle_presentation_scene_test.gd','tests/native_particle_presentation_profile_split_test.gd'];
const results=[];
for(const script of scripts){
 const name=path.basename(script,'.gd'),dir=path.join(output,name);fs.mkdirSync(dir);const report=path.join(dir,'report.json'),log=path.join(dir,'engine.log');
 const resource=compatibilityFixture&&script==='tools/native-particle-loop/bookkeeping_test.gd'?compatibilityFixture.file:'res://'+script;
 const child=spawnSync(engine.executable,['--headless','--path',m.project,'--log-file',log,'--script',resource,'--','--report='+report],{cwd:m.project,windowsHide:true,encoding:'utf8',timeout:60000,maxBuffer:4*1024*1024,env:{...process.env,NWN_PARTICLE_KERNEL:'compiled',APPDATA:path.join(dir,'appdata'),LOCALAPPDATA:path.join(dir,'localappdata')}});
 fs.writeFileSync(path.join(dir,'stdout.log'),child.stdout??'',{flag:'wx'});fs.writeFileSync(path.join(dir,'stderr.log'),child.stderr??'',{flag:'wx'});
 const text=[child.stdout,child.stderr,fs.existsSync(log)?fs.readFileSync(log,'utf8'):''].join('\n');const errors=text.split(/\r?\n/).filter(line=>/SCRIPT ERROR|Parse Error|(?:^|\s)ERROR:|WARNING:|ObjectDB.*leak|resources still in use|CrashHandler|Unhandled exception/.test(line));
 let value;try{value=JSON.parse(fs.readFileSync(report));}catch{}
 const row={script,success:child.status===0&&!child.error&&errors.length===0&&value?.success===true,exit:child.status,error:child.error?.message??null,errors,checks:value?.checks,failures:value?.failures,report,reportSha256:value?hash(fs.readFileSync(report)):null};results.push(row);console.log(JSON.stringify(row));
 // A failed case is terminal for this run, not an excuse to overwrite it.
 if(!row.success)break;
}
verify();const result={success:results.length===scripts.length&&results.every(r=>r.success),variant,engineMode,engine,compatibilityFixture,manifest:{file:manifestFile,sha256:hash(fs.readFileSync(manifestFile))},results,checks:results.reduce((n,r)=>n+(r.checks??0),0),graphicalProcesses:0,serverConnections:0,scope:'Focused private native particle correctness only; FPS and normal launcher integration remain unproven'};
fs.writeFileSync(path.join(output,'summary.json'),JSON.stringify(result,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({success:result.success,variant,cases:results.length,checks:result.checks}));if(!result.success)process.exitCode=1;
