import fs from 'node:fs/promises';
import path from 'node:path';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
import {fileURLToPath} from 'node:url';
import {decodeServerGameMessage} from '../src/network_game_messages.js';
import {NativeMessageReader} from '../src/native_message.js';
import {openLocalModule} from './local-module.mjs';
import {loadNetworkObjectRules} from '../src/network_object_rules.js';
import {NetworkWorld} from '../src/network_world.js';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..'),folder=path.join(root,'backups/animations'),build={number:8193,revision:37,postfix:17};
const read=async name=>JSON.parse(await fs.readFile(path.join(folder,name),'utf8')),hash=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
const bytes=await fs.readFile(path.join(folder,'local-network-action-queue-v146.json')),report=JSON.parse(bytes);assert.equal(report.states.at(-1).phase,'closed');for(const key of ['failure','sampleFailure','disconnectFailure','controlFailure'])assert.ok(!report[key],key);
const install=path.resolve(root,'../FullDecomp/NwnRootInstall'),resolver=await openLocalModule(install,path.join(install,'data/nwm/Prelude.nwm')),rules=await loadNetworkObjectRules(resolver),world=new NetworkWorld(),queueEvents=[],spells=[],readiness=[];
for(const [index,hex]of report.wireMessages.entries()){
 const message=decodeServerGameMessage(Buffer.from(hex,'hex'),{clientBuild:build,serverBuild:build,objectRules:{...rules,objectState:id=>world.registry.get(id)?.replicated}}),at=report.wireTimes[index];
 if(message.kind==='object-updates')for(const record of message.records)for(const event of record.state?.actionQueueChanges??[])queueEvents.push({at,id:record.id,...event});
 if(message.kind==='spell-feedback')spells.push({at,...message});world.apply(message);
 const actor=world.registry.get(world.localObjectId);if(actor?.playerState?.spellbooks){const slots=Object.values(actor.playerState.spellbooks).flatMap(book=>Object.values(book.memorized).flat());readiness.push({at,ready:slots.filter(s=>s?.spell===100&&s.ready).length});}
}
const clicks=report.quickbarActions.filter(a=>a.step.mode==='cancelQueuedAction');assert.deepEqual(clicks.map(c=>c.result.actionId),[0,4]);
for(const {at,result:c}of clicks){
 assert.ok(c.physicalQueueClick);assert.ok(c.queue.some(e=>e.type===c.actionId&&e.group===c.groupId&&!e.pending));assert.ok(c.after.some(e=>e.type===c.actionId&&e.group===c.groupId&&e.pending));
 const addition=queueEvents.find(e=>e.action==='A'&&e.type===c.actionId&&e.group===c.groupId&&e.at<at),deletion=queueEvents.find(e=>e.action==='D'&&e.type===c.actionId&&e.group===c.groupId&&e.at>=at-500);assert.ok(addition&&deletion,'Vanilla server adds and subsequently removes clicked action');
 const request=report.gameplayRequests.find(r=>{const b=Buffer.from(r.packet,'hex');if(b[1]!==6||b[2]!==20||Math.abs(r.at-at)>1000)return false;const data=b.subarray(3),reader=new NativeMessageReader(1);reader.setReadMessage(data,data.length,0xffffffff,1);return reader.readWord()===c.actionId&&reader.readWord()===c.groupId;});assert.ok(request,'Physical click sends native action/group WORD request');
}
const move=report.moves[0],cancel=clicks[0],returnMove=report.moves[1],stopped=report.samples.filter(s=>s.at>cancel.at+1500&&s.at<returnMove.at&&s.state?.phase==='playing');assert.ok(stopped.length>=2);
const positions=stopped.map(s=>s.server.objects.find(o=>o.id===s.server.controlledId).position),point=positions[0];assert.ok(positions.every(p=>Math.hypot(p[0]-point[0],p[1]-point[1])<.05),'Server position remains stationary after cancel');assert.ok(Math.hypot(point[0]-move.position[0],point[1]-move.position[1])>2,'Walk cancelled before original destination');assert.ok(Math.hypot(point[0]-30,point[1]-85)>2,'Character actually moved before cancellation');
assert.ok(spells.some(s=>s.spellId===100&&s.casting===1));assert.ok(!spells.some(s=>s.spellId===100&&s.casting===0),'Cancelled Light self-cast never reports release');assert.equal(readiness.at(-1).ready,readiness.find(r=>r.ready>0).ready,'Server retains prepared Light availability after cancellation');
const final=report.samples.findLast(s=>s.state?.phase==='playing'&&s.party&&s.server?.actionQueue);assert.deepEqual(final.server.actionQueue,[]);assert.deepEqual(final.hud.actionQueue,[]);assert.ok(Math.hypot(final.server.objects.find(o=>o.id===final.server.controlledId).position[0]-30,final.server.objects.find(o=>o.id===final.server.controlledId).position[1]-85)<.1);
for(const s of report.samples.filter(s=>s.party?.members?.length===2)){assert.equal(s.party.members.find(p=>p.self).health.current,77);assert.equal(s.party.members.find(p=>!p.self).health.current,86);}
assert.deepEqual((await fs.readFile(report.runtimeLog,'utf8')).trim().split('\n').filter(Boolean).map(s=>JSON.parse(s)).filter(r=>r.severity==='error'),[]);
const old=await read('local-network-initiative-v145.json');assert.equal(old.states.at(-1).phase,'closed');for(const k of ['failure','sampleFailure','disconnectFailure'])assert.ok(!old[k]);
const currentBytes=await fs.readFile(path.join(folder,'network-action-queue-current-v147.json')),current=JSON.parse(currentBytes),last=current.samples.findLast(s=>s.state?.phase==='playing'&&s.scene?.tiles===144&&s.party?.members.length===2);assert.ok(last);assert.deepEqual(last.scene.failedObjects,[]);assert.deepEqual(last.hud.actionQueue,[]);assert.equal(current.moves.length,0);assert.equal(current.quickbarActions.length,0);for(const k of ['sampleFailure','controlFailure'])assert.ok(!current[k]);
assert.deepEqual((await fs.readFile(current.runtimeLog,'utf8')).trim().split('\n').filter(Boolean).map(s=>JSON.parse(s)).filter(r=>r.severity==='error'),[]);
const result={scope:'Live native walk and prepared self-cast queue-icon cancellation, server-owned action removal and unchanged health beside a passive original client. Not full shared active combat/casting acceptance.',sealed146:{bytes:bytes.length,sha256:hash(bytes),samples:report.samples.length,wire:report.wireMessages.length,phase:'closed'},closed145:{samples:old.samples.length,wire:old.wireMessages.length},clicks,queueEvents,spells,readyLight:{before:readiness.find(r=>r.ready>0).ready,after:readiness.at(-1).ready},stoppedPosition:point,originalDestination:move.position,stoppedSamples:positions.length,finalPosition:[30,85],runtimeErrors:0,current147:{sha256:hash(currentBytes),phase:last.state.phase,tiles:last.scene.tiles,canonicalIds:last.party.members.map(p=>p.id),noScheduledInputs:true},limits:['Current147 full capture remains active/unsealed. Frozen bounded evidence is explicit.','Original client is connected/passive; no new original-origin shared combat claim.','Initial attack approach, missing authored sound reference, remaining audio/render owners and exact native queue layout remain incomplete.']};await fs.writeFile(path.join(folder,'network-action-queue-acceptance-v1.json'),JSON.stringify(result,null,2)+'\n');console.log(JSON.stringify({accepted:true,physicalClicks:clicks.length,stoppedPosition:point,lightRelease:false,lightReady:result.readyLight,runtimeErrors:0,current147:'playing'}));
