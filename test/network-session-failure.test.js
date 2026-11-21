import test from 'node:test';
import assert from 'node:assert/strict';
import {EventEmitter} from 'node:events';
import fs from 'node:fs';
import vm from 'node:vm';
import {NetworkGameSession} from '../electron/network_game_session.mjs';
import {NativeLobby} from '../godot-client/tools/native-lobby.mjs';
import journal from '../godot-client/tools/native-session-failure-journal.cjs';
function session(){
 const peer=new EventEmitter(),diagnostics=[];
 peer.disconnect=async()=>peer.emit('closed',{failed:false});
 const value=new NetworkGameSession({peer,identity:{dispose(){}},build:{build:{number:8193,revision:37,postfix:0},dispose(){}},resources:{close(){}},language:0,openModule:async()=>({}),decodeMessage:v=>v,onDiagnostic:d=>diagnostics.push(d)});
 value.phase='playing';value.areaGeneration=7;
 return{peer,value,diagnostics};
}
async function rejectMessage(row,message='Native attack animation group is invalid'){
 row.value.receive=async()=>{row.value.diagnose({code:'network.object-import-failed',reason:message});throw Error(message);};
 row.peer.emit('message',Uint8Array.of(112));await row.value.delivery;await row.value.disconnectPromise;
}
test('queued delivery preserves the local cause before closed state without inventing a server reason',async()=>{
 const row=session(),states=[];row.value.on('state',v=>states.push(v));await rejectMessage(row);
 const closed=states.find(v=>v.closed);assert.equal(row.value.closed,true);assert.equal(closed.phase,'closed');assert.equal(closed.disconnectReason,undefined);
 assert.deepEqual(closed.clientFailure,{code:'network.game-session-failed',reason:'The client could not process a server update.',cause:{code:'network.object-import-failed',reason:'Native attack animation group is invalid'},phase:'playing',areaGeneration:7});
 assert.equal(row.diagnostics.at(-1).clientFailure.cause.reason,'Native attack animation group is invalid');
 closed.clientFailure.cause.reason='consumer mutation';assert.equal(row.value.state().clientFailure.cause.reason,'Native attack animation group is invalid');
});
test('normal disconnect stays silent and actual server reasons remain separate from local transport failure',async()=>{
 const normal=session();await normal.value.disconnect();assert.equal(normal.value.state().clientFailure,undefined);assert.equal(normal.value.state().disconnectReason,undefined);
 const server=session();server.peer.emit('closed',{failed:false,reason:{strRef:17,text:'Server maintenance'}});assert.equal(server.value.state().clientFailure,undefined);assert.deepEqual(server.value.state().disconnectReason,{strRef:17,text:'Server maintenance'});
 const transport=session();transport.peer.emit('closed',{failed:true});assert.equal(transport.value.state().clientFailure.code,'network.peer-failed');assert.equal(transport.value.state().disconnectReason,undefined);
});
test('delivery failure text is bounded and does not serialize Error stacks or key-shaped data',async()=>{
 const row=session(),key=['ABCDE','23456','FGHIJ','78901','KLMNO','34567','PQRST'].join('-');
 await rejectMessage(row,'Native invalid value\n'+key+' '+ 'x'.repeat(1000));
 const encoded=JSON.stringify(row.value.state().clientFailure);assert.ok(!encoded.includes(key));assert.ok(!row.value.clientFailure.cause.reason.includes('\n'));assert.ok(row.value.clientFailure.cause.reason.length<=384);assert.ok(!encoded.includes('stack'));
});
test('lobby surfaces local failure, clears it for retry, and rejects old-session late failure',async()=>{
 const rows=[],events=[];let lobby;
 lobby=new NativeLobby({listLocal:async()=>[],save:async()=>({}),readLocal:async()=>null,publish:v=>events.push(v),disconnect:async({targetSession})=>targetSession?.disconnect(),connect:async connection=>{const row=session();rows.push(row);lobby.attach(row.value,connection);row.value.publish();}});
 await lobby.join({connection:0});await rejectMessage(rows[0]);assert.match(lobby.error,/Native attack animation group is invalid/);assert.equal(lobby.snapshot().clientFailure.code,'network.game-session-failed');assert.equal(lobby.snapshot().canJoin,true);
 const detached=lobby.snapshot();detached.clientFailure.cause.reason='mutated';assert.match(lobby.snapshot().clientFailure.cause.reason,/attack animation/);
 await lobby.join({connection:1});assert.equal(lobby.error,'');assert.equal(lobby.snapshot().clientFailure,undefined);
 rows[0].value.emit('state',{closed:true,phase:'closed',clientFailure:{code:'old',reason:'stale failure'}});assert.equal(lobby.error,'');assert.equal(lobby.session,rows[1].value);
 await rejectMessage(rows[1],'Native second attempt failed');assert.match(lobby.error,/second attempt/);assert.equal(events.at(-1).connection,2);
 await lobby.leave({connection:2,saveCharacter:false});assert.equal(lobby.error,'');assert.equal(lobby.snapshot().clientFailure,undefined);
});
test('expected portal-origin closure stays silent and a real server reason keeps its existing text',()=>{
 const value=new EventEmitter();Object.assign(value,{closed:false,phase:'playing',portalHandoffReady:true});
 const lobby=new NativeLobby({publish(){}});lobby.connection=1;lobby.attach(value,1);
 value.closed=true;value.emit('state',{closed:true,phase:'closed',clientFailure:{code:'ignored',reason:'origin retired'}});assert.equal(lobby.error,'');assert.equal(lobby.phase,'transferring');
 value.portalHandoffReady=false;value.emit('state',{closed:true,phase:'closed',disconnectReason:{strRef:17,text:'Server maintenance'}});assert.equal(lobby.error,'Server maintenance');
});
test('terminal journal writes before finish, independent of the ordinary diagnostic cap, and deduplicates',async()=>{
 const report={diagnostics:Array(128).fill({code:'nonterminal'})},lines=[];let clock=100;
 const out=journal.createSessionFailureJournal({report,append:async text=>lines.push(JSON.parse(text)),now:()=>clock++});
 assert.equal(out.record({code:'network.packet',reason:'ignored'},1),false);
 const specific={code:'network.object-import-failed',reason:'Native attack animation group is invalid',credentials:{cdKey:'secret'}};
 assert.equal(out.record(specific,1),true);assert.equal(out.record(specific,1),false);
 out.record({code:'network.game-session-failed',reason:'Native game-message delivery failed',clientFailure:{code:'network.game-session-failed',reason:'Local client failure',cause:{code:specific.code,reason:specific.reason},credentials:'secret'}},1);
 await out.settled();assert.equal(lines.length,2);assert.equal(report.diagnostics.length,128);assert.equal(report.sessionFailures.length,2);assert.equal(lines[1].clientFailure.cause.reason,specific.reason);assert.ok(!JSON.stringify(lines).includes('secret'));
 out.record(specific,2);await out.settled();assert.equal(lines.at(-1).connection,2);
});
test('journal bounds retained history, projects known fields, and recovers after a failed append',async()=>{
 const report={},lines=[];let count=0;
 const out=journal.createSessionFailureJournal({report,limit:4,append:async line=>{if(++count===1)throw Error('fixture disk failure');lines.push(JSON.parse(line));}});
 for(let n=0;n<9;n++)out.record({code:'network.peer-failed',reason:'Failure '+n},n);
 out.record({code:'network.connect-failed',reason:'Connect failed',failure:{stage:'key-exchange',reason:'crypto-closed',password:'secret',cause:{private:'secret'}}},10);
 await out.settled();assert.equal(report.sessionFailures.length,4);assert.equal(report.sessionFailureJournalErrors,1);assert.equal(lines.length,9);assert.equal(report.connectionFailures.length,1);assert.ok(!JSON.stringify(lines).includes('secret'));
});
test('actual host diagnostic closure invokes the terminal journal and finish drains it',async()=>{
 const source=fs.readFileSync(new URL('../godot-client/tools/native-session-host.cjs',import.meta.url),'utf8'),body=source.match(/onDiagnostic:(d=>\{if\(report\.diagnostics\.length<128\)[\s\S]*?\}),persistCharacter:/)?.[1];assert.ok(body);
 const report={diagnostics:Array(128).fill({})},lines=[];const sessionFailureJournal=journal.createSessionFailureJournal({report,append:async line=>lines.push(JSON.parse(line))});
 const capture=vm.runInNewContext('('+body+')',{report,sessionFailureJournal,connection:8});capture({code:'network.object-import-failed',reason:'Native attack animation group is invalid'});await sessionFailureJournal.settled();
 assert.equal(lines.length,1);assert.equal(lines[0].connection,8);assert.ok(source.indexOf('await sessionFailureJournal.settled();')<source.indexOf('await fs.writeFile(output,JSON.stringify(report'));
});
