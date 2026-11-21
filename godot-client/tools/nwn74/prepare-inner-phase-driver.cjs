'use strict';
// Preserve the old replay driver; create a diagnostic variant with no FPS output.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../..'),stage=path.join(root,'.cache/nwn74/inner-phase-tracy-a');
const source=path.join(__dirname,'replay-render-probe.mjs'),dest=path.join(__dirname,'replay-inner-phase-tracy.mjs');
const sha=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
assert(!fs.existsSync(dest),'Preserve previous diagnostic driver');
const before=fs.readFileSync(source,'utf8');
assert.equal(sha(Buffer.from(before)),'cafcf235c0e4fc9ba72a2d842d85c15b24ce1a9344c0336a3a2362873b13d15b');
let after=before;
function one(a,b){assert.equal(after.split(a).length,2,'Driver anchor differs: '+a.slice(0,70));after=after.replace(a,b);}
one(".cache/nwn74/engine-build-b/receipt.json",".cache/nwn74/inner-phase-tracy-a/build-receipt.json");
one("nwn74Receipt.originalUntouched!==true","nwn74Receipt.acceptedSourceUnchanged!==true||nwn74Receipt.acceptedBinaryUnchanged!==true||nwn74Receipt.privateSourceRestored!==true");
one("nwn74Receipt.binary?.sha256!=='35e47e75fb71dac4ae91140026d1b333988c1546e8033f86a8624702b12da64f'","nwn74Receipt.binary?.sha256!=='636c4f5f4be0aecae03f07116acadfb7cae13e73d8f0f4d40bbb5b57693ad64a'");
one("if(productionSelection){\n  const file=path.join(project,'reports',run+'.fps.jsonl')","if(false){\n  const file=path.join(project,'reports',run+'.fps.jsonl')");
one('if(productionSelection&&Number.isFinite(value.fps)&&performance.now()-fpsObservationAt>=2000','if(false&&productionSelection&&Number.isFinite(value.fps)&&performance.now()-fpsObservationAt>=2000');
after=after.replaceAll('fps:value.fps,','');
fs.writeFileSync(dest,after,{flag:'wx'});
const receipt={issue:'NWN-74',private:true,source,sourceSha256:sha(Buffer.from(before)),driver:dest,driverSha256:sha(Buffer.from(after)),diagnosticEngineSha256:'636c4f5f4be0aecae03f07116acadfb7cae13e73d8f0f4d40bbb5b57693ad64a',fpsOutputDisabled:true,scope:'Offline scene replay for Tracy phase attribution only; no FPS output or comparison.'};
fs.writeFileSync(path.join(stage,'driver-receipt.json'),JSON.stringify(receipt,null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify(receipt));
