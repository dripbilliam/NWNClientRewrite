const test=require('node:test'),assert=require('node:assert/strict');
const Owner=require('../tools/native-creation-hp-owner.cjs');
const Proof=require('../tools/native-creation-hp-proof.cjs');
async function fixture(){
 const {EntityDisclosureLifetimes}=await import('../../src/network_entity_lifetimes.js');
 const actor={id:0xffffffff,objectType:5,areaId:0x80000001,replicated:{hitPoints:{current:7,maximum:7,fieldE8:0}}};
 const world={localObjectId:actor.id,areaId:actor.areaId,registry:new Map([[actor.id,actor]]),entityDisclosures:new EntityDisclosureLifetimes()};
 return {actor,world,session:{world,peer:{closed:false},closed:false,areaGeneration:1},connection:1};
}
test('actual disclosure owner rejects numeric ID and binds the exact canonical object through export',async()=>{
 const f=await fixture();assert.equal(f.world.entityDisclosures.token(f.actor.id),null);
 const owner=Owner.capture(f.session,1);assert.strictEqual(owner.actor,f.actor);assert.equal(owner.scope.actorLifetime,f.world.entityDisclosures.token(f.actor));assert(owner.scope.actorLifetime>0);
 const received=Owner.witness(owner,f.session,f.session,1,true);assert.equal(received.currentScope,true);assert.equal(received.current,7);assert.equal(received.maximum,7);assert.equal(received.temporary,0);
 const expected={HitPoints:4,CurrentHitPoints:4,MaxHitPoints:6,PregameCurrent:6},server={...expected,MaxHitPoints:7,PregameCurrent:7};
 const typed=values=>({values,types:Object.fromEntries(Object.keys(values).map(key=>[key,3]))});
 assert.equal(Proof.compare(expected,typed(expected),typed(server),false,received).success,true);
 Owner.assertCurrent(owner,f.session,1);
});
test('actual removal, same-ID replacement and disclosure reset retire request-to-callback identity',async()=>{
 for(const retire of [f=>{f.actor.replicationRemoved=true;},f=>{f.world.registry.delete(f.actor.id);},f=>{f.world.registry.set(f.actor.id,{...f.actor,replicated:{hitPoints:{current:99,maximum:99,fieldE8:0}}});},f=>{f.world.entityDisclosures.observeAccepted([{action:'delete',id:f.actor.id}],f.world.registry);},f=>{f.world.entityDisclosures.reset();}]){
  const f=await fixture(),owner=Owner.capture(f.session,1);retire(f);
  assert.equal(Owner.current(owner,f.session,1),false);assert.throws(()=>Owner.assertCurrent(owner,f.session,1),/retired/);
  const received=Owner.witness(owner,f.session,f.session,1,true);assert.equal(received.currentScope,false);assert.equal(received.current,null);
 }
});
test('session, peer, world, scope and final post-await lifetime fences remain mandatory',async()=>{
 for(const retire of [f=>{f.session.closed=true;},f=>{f.session.peer.closed=true;},f=>{f.session.peer={closed:false};},f=>{f.session.world={...f.world};},f=>{f.session.areaGeneration++;},f=>{f.world.areaId++;},f=>{f.world.localObjectId=42;},f=>{f.actor.destroyed=true;}]){
  const f=await fixture(),owner=Owner.capture(f.session,1);retire(f);assert.equal(Owner.current(owner,f.session,1),false);
 }
 const f=await fixture(),owner=Owner.capture(f.session,1);
 assert.equal(Owner.current(owner,f.session,2),false);assert.equal(Owner.current(owner,{...f.session},1),false);assert.equal(Owner.witness(owner,{...f.session},f.session,1,true).currentScope,false);
 f.world.entityDisclosures.maximumSerial=0;f.world.entityDisclosures.reset();assert.throws(()=>Owner.capture(f.session,1),/lifetime/);
});
