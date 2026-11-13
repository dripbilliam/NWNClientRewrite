const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),{spawnSync}=require('node:child_process');
const project=path.resolve(__dirname,'../../../..'),sha=b=>crypto.createHash('sha256').update(b).digest('hex');
const id=process.argv[2]??'light-live-functional-a';if(!/^[a-z0-9-]+$/.test(id))throw Error('Fresh private fixture label required');
const directory=path.join(project,'.cache/native-render-gap/scene',id),renderer=path.join(directory,'project');if(fs.existsSync(directory))throw Error('Existing fixture frozen');fs.mkdirSync(renderer,{recursive:true});
const pins=[];function put(relative,bytes,origin){const p=path.join(renderer,relative);fs.mkdirSync(path.dirname(p),{recursive:true});fs.writeFileSync(p,bytes,{flag:'wx'});pins.push({relative,origin,sha256:sha(bytes)});}
const pending=['systems/native_render/model_point_light.gd'];while(pending.length){const relative=pending.shift();if(pins.some(x=>x.relative===relative))continue;const input=path.join(project,relative),bytes=fs.readFileSync(input);put(relative,bytes,input);for(const m of bytes.toString().matchAll(/(?:preload|load)\("res:\/\/([^"\n]+)"\)/g))pending.push(m[1]);}
put('fixture.gd',fs.readFileSync(path.join(__dirname,'fixture.gd')),path.join(__dirname,'fixture.gd'));
put('tests/native_perf140_render_builtin_light_registry_test.gd',fs.readFileSync(path.join(project,'tests/native_perf140_render_builtin_light_registry_test.gd')),'Current unchanged539check builtin/direct-extension oracle');
const source=path.join(project,'.cache/native-140fps/render-agent/engine-font-atlas-ownership-v1/source/thirdparty/certs/ca-bundle.crt');put('fixture-ca.crt',fs.readFileSync(source),source);
put('.godot/global_script_class_cache.cfg',Buffer.from('list=[]\n'),'Empty cache');
put('project.godot',Buffer.from('config_version=5\n[application]\nconfig/name="Live light fields functional"\n[network]\ntls/certificate_bundle_override="res://fixture-ca.crt"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n'),'No autoloads/session');
// The legacy registry exists only in the retained private diagnostic DLL,
// not the installed production DLL. Reuse its exact frozen independent oracle.
const oracleManifestFile=path.join(project,'.cache/native-140fps/root/lease-scene-diagnostics-v1/manifest.json'),oracleManifest=JSON.parse(fs.readFileSync(oracleManifestFile));
const oraclePin=oracleManifest.pins.find(x=>x.relative==='.cache/native-kernel/nwn-particle-kernel.dll');
const dll=path.join(oracleManifest.project,oraclePin.relative),dllHash=sha(fs.readFileSync(dll));
if(dllHash!==oraclePin.sha256||dllHash!=='672bd24ae23f0be06bb209bc40ec5083fbe8ac14e92b2dd6b10f836255a840ea')throw Error('Retained oracle extension changed');
const descriptorInput=path.join(oracleManifest.project,'native/particle_kernel.gdextension');
const descriptor=fs.readFileSync(descriptorInput,'utf8').replace('res://.cache/native-kernel/nwn-particle-kernel.dll',dll.replaceAll('\\','/'));
put('native/oracle.gdextension',Buffer.from(descriptor),'Private descriptor to exact accepted DLL');put('.godot/extension_list.cfg',Buffer.from('res://native/oracle.gdextension\n'),'Private explicit oracle enrollment');
const engine=path.join(project,'.tools/Godot_v4.7.2-stable_win64.exe'),args=['--headless','--path',renderer,'--script','res://fixture.gd','--check-only'];const appdata=path.join(directory,'parse-appdata'),localdata=path.join(directory,'parse-localappdata');fs.mkdirSync(appdata);fs.mkdirSync(localdata);
const r=spawnSync(engine,args,{encoding:'utf8',windowsHide:true,timeout:30000,maxBuffer:1024*1024,env:{...process.env,APPDATA:appdata,LOCALAPPDATA:localdata}});fs.writeFileSync(path.join(directory,'parse.stdout.log'),r.stdout??'',{flag:'wx'});fs.writeFileSync(path.join(directory,'parse.stderr.log'),r.stderr??'',{flag:'wx'});
const parse={success:r.status===0&&!/SCRIPT ERROR|ERROR:|Parse Error|Compile Error|leaked|still in use/.test((r.stdout??'')+(r.stderr??'')),code:r.status,gpu:false};const manifest={version:1,directory,renderer,pins,oracle:{dll,sha256:dllHash,manifest:oracleManifestFile,manifestSha256:sha(fs.readFileSync(oracleManifestFile))},parse,scope:'Private exact current canonical facade/palette; original reflected/unclaimed builtin owner versus cold-enrolled typed owner; retained independent legacy DLL direct oracle also included; no normal project writes/GPU/FPS'};fs.writeFileSync(path.join(directory,'manifest.json'),JSON.stringify(manifest,null,2),{flag:'wx'});console.log(JSON.stringify({directory,parse,files:pins.length},null,2));process.exitCode=parse.success?0:1;
