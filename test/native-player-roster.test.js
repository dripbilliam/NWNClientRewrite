import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {NetworkWorld} from '../src/network_world.js';
import {playerRosterEntryComplete,stagePlayerRoster,playerRosterHeader} from '../src/network_player_roster.js';
import {playerIdentityFixture} from '../godot-client/tests/native_player_identity_fixture.mjs';
const row=(id=1)=>({playerId:id,objectId:0x80000002,isDM:0,name:'Account',peerD8:0,peerC8:''});
test('full accepted roster knowledge follows exact structural wire schema, not nonempty data',()=>{
 const w=new NetworkWorld();assert.equal(w.playerRosterKnown,false);w.apply({kind:'player-list-add',players:[row()]});assert.equal(w.playerRosterKnown,false);
 w.apply({kind:'player-list-all',players:[{playerId:0,objectId:0x80000002}]});assert.equal(w.playerRosterKnown,false,'legacy incomplete fixtures cannot justify NPC negatives');
 w.apply({kind:'player-list-all',server140:0,players:[row()]});assert.equal(w.playerRosterKnown,true);
 w.apply({kind:'player-list-add',players:[row(2)]});assert.equal(w.playerRosterKnown,true);w.apply({kind:'player-list-delete',playerId:1});assert.equal(w.playerRosterKnown,true);
 w.apply({kind:'player-list-all',server140:0,players:[]});assert.equal(w.playerRosterKnown,true);w.reset();assert.equal(w.playerRosterKnown,false);
});
test('staged clone/identity failures preserve both existing maps and knowledge atomically',()=>{
 const w=new NetworkWorld();w.apply({kind:'player-list-all',server140:0,players:[row()]});const players=w.players,controls=w.controls,before=[...players],beforeControls=[...controls];
 for(const message of [{kind:'player-list-all',server140:0,players:[row(3),{...row(4),fn(){}}]},{kind:'player-list-add',players:[row(3),{...row(4),objectId:-1}]},{kind:'player-list-all',server140:0,players:null}]){assert.throws(()=>w.apply(message));assert.equal(w.players,players);assert.equal(w.controls,controls);assert.deepEqual([...players],before);assert.deepEqual([...controls],beforeControls);assert.equal(w.playerRosterKnown,true);}
 const input={kind:'player-list-all',server140:0,players:[row(5)]};w.apply(input);input.players[0].name='mutated';assert.equal(w.players.get(5).name,'Account');
});
test('schema completeness preserves absent character versus missing/partial fields',()=>{
 assert.equal(playerRosterEntryComplete(row()),true);assert.equal(playerRosterEntryComplete({playerId:1,objectId:2}),false);
 const complete={...row(),character:{id:0x80000003,firstName:{text:'PC'},lastName:{gender:0,strRef:1},portrait:6}};assert.equal(playerRosterEntryComplete(complete),true);
 for(const character of [null,{id:0x80000003},{...complete.character,portrait:65534},{...complete.character,id:-1}])assert.equal(playerRosterEntryComplete({...row(),character}),false);
 assert.equal(stagePlayerRoster({kind:'player-list-all',server140:0,players:[row(),row()]}).complete,false,'duplicate IDs do not prove a complete original roster');
});
test('actual Session World host fixture preserves selected/control distinction and source knowledge',async()=>{
 const trace=await playerIdentityFixture();assert.equal(trace.success,true);assert.equal(trace.stages.length,19);
 assert.equal(trace.stages[0].header.playerRosterKnown,false);assert.equal(trace.stages[3].header.playerRosterKnown,true);
 assert.equal(trace.stages[3].header.players[0][1].character.id,0x80000002);assert.equal(trace.stages[3].header.players[0][1].objectId,0x80000003);
 assert.equal(trace.stages.at(-1).header.gameMasterPermission,null);
 const host=fs.readFileSync(new URL('../godot-client/tools/native-session-host.cjs',import.meta.url),'utf8');assert.match(host,/ui:\{\.\.\.playerRosterHeader\(session\.world\),guiPanelAccess:/);
});
