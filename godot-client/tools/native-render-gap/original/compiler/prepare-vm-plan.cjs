'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),root=path.resolve(__dirname,'../../../..'),sha=b=>crypto.createHash('sha256').update(b).digest('hex');
const label=process.argv[2]||'a';if(!/^[a-z0-9-]+$/.test(label))throw Error('Label');const out=path.join(root,'.cache/native-render-gap/original/compiler/vm-no-gcse-'+label);if(fs.existsSync(out))throw Error('Preserve proposal');fs.mkdirSync(out,{recursive:true});
const invocationFile=path.join(root,'.cache/native-render-gap/engine/build-1794148176296/invocation.json'),invocation=JSON.parse(fs.readFileSync(invocationFile)),source=invocation.source,objectRelative='bin/obj/modules/gdscript/gdscript_vm.windows.template_release.x86_64.o',object=path.join(source,objectRelative),archive=path.join(source,'bin/obj/modules/libmodule_gdscript.windows.template_release.x86_64.a'),commandFile=path.join(out,'compile-command.json'),profile=path.join(out,'capture-profile.py');
// Use the pinned built-in compilation DB emitter and its generation-only
// branch, replacing its writer only in this private Python process. Emit only
// the requested exact VM argument vector to our private output, never the
// active source's compile_commands.json. No compiler/builder action executes.
const python=`def _capture_vm(_targets, _sources, _env, _target=${JSON.stringify(object)}, _output=${JSON.stringify(commandFile)}):
    import json
    from pathlib import Path
    import SCons.Tool.compilation_db as compilation_db
    from SCons.Action import _string_from_cmd_list
    rows = []
    for db_target, db_source, db_env, db_action in compilation_db.__COMPILATION_DB_ENTRIES:
        if Path(db_target.get_abspath()) != Path(_target):
            continue
        commands = db_env.subst_list("$CXXCOM", target=[db_target], source=[db_source], overrides={"TEMPFILE": compilation_db.CompDBTEMPFILE})
        rows.append(dict(target=db_target.get_abspath(), source=db_source.get_abspath(), arguments=[[str(a) for a in command] for command in commands], display=[_string_from_cmd_list(command) for command in commands]))
    if len(rows) != 1:
        raise RuntimeError("Expected exactly one VM compilation DB row: " + str(len(rows)))
    result = dict(version=1, sourceOnly=True, directory=str(Path.cwd()), rows=rows, scope="Exact pinned SCons built-in compilation DB environment expansion only; no compiler action or active source write.")
    with open(_output, "x", encoding="utf-8") as stream:
        json.dump(result, stream, indent=2)
__import__("SCons.Tool.compilation_db", fromlist=["write_compilation_db"]).write_compilation_db = _capture_vm
`;
fs.writeFileSync(profile,python,{flag:'wx'});const archiveBytes=fs.readFileSync(archive),plan={version:1,sourceOnly:true,out,source,invocationFile,invocationSha256:sha(fs.readFileSync(invocationFile)),compiler:invocation.compiler,compilerSha256:invocation.compilerSha256,python:invocation.python,pythonSha256:invocation.pythonSha256,object,objectSha256:sha(fs.readFileSync(object)),sourceFile:path.join(source,'modules/gdscript/gdscript_vm.cpp'),sourceSha256:sha(fs.readFileSync(path.join(source,'modules/gdscript/gdscript_vm.cpp'))),archive,archiveSha256:sha(archiveBytes),archiveMagic:archiveBytes.toString('ascii',0,8),profile,profileSha256:sha(python),commandFile,arguments:[...invocation.arguments,'profile='+profile,'compiledb=yes','compiledb_gen_only=yes','verbose=yes',objectRelative,'--dry-run'],delta:['-fno-gcse only for gdscript_vm.cpp'],futureSteps:['Inspect exact captured argument vector and verify -O3/-ffp-contract=off/-fno-exceptions and exactly one original source/object.','Enumerate thin archive members to absolute original paths in exact order; hash them before/after, never copy a thin archive with relative references.','Create a PRIVATE NORMAL control archive with the original same-order member bytes and link a private control EXE using the retained exact V8 main link recipe. Require all loadable bytes match immutable V8.','Compile exactly one VM TU into a private same-basename object using captured argv plus -fno-gcse. No other flag/source change.','Create a private normal candidate archive with only that VM member substituted. Reuse all other link args and preserve EXE basename, private output/map paths.','Re-link the unmodified private control after candidate build and verify identical control code, plus unchanged original object/member hashes; reject any concurrent build/source drift.','Run actual VM/scene/callback/headless and graphical correctness differential before matched FPS. New images/maps/RVAs have their own exact hashes; never symbolize with V8 maps.'],status:'Capture is metadata-only; actual VM compile/private archive/link requires parent review and resource slot. Full-engine LTO is unavailable in this pinned --disable-lto compiler.'};fs.writeFileSync(path.join(out,'plan.json'),JSON.stringify(plan,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({out,sha256:sha(fs.readFileSync(path.join(out,'plan.json'))),captureArguments:plan.arguments}));
