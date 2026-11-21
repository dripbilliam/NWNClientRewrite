import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {fileURLToPath} from 'node:url';
import {dialogReplyRequest} from '../src/network_player_requests.js';
import {decodeServerGameMessage} from '../src/network_game_messages.js';
import {installedNetworkResources} from '../electron/installed_network_resources.mjs';
import {NetworkText} from '../src/network_text.js';
import {NetworkWorld} from '../src/network_world.js';
import {openLocalModule} from '../scripts/local-module.mjs';
const replies=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-network-dialog-reply-observations.json',import.meta.url)));

test('dialog reply wire fields match original sender and original server handler in 110 cases',()=>{
 for(const row of replies.cases.filter(r=>r.case.format===1)){
  const packet=dialogReplyRequest(row.case),native=Buffer.from(row.packet,'hex');assert.equal(packet.length,native.length);assert.deepEqual(Buffer.from(packet.subarray(0,-1)),native.subarray(0,-1));assert.equal(packet.at(-1)&0xe0,native.at(-1)&0xe0);
  if(row.case.missingOwner||row.case.badCast){assert.equal(row.result,0);continue;}
  const c=row.calls[0];assert.equal(c.replyId,row.case.replyId);assert.equal(c.entryId,row.case.entryId);assert.equal(c.abort,row.case.abort);assert.equal(c.playerId,17);
 }
});

test('captured native server dialog messages retain owner, speaker, localized text, reply IDs and current entry',()=>{
 const capture=JSON.parse(fs.readFileSync(new URL('../backups/animations/local-network-renderer-v11.json',import.meta.url))),messages=capture.wireMessages.map(h=>Buffer.from(h,'hex')).filter(b=>b[1]===20).map(b=>decodeServerGameMessage(b));
 const [entry,choices]=messages;assert.equal(entry.kind,'dialog-entry');assert.equal(entry.ownerId,0x80000013);assert.equal(entry.speakerId,0x80000013);assert.equal(entry.tokenObjectId,0xffffffff);assert.deepEqual(entry.text,{gender:0,strRef:57795});
 assert.equal(choices.entryId,32);assert.equal(choices.firstCount,1);assert.equal(choices.secondCount,0);assert.deepEqual(choices.replies,[{text:{text:''},id:0}]);
});

test('network talk lookup uses the installed native TLK record owner and keeps file paths private',async()=>{
 const resources=installedNetworkResources({install:fileURLToPath(new URL('../../FullDecomp/NwnRootInstall/',import.meta.url))}),issues=[];
 const result=await resources.talkString(0x6cd,0,[],d=>issues.push(d));assert.equal(result.status,1);assert.ok(result.text.length);assert.equal(typeof result.sound,'string');assert.equal(JSON.stringify(result).includes('NwnRootInstall'),false);assert.deepEqual(issues,[]);
});

test('network FullName and gender tokens use active StringTokens2DA and replicated character identity',async()=>{
 const install=fileURLToPath(new URL('../../FullDecomp/NwnRootInstall/',import.meta.url)),resources=installedNetworkResources({install}),resolver=await openLocalModule(install,await resources.findFile('nwm','Prelude','nwm')),world=new NetworkWorld(),issues=[];
 const capture=JSON.parse(fs.readFileSync(new URL('../backups/animations/local-network-session-v1.json',import.meta.url)));for(const message of capture.messages)world.apply(message);
 const player=world.registry.get(world.localObjectId),name=player.appearance.name,expected=[name.firstName.text,name.lastName.text].filter(Boolean).join(' '),text=new NetworkText({world,getResource:(...args)=>resolver.getResource(...args),talkString:(ref,g)=>resources.talkString(ref,g,[],()=>{}),diagnose:(...args)=>issues.push(args)});
 assert.equal(await text.resolve({text:'<FullName>'},player.id),expected);assert.ok((await text.resolve({text:'<him/her>'},player.id)).length);assert.deepEqual(issues,[]);
});

test('actual renderer dialog choices advance the vanilla campaign and server closure clears the UI',()=>{
 const live=JSON.parse(fs.readFileSync(new URL('../backups/animations/local-network-renderer-v14.json',import.meta.url))),diagnostics=JSON.parse(fs.readFileSync(new URL('../backups/animations/local-network-renderer-v14-diagnostics.json',import.meta.url)));
 assert.equal(live.connected,true);assert.equal(live.failure,undefined);assert.equal(live.sampleFailure,undefined);assert.equal(live.dialogSelections.length,8);assert.equal(new Set(live.dialogSelections.map(s=>s.entryId)).size,8);
 assert.ok(live.dialogSelections.some(s=>s.text.includes('Spectorial Melimion')));assert.ok(live.dialogSelections.some(s=>s.text.includes(' on him.')));assert.equal(live.dialogSelections.some(s=>/<[^>]+>|NO STATS/.test(s.text)),false);
 assert.equal(live.samples.at(-1).dialog,null);assert.equal(live.states.at(-1).phase,'closed');assert.deepEqual(live.renderer.scene.failedObjects,[]);
 const dialogs=live.wireMessages.map(h=>Buffer.from(h,'hex')).filter(b=>b[1]===20).map(b=>decodeServerGameMessage(b));assert.ok(dialogs.some(d=>d.kind==='dialog-close'));assert.ok(dialogs.filter(d=>d.kind==='dialog-entry').length>=8);
 // A locked native door must not be optimistically opened by the client.
 assert.ok(live.interactions.some(i=>i.action==='door.open'));assert.ok(live.samples.every(s=>s.scene?.objects.filter(o=>o.objectType===10).every(d=>d.animation===22)??true));
 assert.equal(diagnostics.some(d=>d.severity==='error'||/game-message-invalid|network.text-token-unhandled|scene-object-failed/.test(d.code)),false);
});
