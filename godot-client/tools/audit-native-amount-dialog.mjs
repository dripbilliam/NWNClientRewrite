// Scoped original amount-control acceptance; never certifies the full UI goal.
import fs from 'node:fs/promises';
import path from 'node:path';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {fileURLToPath} from 'node:url';
const home=fileURLToPath(new URL('../',import.meta.url)),workspace=path.resolve(home,'..');
const hash=bytes=>createHash('sha256').update(bytes).digest('hex');
const read=async file=>JSON.parse(await fs.readFile(path.join(home,file),'utf8'));
async function sources(proof){const entries=Object.entries(proof.sourceSha256);assert.ok(entries.length>100);for(const[file,digest]of entries)assert.equal(hash(await fs.readFile(path.join(home,file))),digest,file+' changed');return entries.length;}
const receipts=[];
for(const[run,count]of[['native-amount-rules-final-v1',1161],['native-amount-ui-final-v1',210]]){
 const r=await read('reports/'+run+'.json'),proof=await read('reports/'+run+'.debugger.json');assert.equal(r.success,true);assert.equal(r.checks,count);assert.deepEqual(r.failures,[]);
 for(const key of['success','armed','sourceUnchanged','normalHeap'])assert.equal(proof[key],true);for(const key of['exception','engineOrLifetimeError'])assert.equal(proof[key],false);assert.equal(proof.debuggerExit,0);assert.equal(proof.publicConnections,0);
 receipts.push({run,checks:count,sources:await sources(proof)});
}
for(const[run,count]of[['native-amount-local-final-v1',170],['native-amount-barter-final-v1',57]]){
 const r=await read('reports/'+run+'.json');for(const key of['success','sourceUnchanged','debuggerArmed'])assert.equal(r[key],true);assert.equal(r.nativeException,false);assert.equal(r.nativeExit,0);assert.equal(r.publicConnections,0);assert.equal(r.endpoint,'127.0.0.1:5125');assert.equal(r.native.workersRemaining,0);assert.equal(r.actions.checks.length,count);assert.ok(r.actions.checks.every(row=>row.passed));assert.deepEqual(r.actions.failures,[]);
 if(count===170)for(const label of['Live native amount confirmation preserves the original decimal prefix before sending gold','Unchanged original server deducts exactly the dragged gold amount','Server creates a separate potion item and conserves total stack count','Original server confirms the selected split amount without a local stack edit'])assert.ok(r.actions.checks.some(row=>row.label===label&&row.passed),label);
 receipts.push({run,checks:count,sources:await sources(r)});
}
const original=[];
for(const file of['native-amount-dialog-observations-v2.json','rea-native-amount-dialog-v1.json','rea-inventory-gold-amount-v1.json']){
 const bytes=await fs.readFile(path.join(workspace,'backups/animations',file)),r=JSON.parse(bytes);assert.equal(r.binarySha256??r.target,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');if(r.amounts){assert.equal(r.amounts.length,500);assert.equal(r.timers.length,200);assert.equal(r.keys.length,133);assert.equal(r.constructor.delay,500000);assert.equal(r.constructor.period,50000);}original.push({file,sha256:hash(bytes)});
}
const images=[];
for(const suffix of['gold-amount','stack-amount']){const file='reports/native-amount-ui-final-v1-'+suffix+'.png',bytes=await fs.readFile(path.join(home,file));assert.equal(bytes.subarray(0,8).toString('hex'),'89504e470d0a1a0a');images.push({file,sha256:hash(bytes)});}
const archive='backups/native-amount-dialog-v1.zip',checkpoint=await read(archive+'.verified.json');assert.equal(checkpoint.verified,true);assert.equal(hash(await fs.readFile(path.join(home,archive))),checkpoint.sha256);for(const row of checkpoint.manifest){const file=row.sourceScope==='workspace'?path.join(workspace,row.source):path.join(home,row.file);assert.equal(hash(await fs.readFile(file)),row.sha256);}
const result={success:true,checks:receipts.reduce((sum,row)=>sum+row.checks,0),goalComplete:false,fullUiParity:false,originalAmountArithmeticAndTimerAccepted:true,nativeGoldAndStackInputAccepted:true,unboundedCaptionAnchorCorrectionAccepted:true,authoritativeLocalTransfersAccepted:true,twoPlayerBarterRegressionAccepted:true,publicConnections:0,manualClientTouched:false,receipts,original,images,checkpoint:{file:archive,sha256:checkpoint.sha256,files:checkpoint.files},remaining:'Other dialogs, constructor-specific constrained labels, full clipboard/IME/caret/localization/scale and shared button audio/preference parity; all previously recorded entire-UI gaps remain open. Isolated viewport inspection covers the tested source resources and scale, not broad original-client visual equivalence.'};
await fs.writeFile(path.join(home,'reports/native-amount-dialog-acceptance-v1.json'),JSON.stringify(result,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({success:true,checks:result.checks,goalComplete:false,checkpoint:result.checkpoint}));
