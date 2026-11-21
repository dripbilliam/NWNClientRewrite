// Bounded acceptance summary from sealed QA capture and authoritative exports.
// Run in a separate CLI process: full captures must not remain in a live REPL.
import fs from 'node:fs/promises';
import path from 'node:path';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
import {fileURLToPath} from 'node:url';
import {decodeServerGameMessage} from '../src/network_game_messages.js';
import {parseGff,getGffStructType} from '../src/gff.js';
const workspace=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..'),capture=path.join(workspace,'backups/animations');
const hash=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
const read=async name=>JSON.parse(await fs.readFile(path.join(capture,name),'utf8'));
const sealedName='local-network-character-export-v132.json',sealedBytes=await fs.readFile(path.join(capture,sealedName)),report=JSON.parse(sealedBytes);
assert.equal(report.states.at(-1).phase,'closed');
for(const key of ['failure','sampleFailure','disconnectFailure'])assert.ok(!report[key],key);
const before=await read('network-character-export-equip-proof-v131.json'),spell=await read('network-character-export-spell-proof-v131.json'),rejoin=await read('network-character-export-reconnect-proof-v132.json');
const summary=inventory=>inventory.equipment.map(({name,slot,stackSize})=>({name,slot,stackSize})).sort((a,b)=>a.slot-b.slot);
assert.deepEqual(summary(before.inventory),summary(rejoin.inventory));
assert.deepEqual(spell.before.map(s=>s.Ready),[1,1]);assert.deepEqual(spell.after.map(s=>s.Ready),[0,1]);
// The original server readies levels during this admission path; do not claim
// that spent slots stay spent on a server configured to restore them.
assert.deepEqual(rejoin.lightSlotsAfterReconnect.map(s=>s.Ready),[1,1]);
const replies=[];
for(const hex of report.wireMessages){
 const bytes=Buffer.from(hex,'hex');if(bytes[1]!==3||bytes[2]!==10)continue;
 const reply=decodeServerGameMessage(bytes),root=parseGff(reply.data,'BIC ').root;
 assert.equal(reply.kind,'character-export');
 replies.push({sha256:hash(reply.data),bytes:reply.data.length,equipment:root.Equip_ItemList.map(i=>({slot:getGffStructType(i),baseItem:i.BaseItem,stackSize:i.StackSize})),lightSlots:root.ClassList[0].MemorizedList0.filter(s=>s.Spell===100).map(s=>s.Ready)});
}
assert.equal(replies.length,2);assert.ok(replies.some(r=>r.sha256===rejoin.reExportEntry.sha256));
assert.equal(report.gameplayRequests.filter(r=>r.packet==='70061f').length,2);
const log=(await fs.readFile(report.runtimeLog,'utf8')).trim().split('\n').filter(Boolean).map(line=>JSON.parse(line));
const errors=log.filter(r=>r.severity==='error').map(({code,message})=>({code,message}));assert.deepEqual(errors,[]);
const result={scope:'Native server export, durable local vault and saved-entry equipment reconnect; full multiplayer goal remains active.',sealed:{file:sealedName,sha256:hash(sealedBytes),bytes:sealedBytes.length,samples:report.samples.length,wireMessages:report.wireMessages.length,finalPhase:report.states.at(-1).phase},equipmentPreserved:true,newCanonicalItemIds:rejoin.inventory.equipment.map(item=>({name:item.name,before:before.inventory.equipment.find(old=>old.slot===item.slot).id,after:item.id})),nativeExports:replies,spellExportBefore:spell.before.map(s=>s.Ready),spellExportAfterCast:spell.after.map(s=>s.Ready),spellAfterNativeAdmission:rejoin.lightSlotsAfterReconnect.map(s=>s.Ready),nativeRestore:{owner:'nwmain server implementation CNWSPlayer::LoadCreatureData',address:'0x1404bb450',callSite:'0x1404bbe2a',helper:'0x1404123b0',condition:'loader restore flag equals zero',configurationMeaning:'not established'},originalPlayer:rejoin.players.find(p=>p.id!==rejoin.localObjectId),runtime:{records:log.length,errors},limits:['v131 full capture was lost to a QA close race; only bounded frozen summary and export proofs retained.','v132 corrected harness closes normally and its full capture is sealed.','Spent slots were preserved in the vault; this native server restored them on admission.','No active original-client shared combat, server-vault admission, crash-save or complete multiplayer acceptance claim.']};
await fs.writeFile(path.join(capture,'network-character-export-acceptance-v1.json'),JSON.stringify(result,null,2)+'\n');
console.log(JSON.stringify({accepted:true,equipmentPreserved:true,nativeExports:replies.length,finalPhase:'closed',runtimeErrors:errors.length,scope:result.scope}));
