import fs from 'node:fs/promises';
import path from 'node:path';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {fileURLToPath} from 'node:url';
const project=fileURLToPath(new URL('../',import.meta.url)),workspace=path.dirname(project.slice(0,-1)),hash=bytes=>createHash('sha256').update(bytes).digest('hex');
const labels=['game-types','filters','activation','details','keyboard','refresh','pages','retained','deletion','rejection'];
let nativeChecks=0;const receipts=[];
for(const label of labels){
 const file=path.join(project,'.cache/nwn40/nwn40-secondary-'+label+'/proof.json'),bytes=await fs.readFile(file),proof=JSON.parse(bytes);
 assert.equal(proof.success,true,label);assert.equal(proof.clean,true,label);assert.deepEqual(proof.failures,[]);assert.deepEqual(proof.changed,[]);assert.equal(proof.graphical,true);assert.equal(proof.unfocusable,true);assert.ok(Number.isInteger(proof.screen)&&proof.screen>=0);assert.equal(proof.outcome.exitCode,0);assert.equal(proof.outcome.killed,false);
 if(proof.window){assert.equal(proof.window.focused,false);assert.equal(proof.window.unfocusable,true);assert.equal(proof.window.screen,proof.screen);assert.notEqual(proof.window.screen,proof.window.primary);}
 for(const item of proof.inputs)assert.equal(hash(await fs.readFile(path.join(workspace,item.path))),item.sha256,item.path+': source changed');
 nativeChecks+=proof.checks;receipts.push({file:path.relative(workspace,file),sha256:hash(bytes),checks:proof.checks,screen:proof.screen});
}
const liveFile=path.join(project,'.cache/nwn40/nwn40-live-v6/result.json'),liveBytes=await fs.readFile(liveFile),live=JSON.parse(liveBytes);
assert.equal(live.success,true);assert.equal(live.checkCount,36);assert.ok(live.checks.every(value=>value.passed));assert.equal(live.failure,null);assert.equal(live.serversStopped,true);assert.equal(live.unexpectedServerExit,false);assert.equal(live.sourceModuleUnchanged,true);assert.equal(live.sourcesUnchanged,true);assert.equal(live.publicConnections,0);
for(const [file,digest]of Object.entries(live.sourceHashes))assert.equal(hash(await fs.readFile(path.join(project,file))),digest,file+': live source changed');
receipts.push({file:path.relative(workspace,liveFile),sha256:hash(liveBytes),checks:live.checkCount});
const nodeFile=path.join(workspace,'.cache/nwn-40/final-node.tap'),nodeBytes=await fs.readFile(nodeFile),nodeText=nodeBytes.toString('utf8').replace(/^\uFEFF/,'');
assert.match(nodeText,/# tests 177\r?\n/);assert.match(nodeText,/# pass 177\r?\n/);assert.match(nodeText,/# fail 0\r?\n/);assert.match(nodeText,/# skipped 0\r?\n/);
receipts.push({file:path.relative(workspace,nodeFile),sha256:hash(nodeBytes),checks:177});
const result={success:true,ticket:'NWN-40',scope:'Existing player browser and character-vault workflow',nodeTests:177,nativeChecks,liveChecks:36,totalChecks:177+nativeChecks+36,secondaryMonitor:true,unfocused:true,receipts,limitations:'No new DM authentication/hosting/LAN discovery or full-client rendering/performance claim. Native UI and real-server service composition are separate acceptance legs. NWN-14 intermittent admission failures remain a separate issue.'};
await fs.writeFile(path.join(project,'.cache/nwn40/completion.json'),JSON.stringify(result,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify(result));
