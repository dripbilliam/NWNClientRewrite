// Sole allocated short functional graphics lane. No native build/server/input
// automation. All pointer/key events belong to an isolated SubViewport fixture.
import fs from 'node:fs/promises';import path from 'node:path';import {createHash} from 'node:crypto';import {spawn} from 'node:child_process';import {fileURLToPath} from 'node:url';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..'),[label,chosenEntry]=process.argv.slice(2);
const entry=chosenEntry??'native_parity_highlight_render_test.gd';
if(!['native_parity_highlight_render_test.gd','native_parity_highlight_textured_render_test.gd','native_parity_highlight_registry_actor_render_test.gd'].includes(entry))throw Error('Only the owned allocated highlight graphical fixture may run');
const actualActor=entry==='native_parity_highlight_registry_actor_render_test.gd';
const checkOnly=process.argv.slice(4).includes('--check-only');
const variantArg=process.argv.slice(4).find(value=>value.startsWith('--bounds-variant='));
const boundsVariant=variantArg?.slice('--bounds-variant='.length)??null;
if(boundsVariant!==null&&(!actualActor||!['attribution','inline','aabb','kernel'].includes(boundsVariant)))throw Error('Only explicit owned actor-fixture variants may be staged');
const kernelLabel=process.argv.slice(4).find(value=>value.startsWith('--kernel-build='))?.slice('--kernel-build='.length)??null;
if((boundsVariant==='kernel')!==Boolean(kernelLabel)||kernelLabel&&!/^highlight-kernel-build-v[0-9]+$/.test(kernelLabel))throw Error('Kernel variant requires one explicit private build label');
const screenArg=process.argv.slice(4).find(value=>value.startsWith('--screen='))?.slice('--screen='.length)??'2';if(!/^[0-8]$/.test(screenArg))throw Error('Explicit screen index0..8 required');const screen=Number(screenArg);
if(!/^[a-z0-9-]+$/.test(label??''))throw Error('Fresh explicit label required');
const folder=path.join(project,'.cache/native-140fps/particles-agent',label),copy=path.join(folder,'project');await fs.mkdir(folder,{recursive:false});await fs.mkdir(copy);
const hash=b=>createHash('sha256').update(b).digest('hex'),descriptorFile=path.join(project,'.cache/native-140fps/render-agent/engine-builtin-light-v2/engine-descriptor.json'),descriptorBytes=await fs.readFile(descriptorFile),engine=JSON.parse(descriptorBytes).engines.candidate;
if(engine.sha256!=='ce2d36407d0a6107a3076a00faf7d9f9dae185c86994ccea8dfd7e450c50f12a'||hash(await fs.readFile(engine.path))!==engine.sha256)throw Error('Pinned engine mismatch');
const pins=[],seen=new Set(),omittedNativeDescriptors=[];async function stage(relative){
 if(seen.has(relative))return;seen.add(relative);
 if(relative.startsWith('native/')&&relative.endsWith('.gdextension')){omittedNativeDescriptors.push(relative);return;}
 if(relative.includes('..')||path.isAbsolute(relative)||!['.gd','.gdshader','.json'].includes(path.extname(relative)))throw Error('Unexpected source closure: '+relative);
 let bytes=await fs.readFile(path.join(project,relative));const sourceSha256=hash(bytes);let variantSource=null;
 if(boundsVariant!==null&&boundsVariant!=='kernel'&&relative==='tools/native_parity/highlighting/native_highlight_bounds_textured.gd'){
  if(sourceSha256!=='7bbcbf8d0ac6c9ee3196e68f0e1664d729fa61c21dec1b82e9bac80438b344f9')throw Error('Frozen textured parent differs');
  variantSource=path.join(project,'tools/native_parity/highlighting/candidates/bounds_'+boundsVariant+'.gd');bytes=await fs.readFile(variantSource);
 }
 if(boundsVariant==='kernel'&&relative==='systems/native_render/selection_highlight.gd'){
  const before='const Bounds=preload("res://tools/native_parity/highlighting/native_highlight_bounds_textured.gd")',after='const Bounds=preload("res://tools/native_parity/highlighting/native_highlight_bounds_kernel.gd")';
  const code=bytes.toString('utf8');if(code.split(before).length!==2)throw Error('Actual selection binding differs');bytes=Buffer.from(code.replace(before,after));
 }
 const text=bytes.toString('utf8'),dest=path.join(copy,relative);await fs.mkdir(path.dirname(dest),{recursive:true});await fs.writeFile(dest,bytes,{flag:'wx'});pins.push({relative,sourceSha256,variantSource,sha256:hash(bytes),bytes:bytes.length});
 for(const m of text.matchAll(/(?:preload|load)\(\s*["']res:\/\/([^"']+)["']\s*\)|extends\s+["']res:\/\/([^"']+)["']|FileAccess\.get_file_as_string\(\s*["']res:\/\/([^"']+)["']\s*\)/g))await stage(m[1]??m[2]??m[3]);
}
await stage('tests/'+entry);await fs.mkdir(path.join(copy,'.godot'));await fs.writeFile(path.join(copy,'.godot/global_script_class_cache.cfg'),'list=[]\n',{flag:'wx'});
const nativeInputs=[];
if(actualActor){
 const parent=path.join(project,'.cache/native-140fps/root/drive-envelope-fenced-v1'),manifest=await fs.readFile(path.join(parent,'manifest.json'));
 if(hash(manifest)!=='cce71cea6e3ae8116d4747c97f1e161eed9350cd85386dc372578d9f6d4cdfc1')throw Error('Approved native parent differs');
 for(const relative of ['native/particle_kernel.gdextension','.cache/native-kernel/nwn-particle-kernel.dll']){
  const source=path.join(parent,'project',relative),bytes=await fs.readFile(source),target=path.join(copy,relative),sha256=hash(bytes);
  if(relative.endsWith('.dll')&&sha256!=='672bd24ae23f0be06bb209bc40ec5083fbe8ac14e92b2dd6b10f836255a840ea')throw Error('Approved native DLL differs');
  await fs.mkdir(path.dirname(target),{recursive:true});await fs.writeFile(target,bytes,{flag:'wx'});nativeInputs.push({relative,source,sha256,bytes:bytes.length});
 }
}
if(kernelLabel){
 const file=path.join(project,'.cache/native-presentation-parity/particles-agent',kernelLabel,'build.json'),build=JSON.parse(await fs.readFile(file));
 if(build.exit_code!==0||build.source_changed.length)throw Error('Isolated highlight build did not pass');
 for(const pin of build.sources)if(hash(await fs.readFile(pin.source))!==pin.sha256||hash(await fs.readFile(pin.file))!==pin.sha256)throw Error('Highlight kernel source differs');
 for(const [source,relative,expected]of[[build.binary,'.cache/highlight-kernel/nwn-highlight-geometry.dll',build.binary_sha256],[build.descriptor,'native/highlight_geometry.gdextension',build.descriptor_sha256]]){
  const bytes=await fs.readFile(source),sha256=hash(bytes);if(sha256!==expected)throw Error('Highlight kernel artifact differs');const target=path.join(copy,relative);await fs.mkdir(path.dirname(target),{recursive:true});await fs.writeFile(target,bytes,{flag:'wx'});nativeInputs.push({relative,source,sha256,bytes:bytes.length});
 }
}
const user=path.join(folder,'userdata');await fs.mkdir(user);const report=path.join(folder,'report.json'),install=path.resolve(project,'../../FullDecomp/NwnRootInstall');
const configuration='config_version=5\n[application]\nconfig/name="NWN isolated bounds highlight"\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="CodexParity/'+label+'"\n[display]\nwindow/size/viewport_width=1200\nwindow/size/viewport_height=900\nwindow/size/no_focus=true\nwindow/size/initial_position_type=3\nwindow/size/initial_screen='+screen+'\nwindow/vsync/vsync_mode=1\n[rendering]\nrenderer/rendering_method="forward_plus"\nrenderer/rendering_method.mobile="forward_plus"\ndriver/threads/thread_model=2\n';await fs.writeFile(path.join(copy,'project.godot'),configuration,{flag:'wx'});
const proof={version:1,label,project:copy,sourceProject:project,pins,omittedNativeDescriptors,nativeInputs,checkOnly,boundsVariant,engine:{...engine,descriptor:descriptorFile,descriptorSha256:hash(descriptorBytes)},projectSha256:hash(Buffer.from(configuration)),install,report,sourceProjectImports:0,nativeBuilds:0,nativeOutputsCopied:nativeInputs.length,serverConnections:0,performanceClaim:false,configuredBeforeWindow:{screen,noFocus:true,mouseCapture:false,renderThread:2}};
await fs.writeFile(path.join(folder,'staged.json'),JSON.stringify(proof,null,2)+'\n',{flag:'wx'});
const args=[...(checkOnly?['--headless','--check-only']:[]),'--path',copy,'--screen',String(screen),'--log-file',path.join(folder,'engine.log'),'--script','res://tests/'+entry,'--',actualActor?'--particle-kernel=compiled':'--particle-kernel=gd',...(actualActor?['--model-storage=native']:[]),...(kernelLabel?['--highlight-kernel=compiled']:[]),'--expected-screen='+screen,'--report='+report,'--install='+install];
const child=spawn(engine.path,args,{cwd:copy,windowsHide:true,env:{...process.env,APPDATA:user,LOCALAPPDATA:user,NWN_PARITY_UI_TEST_DIR:user}});console.log(JSON.stringify({started:true,pid:child.pid,folder,args,sourceFiles:pins.length}));let stdout='',stderr='',timedOut=false;child.stdout.on('data',v=>stdout+=v);child.stderr.on('data',v=>stderr+=v);const timeout=setTimeout(()=>{timedOut=true;child.kill();},150000);const closed=await new Promise((resolve,reject)=>{child.on('error',reject);child.on('close',(code,signal)=>resolve({code,signal}));});clearTimeout(timeout);await fs.writeFile(path.join(folder,'stdout.log'),stdout);await fs.writeFile(path.join(folder,'stderr.log'),stderr);
proof.pid=child.pid;proof.args=args;Object.assign(proof,closed,{timedOut});proof.sourceChanged=[];proof.privateChanged=[];for(const pin of pins){if(hash(await fs.readFile(path.join(project,pin.relative)))!==(pin.sourceSha256??pin.sha256))proof.sourceChanged.push(pin.relative);if(hash(await fs.readFile(path.join(copy,pin.relative)))!==pin.sha256)proof.privateChanged.push(pin.relative);}
for(const pin of pins){if(pin.variantSource&&hash(await fs.readFile(pin.variantSource))!==pin.sha256)proof.sourceChanged.push(pin.variantSource);}
for(const pin of nativeInputs){if(hash(await fs.readFile(pin.source))!==pin.sha256)proof.sourceChanged.push(pin.source);if(hash(await fs.readFile(path.join(copy,pin.relative)))!==pin.sha256)proof.privateChanged.push(pin.relative);}
proof.reportAvailable=false;try{proof.report=JSON.parse(await fs.readFile(report));proof.reportAvailable=true;}catch{}proof.engineErrors=/SCRIPT ERROR:|^ERROR:|ObjectDB.*leak|resources still in use/m.test(stdout+'\n'+stderr);proof.success=closed.code===0&&!timedOut&&(checkOnly||proof.report?.success===true)&&!proof.sourceChanged.length&&!proof.privateChanged.length&&!proof.engineErrors;await fs.writeFile(path.join(folder,'process.json'),JSON.stringify(proof,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({folder,...closed,timedOut,checks:proof.report?.checks,failures:proof.report?.failures,engineErrors:proof.engineErrors,sourceChanged:proof.sourceChanged,privateChanged:proof.privateChanged,success:proof.success}));process.exitCode=proof.success?0:1;
