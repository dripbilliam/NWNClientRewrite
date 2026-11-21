'use strict';
// Private, final-report-only derivative of the frozen accepted-control scene.
// No native build, accepted project edit, or normal selector modification.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../..');
const label='source-input-b',directory=path.join(root,'.cache/nwn64',label);
const base=path.join(root,'.cache/nwn64/clock-review-pair-b');
const proposal=JSON.parse(fs.readFileSync(path.join(base,'proposal.json')));
const staged=JSON.parse(fs.readFileSync(path.join(base,'staged.json')));
const view=proposal.views.find(row=>row.mode==='accepted-control');
const selected=staged.selections.find(row=>row.mode==='accepted-control');
const sha=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
const read=file=>fs.readFileSync(file);
const helper='tools/nwn64/source_input_census.gd';
function target(basePath,relative){
 assert(relative&&!path.isAbsolute(relative)&&!relative.split(/[\\/]/).some(part=>!part||part==='.'||part==='..'));
 const file=path.resolve(basePath,relative),rel=path.relative(basePath,file);
 assert(!rel.startsWith('..')&&!path.isAbsolute(rel));return file;
}
function reportOverlay(bytes){
 const text=bytes.toString();
 const needle='\t\treport.private_clock_review={';
 assert.equal(text.split(needle).length,2,'Expected one existing private final-report seam');
 return Buffer.from(text.replace(needle,'\t\treport.private_source_input_census=preload("res://'+helper+'").collect(world)\n'+needle));
}
async function main(){
 assert(!fs.existsSync(directory),'Fresh label required');
 assert(selected.private&&selected.accepted===false&&selected.production===false);
 assert.equal(sha(read(selected.file)),selected.sha256);
 for(const pin of view.pins)assert.equal(sha(read(target(view.project,pin.relative))),pin.sha256,'Frozen input changed '+pin.relative);
 const project=path.join(directory,'project');fs.mkdirSync(project,{recursive:true});
 const patches=new Map([['native_live_world.gd',reportOverlay(read(target(view.project,'native_live_world.gd')))],
  [helper,read(target(root,helper))]]);
 const pins=[];
 for(const pin of view.pins){
  const src=target(view.project,pin.relative),dest=target(project,pin.relative);fs.mkdirSync(path.dirname(dest),{recursive:true});
  if(patches.has(pin.relative))fs.writeFileSync(dest,patches.get(pin.relative),{flag:'wx'});
  else if(pin.relative.startsWith('.godot/'))fs.copyFileSync(src,dest,fs.constants.COPYFILE_EXCL);
  else fs.linkSync(src,dest);
  pins.push({relative:pin.relative,sha256:sha(read(dest))});
 }
 assert(!pins.some(pin=>pin.relative===helper),'New helper must not already exist');
 const helperFile=target(project,helper);fs.mkdirSync(path.dirname(helperFile),{recursive:true});fs.writeFileSync(helperFile,patches.get(helper),{flag:'wx'});
 pins.push({relative:helper,sha256:sha(read(helperFile))});
 const selectionHelper=require(path.join(project,'tools/native-production-selection.cjs'));
 const preferences=JSON.parse(read(proposal.preferences.file));
 const row=await selectionHelper.stageProductionSelection({project,label,argv:proposal.argv,preferenceSeeds:preferences,env:{}});
 assert(row.selection.private&&row.selection.accepted===false&&row.selection.production===false);
 assert.equal(row.selection.renderCore.engineSha256,'753b3e188068efaf865bda3abd6322ebe44e3a98ef2f5d199c8af1a78624c98b');
 assert.equal(row.selection.renderCore.nativeKernelSha256,'485741af15f0581a3c60c0f9a8ae738888eba08716c7a5c2c2d1bd550828963d');
 for(const pin of pins)assert.equal(sha(read(target(project,pin.relative))),pin.sha256,'Staged source changed '+pin.relative);
 const output={kind:'private-nwn64-source-input-census',private:true,accepted:false,production:false,project,selection:row.file,selectionSha256:row.sha256,driver:path.join(project,'tools/replay-native-loading.mjs'),capture:proposal.capture,pins,overlays:[{relative:'native_live_world.gd',sha256:sha(patches.get('native_live_world.gd'))},{relative:helper,sha256:sha(patches.get(helper))}],scope:'Accepted Core E/DLL and source, one final-report-only helper. No native build, normal selector or accepted source writes; generation4 original archive replay remains a separate operation.'};
 const file=path.join(directory,'staged.json');fs.writeFileSync(file,JSON.stringify(output,null,2)+'\n',{flag:'wx'});
 console.log(JSON.stringify({file,sha256:sha(read(file)),project,selection:row.file,selectionSha256:row.sha256,pins:pins.length,overlays:output.overlays}));
}
main().catch(error=>{console.error(error.stack);process.exitCode=1;});
