import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {EventEmitter} from 'node:events';
import {NetworkGameSession} from '../electron/network_game_session.mjs';
import {attackRequest} from '../src/network_player_requests.js';
import {OBJECT_INVALID} from '../src/game_object_array.js';
import {cancelPolymorphRequest} from '../src/network_polymorph_input.js';

function fixture(){
 const peer=new EventEmitter(),sent=[];peer.sendGameMessage=async bytes=>sent.push([...bytes]);
 const session=new NetworkGameSession({peer,identity:{dispose(){}},build:{build:{number:8193,revision:35,postfix:0},dispose(){}},resources:{},language:0,openModule:async()=>({}),decodeMessage:m=>m});
 const actor={id:0xfffffff1,objectType:5,areaId:0x80000007,replicated:{field8D4:129,field8D6:2,field8D8:0x80000008},playerState:{actionQueue:[{type:3,group:17}]}};
 session.phase='playing';session.areaReadySent=true;session.areaGeneration=7;session.world.areaId=actor.areaId;session.world.localObjectId=actor.id;session.world.registry.addObjectAtPos(actor.id,actor);
 return{session,actor,sent,scope:{areaId:actor.areaId,areaGeneration:7,actorId:actor.id}};
}
test('world Disengage uses original attack INVALID and awaits server state',async()=>{
 const {session:s,actor,sent,scope}=fixture(),before=structuredClone(actor);
 assert.deepEqual(await s.disengage(scope),{sent:true,serverAcknowledged:false});
 assert.deepEqual(sent,[[...attackRequest({targetId:OBJECT_INVALID})]]);assert.deepEqual(actor,before);
});
test('world Disengage rejects stale actor, area generation, transition, removal and disconnected scope',async()=>{
 const {session:s,actor,sent,scope}=fixture();
 for(const change of [{actorId:99},{areaId:6},{areaGeneration:6},{actorId:undefined}])await assert.rejects(s.disengage({...scope,...change}));
 s.phase='area-loading';await assert.rejects(s.disengage(scope));s.phase='playing';
 actor.replicationRemoved=true;await assert.rejects(s.disengage(scope));actor.replicationRemoved=false;
 s.world.localObjectId=actor.id-1;await assert.rejects(s.disengage(scope));s.world.localObjectId=actor.id;
 s.closed=true;await assert.rejects(s.disengage(scope));assert.equal(sent.length,0);
});
test('host preserves private controlled ID for Disengage rather than replacing old actor scope',()=>{
 const source=fs.readFileSync(new URL('../godot-client/tools/native-session-host.cjs',import.meta.url),'utf8');
 assert.match(source,/if\(\[[^\n]*'native-disengage'[^\n]*\.includes\(message\.kind\)\)input\.actorId=message\.actorId/);
 assert.match(source,/'native-disengage':'disengage'/);
});
test('direct world CancelShape uses current actor6/30 without a quickbar or local prediction',async()=>{
 const {session:s,actor,sent,scope}=fixture(),before=structuredClone(actor);
 assert.deepEqual(await s.cancelPolymorph(scope),{sent:true,serverAcknowledged:false});
 assert.deepEqual(sent,[[...cancelPolymorphRequest({actorId:actor.id})]]);assert.deepEqual(actor,before);
 for(const change of [{actorId:99},{areaGeneration:6},{areaId:7}])await assert.rejects(s.cancelPolymorph({...scope,...change}));assert.equal(sent.length,1);
 s.closed=true;await assert.rejects(s.cancelPolymorph(scope));
});
