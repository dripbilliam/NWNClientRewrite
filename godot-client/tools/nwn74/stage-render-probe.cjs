'use strict';
// Stage a private original-source replay. The accepted executable and project
// are read-only; only the staged FrameProfile reads the completed render frame.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../..');
const label=process.argv[2];
assert(/^[a-z0-9][a-z0-9-]{0,40}$/.test(label??''),'Fresh label required');
const scope=path.join(root,'.cache/nwn74',label),input=path.join(scope,'input');
assert(!fs.existsSync(scope),'Preserve existing private stage');
const read=file=>fs.readFileSync(file),sha=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
const baseFile=path.join(root,'.cache/native-presentation-parity/production-replay/nwn62-completion-tail-c/production-selection.json');
const base=JSON.parse(read(baseFile));
assert(base.complete&&base.production&&base.pins.length>2000);
assert.equal(base.renderCore.engineSha256,'753b3e188068efaf865bda3abd6322ebe44e3a98ef2f5d199c8af1a78624c98b');
const receiptFile=path.join(root,'.cache/nwn74/engine-build-b/receipt.json'),receipt=JSON.parse(read(receiptFile));
assert(receipt.success&&receipt.originalUntouched&&receipt.binary.sha256==='35e47e75fb71dac4ae91140026d1b333988c1546e8033f86a8624702b12da64f');
assert.equal(sha(read(receipt.binary.file)),receipt.binary.sha256);
const profileRelative='systems/native_render/frame_profile.gd';
const profileSource=path.join(base.sourceProject,profileRelative);
let profile=read(profileSource).toString('utf8');
assert.equal(sha(Buffer.from(profile)),'42d7585cd745c944a6a907dc11516994d639764d638cf1d7f7b5b041a6bcc9d0');
function replaceOnce(before,after){assert.equal(profile.split(before).length,2,'Profile seam missing or duplicated');profile=profile.replace(before,after);}
replaceOnce('var render_boundary_count:=0','var render_boundary_count:=0\nvar render_probe_available:=false\nvar render_probe_frame_id:=-1');
replaceOnce('\tset_enabled(true)\nfunc set_enabled', '\trender_probe_available=ClassDB.class_exists("NwnFrameProbe") and ClassDB.class_has_method("NwnFrameProbe","completed_frame") and ClassDB.class_has_method("NwnFrameProbe","set_enabled")\n\tset_enabled(true)\nfunc set_enabled');
replaceOnce('\tenabled=value; rows.clear();', '\tif render_probe_available: ClassDB.class_call_static("NwnFrameProbe","set_enabled",value)\n\trender_probe_frame_id=-1\n\tenabled=value; rows.clear();');
replaceOnce('var row: Dictionary=phases.duplicate() if phase_frame==Engine.get_process_frames() else {}','var row: Dictionary=phases.duplicate() if phase_frame==Engine.get_process_frames() else {}\n\tif render_probe_available:\n\t\tvar completed: Dictionary=ClassDB.class_call_static("NwnFrameProbe","completed_frame")\n\t\tvar completed_id:=int(completed.get("frame_id",-1))\n\t\tif bool(completed.get("available",false)) and completed_id>render_probe_frame_id:\n\t\t\trender_probe_frame_id=completed_id\n\t\t\tfor key in completed:\n\t\t\t\tif completed[key] is int and key!="frame_id" and key!="writer_thread": row["rt_"+str(key)]=completed[key]');
replaceOnce('\tif is_instance_valid(viewport): RenderingServer.viewport_set_measure_render_time(viewport.get_viewport_rid(),false)','\tif render_probe_available: ClassDB.class_call_static("NwnFrameProbe","set_enabled",false)\n\tif is_instance_valid(viewport): RenderingServer.viewport_set_measure_render_time(viewport.get_viewport_rid(),false)');
const profileBytes=Buffer.from(profile),profileSha=sha(profileBytes);
function target(basePath,relative){assert(relative&&!path.isAbsolute(relative)&&!relative.split(/[\\/]/).some(part=>!part||part==='.'||part==='..'));const file=path.resolve(basePath,relative);assert(!path.relative(basePath,file).startsWith('..'));return file;}
fs.mkdirSync(input,{recursive:true});const pins=[];
for(const pin of base.pins){
 const from=target(base.sourceProject,pin.relative);assert.equal(sha(read(from)),pin.sha256,'Frozen base changed '+pin.relative);
 const dest=target(input,pin.relative);fs.mkdirSync(path.dirname(dest),{recursive:true});
 if(pin.relative===profileRelative)fs.writeFileSync(dest,profileBytes,{flag:'wx'});else fs.linkSync(from,dest);
 pins.push({relative:pin.relative,sha256:sha(read(dest))});
}
for(const [relative,expected] of [['.tools/native-core/Godot_native_core_e_win64.exe','753b3e188068efaf865bda3abd6322ebe44e3a98ef2f5d199c8af1a78624c98b'],['.tools/native-core/accepted-core-e.json','29b1c6adcdecb11eebc859730c770e879a108279dfaaf60792e4c11c00add78a']]){
 const from=target(root,relative);assert.equal(sha(read(from)),expected);const dest=target(input,relative);fs.mkdirSync(path.dirname(dest),{recursive:true});fs.linkSync(from,dest);pins.push({relative,sha256:expected});
}
const seeds={version:1,expected:base.preferences.expected,description:base.preferences.description};
for(const name of ['render','layout'])seeds[name]={file:path.join(path.dirname(base.sourceProject),base.preferences[name].relative),sha256:base.preferences[name].sha256};
const argv=base.options.map(option=>option==='--detailed-profiling=off'?'--detailed-profiling=on':option);
assert(argv.includes('--detailed-profiling=on'));
const helper=require(path.join(input,'tools/native-production-selection.cjs'));
(async()=>{
 const staged=await helper.stageProductionSelection({project:input,label:'nwn74-'+label,argv,preferenceSeeds:seeds,env:{}});
 assert.equal(staged.selection.profiling,'true');
 assert.equal(staged.selection.renderCore.engineSha256,base.renderCore.engineSha256);
 assert.equal(sha(read(path.join(staged.selection.sourceProject,profileRelative))),profileSha);
 const capture='C:/Users/Niflheim/AppData/Roaming/nwn-model-viewer-research/native-loading-recordings/capture-YaH3xf';
 assert.equal(sha(read(path.join(capture,'recording.json'))),'1913892cd42db0f68dfa1b0edbdd37be4c380bdda50c95c178dc4ca2ba38a463');
 const result={issue:'NWN-74',private:true,accepted:false,baseSelection:baseFile,baseSelectionSha256:sha(read(baseFile)),input,pins,profile:{relative:profileRelative,baseSha256:'42d7585cd745c944a6a907dc11516994d639764d638cf1d7f7b5b041a6bcc9d0',privateSha256:profileSha},selection:{file:staged.file,sha256:staged.sha256,sourceIdentity:staged.selection.mainSourceIdentity.sha256},engine:{receipt:receiptFile,receiptSha256:sha(read(receiptFile)),file:receipt.binary.file,sha256:receipt.binary.sha256},capture,recordingSha256:sha(read(path.join(capture,'recording.json'))),scope:'Private render phase profiling only; accepted source/engine/defaults unchanged. Frame metrics are asynchronous completed render frames, with nested spans and diagnostic overhead. No FPS claim.'};
 const file=path.join(scope,'staged.json');fs.writeFileSync(file,JSON.stringify(result,null,2)+'\n',{flag:'wx'});
 console.log(JSON.stringify({file,sha256:sha(read(file)),profileSha,selection:result.selection,engine:result.engine,pins:pins.length}));
})().catch(error=>{console.error(error.stack);process.exitCode=1;});
