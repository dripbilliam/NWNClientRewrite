'use strict';
// Freeze current normal route versus explicit PackedScene route under one source.
const fs=require('node:fs');const path=require('node:path');const crypto=require('node:crypto');const assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../..');const scope=path.join(root,'.cache/nwn62/packed-route-pair-a');
const referenceFile=path.join(root,'.cache/native-presentation-parity/production-replay/nwn62-completion-tail-c/production-selection.json');
const sha=file=>crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
async function main(){
 assert(!fs.existsSync(path.join(scope,'staged.json')),'Preserve previous stage');
 const reference=JSON.parse(fs.readFileSync(referenceFile));
 const seeds={version:1,expected:reference.preferences.expected,description:'NWN-62 current ordinary/cooperative versus explicit packed route'};
 for(const name of ['render','layout'])seeds[name]={file:reference.preferences[name].source,sha256:reference.preferences[name].sha256};
 const helper=require(path.join(root,'tools/native-production-selection.cjs'));
 const common=[...reference.options];
 const ordinary=await helper.stageProductionSelection({project:root,label:'nwn62-current-ordinary-a',argv:[...common,'--loading-pipeline=ordinary'],preferenceSeeds:seeds,env:{}});
 const packed=await helper.stageProductionSelection({project:root,label:'nwn62-current-packed-a',argv:[...common,'--loading-pipeline=packed'],preferenceSeeds:seeds,env:{}});
 for(const row of [ordinary,packed])await helper.readProductionSelection(row.file,row.sha256);
 assert.equal(ordinary.selection.mainSourceIdentity.sha256,packed.selection.mainSourceIdentity.sha256);
 assert.equal(ordinary.selection.runtime.executableSha256,packed.selection.runtime.executableSha256);
 assert.equal(ordinary.selection.preferences.render.sha256,packed.selection.preferences.render.sha256);
 assert.equal(ordinary.selection.preferences.layout.sha256,packed.selection.preferences.layout.sha256);
 assert.deepEqual(ordinary.selection.flags,packed.selection.flags.filter(x=>x!=='--model-template=packed'));
 assert(packed.selection.flags.includes('--model-template=packed'));
 const prior=JSON.parse(fs.readFileSync(path.join(root,'.cache/nwn74/base-merge-pair-a/staged.json')));
 assert.equal(sha(path.join(prior.capture,'recording.json')),prior.recordingSha256);
 fs.mkdirSync(scope,{recursive:true});
 const staged={version:1,issue:'NWN-62',private:true,accepted:false,capture:prior.capture,recordingSha256:prior.recordingSha256,sourceIdentity:ordinary.selection.mainSourceIdentity.sha256,engineSha256:ordinary.selection.runtime.executableSha256,selections:{ordinary:{file:ordinary.file,sha256:ordinary.sha256},packed:{file:packed.file,sha256:packed.sha256}},changedNativeOutputs:['--model-template=packed'],scope:'Same current source and accepted engine: ordinary current cooperative route versus explicit packed scene route; original generation-2 offline capture. No default change or Arelith acceptance.'};
 const file=path.join(scope,'staged.json');fs.writeFileSync(file,JSON.stringify(staged,null,2)+'\n',{flag:'wx'});
 console.log(JSON.stringify({file,sha256:sha(file),sourceIdentity:staged.sourceIdentity,selections:staged.selections}));
}
main().catch(error=>{console.error(error.stack);process.exitCode=1;});
