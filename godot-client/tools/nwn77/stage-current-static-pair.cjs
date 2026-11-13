'use strict';
// Stage the same current source, runtime, and preference seeds for an isolated
// static-scenery A/B. Run only while source writers are paused.
const fs=require('node:fs');
const path=require('node:path');
const crypto=require('node:crypto');
const assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../..');
const variant=process.argv[2]==='base'?'base':'static';
const flag=variant==='base'?'--base-scenery-draw=merged':'--static-scenery=merged';
const scope=path.join(root,`.cache/nwn77/current-${variant}-pair-a`);
const referenceFile=path.join(root,'.cache/native-presentation-parity/production-replay/nwn62-completion-tail-c/production-selection.json');
const hash=file=>crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
async function main(){
 assert(!fs.existsSync(path.join(scope,'staged.json')),'Preserve previous stage');
 const reference=JSON.parse(fs.readFileSync(referenceFile));
 assert.equal(reference.runtime.kind,'verified-native');
 assert.equal(reference.profiling,'false');
 assert(!reference.options.some(x=>x.startsWith('--loading-pipeline=')));
 const seeds={version:1,expected:reference.preferences.expected,description:'NWN-77 current-source isolated static scenery A/B; same reviewed preferences'};
 for(const name of ['render','layout'])seeds[name]={file:reference.preferences[name].source,sha256:reference.preferences[name].sha256};
 const helper=require(path.join(root,'tools/native-production-selection.cjs'));
 const common=[...reference.options];
 const off=await helper.stageProductionSelection({project:root,label:`nwn77-current-${variant}-streamed-a`,argv:[...common,'--loading-pipeline=streamed'],preferenceSeeds:seeds,env:{}});
 const on=await helper.stageProductionSelection({project:root,label:`nwn77-current-${variant}-merged-a`,argv:[...common,`--loading-pipeline=${variant}-merged`],preferenceSeeds:seeds,env:{}});
 for(const row of [off,on])await helper.readProductionSelection(row.file,row.sha256);
 assert.equal(off.selection.mainSourceIdentity.sha256,on.selection.mainSourceIdentity.sha256,'Source changed between staging legs');
 assert.equal(off.selection.runtime.executableSha256,on.selection.runtime.executableSha256);
 assert.equal(off.selection.preferences.render.sha256,on.selection.preferences.render.sha256);
 assert.equal(off.selection.preferences.layout.sha256,on.selection.preferences.layout.sha256);
 assert.deepEqual(off.selection.flags.filter(x=>x!==flag),on.selection.flags.filter(x=>x!==flag));
 assert(!off.selection.flags.includes(flag));
 assert(on.selection.flags.includes(flag));
 const prior=JSON.parse(fs.readFileSync(path.join(root,'.cache/nwn74/base-merge-pair-a/staged.json')));
 assert.equal(hash(path.join(prior.capture,'recording.json')),prior.recordingSha256);
 fs.mkdirSync(scope,{recursive:true});
 const staged={version:1,issue:variant==='base'?'NWN-74':'NWN-77',variant,private:true,accepted:false,reference:{file:referenceFile,sha256:hash(referenceFile)},capture:prior.capture,recordingSha256:prior.recordingSha256,sourceIdentity:off.selection.mainSourceIdentity.sha256,engineSha256:off.selection.runtime.executableSha256,selections:{off:{file:off.file,sha256:off.sha256},on:{file:on.file,sha256:on.sha256}},changedNativeOutputs:[flag],scope:`Current source, original generation-2 offline replay, isolated ${variant} scenery merging; no live Arelith or pixel acceptance claim`};
 const file=path.join(scope,'staged.json');fs.writeFileSync(file,JSON.stringify(staged,null,2)+'\n',{flag:'wx'});
 console.log(JSON.stringify({file,sha256:hash(file),sourceIdentity:staged.sourceIdentity,engineSha256:staged.engineSha256,selections:staged.selections}));
}
main().catch(error=>{console.error(error.stack);process.exitCode=1;});
