'use strict';
// No client launch. Clone the existing pinned render-probe source and stage
// two production selections whose only policy differences are static scenery
// and BASE draw merging. The launcher exposes these together as one pipeline.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../..'),scope=path.join(root,'.cache/nwn74/base-merge-pair-a');
const previousFile=path.join(root,'.cache/nwn74/render-probe-a/staged.json');
const previous=JSON.parse(fs.readFileSync(previousFile));
const hash=file=>crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const destination=(base,relative)=>{assert(relative&&!path.isAbsolute(relative)&&!relative.split(/[\\/]/).some(p=>!p||p==='.'||p==='..'));const file=path.resolve(base,relative);assert(!path.relative(base,file).startsWith('..'));return file;};
async function main(){
 assert(!fs.existsSync(path.join(scope,'staged.json')),'Preserve existing base-merge stage');
 assert(previous.private&&!previous.accepted&&previous.pins.length>2000);
 assert.equal(hash(previousFile),'31e6d21c9d74fb66837445f82637e70df93440195a3128133b8f01b40853460a');
 assert.equal(hash(previous.engine.receipt),previous.engine.receiptSha256);
 assert.equal(hash(previous.engine.file),previous.engine.sha256);
 assert.equal(hash(path.join(previous.capture,'recording.json')),previous.recordingSha256);
 const original=JSON.parse(fs.readFileSync(previous.selection.file));
 assert.equal(hash(previous.selection.file),previous.selection.sha256);
 assert.equal(original.profiling,'true');
 assert(!original.options.some(x=>x.startsWith('--base-scenery-draw=')));
 assert.equal(original.mainSourceIdentity.sha256,previous.selection.sourceIdentity);
 const input=path.join(scope,'input');fs.mkdirSync(input,{recursive:true});
 const pins=[];
 for(const pin of previous.pins){
  const from=destination(previous.input,pin.relative);assert.equal(hash(from),pin.sha256,'Existing source pin changed: '+pin.relative);
  const target=destination(input,pin.relative);fs.mkdirSync(path.dirname(target),{recursive:true});
  if(fs.existsSync(target))assert.equal(hash(target),pin.sha256,'Existing partial stage pin changed: '+pin.relative);
  else fs.linkSync(from,target);
  pins.push(pin);
 }
 const seeds={version:1,expected:original.preferences.expected,description:original.preferences.description};
 for(const name of ['render','layout'])seeds[name]={file:original.preferences[name].source,sha256:original.preferences[name].sha256};
 const helper=require(path.join(input,'tools/native-production-selection.cjs'));
 const off=await helper.stageProductionSelection({project:input,label:'nwn74-base-merge-streamed-a',argv:[...original.options,'--loading-pipeline=streamed'],preferenceSeeds:seeds,env:{}});
 const on=await helper.stageProductionSelection({project:input,label:'nwn74-base-merge-merged-a',argv:[...original.options,'--loading-pipeline=merged'],preferenceSeeds:seeds,env:{}});
 for(const staged of [off,on])await helper.readProductionSelection(staged.file,staged.sha256);
 assert.equal(off.selection.mainSourceIdentity.sha256,on.selection.mainSourceIdentity.sha256);
 assert.equal(off.selection.mainSourceIdentity.sha256,previous.selection.sourceIdentity);
 assert.equal(off.selection.runtime.executableSha256,on.selection.runtime.executableSha256);
 assert.equal(off.selection.preferences.render.sha256,on.selection.preferences.render.sha256);
 assert.equal(off.selection.preferences.layout.sha256,on.selection.preferences.layout.sha256);
 const mergeFlags=new Set(['--static-scenery=merged','--base-scenery-draw=merged']);
 assert.deepEqual(off.selection.flags.filter(x=>!mergeFlags.has(x)),on.selection.flags.filter(x=>!mergeFlags.has(x)));
 assert(!off.selection.flags.some(x=>mergeFlags.has(x)));
 assert(mergeFlags.size===2&&[...mergeFlags].every(x=>on.selection.flags.includes(x)));
 const result={issue:'NWN-74',private:true,accepted:false,sourceStage:previousFile,sourceStageSha256:hash(previousFile),input,pins,engine:previous.engine,capture:previous.capture,recordingSha256:previous.recordingSha256,driver:path.join(__dirname,'replay-render-probe.mjs'),driverSha256:hash(path.join(__dirname,'replay-render-probe.mjs')),selections:{off:{file:off.file,sha256:off.sha256,sourceIdentity:off.selection.mainSourceIdentity.sha256,policy:'streamed'},on:{file:on.file,sha256:on.sha256,sourceIdentity:on.selection.mainSourceIdentity.sha256,policy:'merged'}},changedNativeOutputs:[...mergeFlags],scope:'Immutable original generation-2 render probe source, private phase engine and preference seeds. Streamed vs merged loading pipeline differs only in static-scenery and BASE draw merging outputs; results cannot be attributed to BASE alone. No client launched or FPS claim.'};
 const file=path.join(scope,'staged.json');fs.writeFileSync(file,JSON.stringify(result,null,2)+'\n',{flag:'wx'});
 console.log(JSON.stringify({file,sha256:hash(file),off:result.selections.off.sha256,on:result.selections.on.sha256,sourceIdentity:result.selections.off.sourceIdentity,pins:pins.length}));
}
main().catch(error=>{console.error(error.stack);process.exitCode=1;});
