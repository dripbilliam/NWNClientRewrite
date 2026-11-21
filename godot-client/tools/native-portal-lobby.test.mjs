import test from 'node:test';import assert from 'node:assert/strict';import {EventEmitter} from 'node:events';import {NativeLobby} from './native-lobby.mjs';
class Session extends EventEmitter{
 constructor(){super();this.phase='playing';this.closed=false;}
 set(phase,closed=false){this.phase=phase;this.closed=closed;this.emit('state',{phase,closed});}
}
async function fixture(){
 let lobby;const old=new Session(),events=[],disconnections=[];
 lobby=new NativeLobby({listLocal:async()=>[],connect:async c=>lobby.attach(old,c),disconnect:async options=>disconnections.push(options),publish:v=>events.push(v)});
 await lobby.join({connection:0});old.set('transferring');old.portalTransfer={pending:{}};
 return{old,lobby,events,disconnections,release(){old.portalHandoffReady=true;old.set('closed',true);return lobby.advancePortal(old,{host:'127.0.0.1',port:5122});}};
}
test('old-server handoff remains cancellable and cannot admit an unrelated login while no destination is attached',async()=>{
 const f=await fixture();assert.equal(f.lobby.snapshot().canCancelJoin,true);const c=f.release();assert.equal(c,2);assert.equal(f.lobby.session,null);assert.equal(f.lobby.snapshot().canJoin,false);assert.equal(f.lobby.snapshot().canCancelJoin,true);
 await assert.rejects(f.lobby.join({connection:c}),/Disconnect/);await f.lobby.cancelJoin({connection:c});assert.deepEqual(f.disconnections,[{saveCharacter:false,targetSession:null}]);assert.equal(f.lobby.snapshot().canJoin,true);assert.equal(f.lobby.snapshot().canCancelJoin,false);
 assert.throws(()=>f.lobby.attach(new Session(),c),/Cancelled/);
});
test('destination setup releases busy and remains cancellable through connection and resources until playing',async()=>{
 const f=await fixture(),c=f.release(),next=new Session();f.lobby.attach(next,c);
 assert.equal(f.lobby.busy,false);assert.equal(f.lobby.snapshot().canCancelJoin,true);
 next.set('connecting');assert.equal(f.lobby.snapshot().canCancelJoin,true);next.set('resources');assert.equal(f.lobby.snapshot().canCancelJoin,true);
 next.set('character-selection');next.localVaultAllowed=true;next.resourceResult={ready:true};next.resolver={};assert.equal(f.lobby.snapshot().canSelect,false);assert.equal(f.lobby.snapshot().canCreate,false);await assert.rejects(f.lobby.choose({connection:c,key:'unrelated'}),/unavailable/);
 next.set('playing');assert.equal(f.lobby.snapshot().canCancelJoin,false);assert.equal(f.lobby.transferring,false);assert.equal(f.lobby.snapshot().connected,true);
});
test('late origin state and a failed destination cannot leave a stuck transfer or clear a newer lobby',async()=>{
 const f=await fixture(),c=f.release(),next=new Session();f.lobby.attach(next,c);f.old.set('playing');assert.equal(f.lobby.session,next);assert.equal(f.lobby.transferring,true);
 next.set('closed',true);assert.equal(f.lobby.transferring,true);assert.equal(f.lobby.busy,true);assert.equal(f.lobby.snapshot().canJoin,false);
 f.lobby.failPortal(c,'Destination failed');assert.equal(f.lobby.phase,'menu');assert.equal(f.lobby.error,'Destination failed');
 assert.equal(f.lobby.snapshot().canJoin,true);
 f.lobby.connection++;f.lobby.phase='playing';f.lobby.failPortal(c,'stale');assert.equal(f.lobby.phase,'playing');
});

test('after connect settles, a later resource disconnect releases normally; source preparation failure does not wait for a destination callback',async()=>{
 const f=await fixture(),c=f.release(),next=new Session();f.lobby.attach(next,c);next.set('resources');f.lobby.portalConnected(next,c);next.set('closed',true);assert.equal(f.lobby.snapshot().canJoin,true);assert.equal(f.lobby.transferring,false);
 const g=await fixture();g.old.set('closed',true);assert.equal(g.lobby.snapshot().canJoin,true);assert.equal(g.lobby.transferring,false);
});
test('advance requires the exact released portal owner and resource failure remains cancellable',async()=>{
 const f=await fixture();assert.throws(()=>f.lobby.advancePortal(f.old,{}),/no longer owns/);assert.throws(()=>f.lobby.advancePortal(new Session(),{}),/no longer owns/);
 const c=f.release(),next=new Session();f.lobby.attach(next,c);next.set('resources-unavailable');assert.equal(f.lobby.snapshot().canCancelJoin,true);assert.match(f.lobby.error,/content/);
 await f.lobby.cancelJoin({connection:c});assert.equal(f.lobby.snapshot().canJoin,true);
});
