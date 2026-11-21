const {test}=require('node:test'),assert=require('node:assert/strict');
const {RawVisualEvents}=require('./raw-visual-events.cjs'),{RawCombatEvents}=require('./raw-combat-events.cjs');
test('raw visual transport shares canonical lifetimes, preserves duplicate effects and clones controller maps',()=>{
 const identities=new RawCombatEvents(),raw=new RawVisualEvents(identities),actor={id:1,areaId:2},world={areaId:2,registry:new Map([[1,actor]]),presentationChanges:[{action:'visual-effects',id:1,changes:[{action:'A',visualId:1,visualTransform:{keys:[0],entries:[{key:0,value:{identity:true}}]}}]}]};
 const one=raw.frame(world,3,4,{kind:'object-updates'}),two=raw.frame(world,3,4,{kind:'object-updates'});
 assert.equal(one.events[0].lifetime,identities.object(actor).nativeLifetime);assert.equal(two.serial,one.serial+1);assert.equal(one.connection,4);assert.equal(one.generation,3);
 one.events[0].changes[0].visualTransform.keys.push(2);assert.deepEqual(world.presentationChanges[0].changes[0].visualTransform.keys,[0]);
 actor.replicationRemoved=true;assert.equal(raw.frame(world,3,4,{kind:'object-updates'}),null);
});
test('instant packets remain raw and never create canonical point proxies or interpret tables',()=>{
 const identities=new RawCombatEvents(),raw=new RawVisualEvents(identities),world={areaId:2,registry:new Map(),presentationChanges:[]},message={kind:'object-visual',targetId:0x7f000000,visualId:69,position:[1,2,3]};
 const frame=raw.frame(world,3,4,message);assert.equal(world.registry.size,0);assert.equal(frame.events[0].lifetime,0);assert.equal(frame.events[0].id,message.targetId);assert.deepEqual(frame.events[0].message,message);frame.events[0].message.position[0]=5;assert.equal(message.position[0],1);
});
test('extended visual source identity rejects stale sources without inventing a dummy',()=>{
 const identities=new RawCombatEvents(),raw=new RawVisualEvents(identities),source={id:1,areaId:2},target={id:3,areaId:2},world={areaId:2,registry:new Map([[1,source],[3,target]])};
 const packet={kind:'object-visual',targetId:3,sourceId:1,visualId:73,duration:5,sourcePart:1,targetPart:0};
 const before=raw.frame(world,3,4,packet).events[0];assert.equal(before.sourceLifetime,identities.identity(source));assert.equal(before.lifetime,identities.identity(target));
 source.replicationRemoved=true;assert.equal(raw.frame(world,3,4,packet).events[0].sourceLifetime,0);
 const replacement={id:1,areaId:2};world.registry.set(1,replacement);assert.notEqual(raw.frame(world,3,4,packet).events[0].sourceLifetime,before.sourceLifetime);
 replacement.areaId=5;assert.equal(raw.frame(world,3,4,packet).events[0].sourceLifetime,0);
 target.areaId=5;assert.equal(raw.frame(world,3,4,packet),null);assert.equal(world.registry.size,2);
});
test('area visual messages retain packet values and clone independently without canonical allocation',()=>{
 const raw=new RawVisualEvents(new RawCombatEvents()),world={areaId:2,registry:new Map()},packet={kind:'area-visual',visualId:69,position:[1.25,2.5,3.75],duration:0};
 const frame=raw.frame(world,9,11,packet);assert.deepEqual([frame.connection,frame.generation,frame.areaId],[11,9,2]);
 assert.deepEqual(frame.events,[{kind:'area',id:0x7f000000,lifetime:0,message:packet}]);frame.events[0].message.position[0]=8;assert.equal(packet.position[0],1.25);assert.equal(world.registry.size,0);
});
test('safe projectile transport forwards only decoded headers and canonical source/target lifetimes',()=>{
 const identities=new RawCombatEvents(),raw=new RawVisualEvents(identities),source={id:1,areaId:2},target={id:3,areaId:2},world={areaId:2,registry:new Map([[1,source],[3,target]])};
 const packet={kind:'safe-projectile',header:{sourceId:1,targetId:3,from:[1,2,3],to:[4,5,6],appearance:6,spellId:0,duration:1000}};
 const event=raw.frame(world,5,6,packet).events[0];assert.equal(event.kind,'projectile');assert.equal(event.sourceLifetime,identities.identity(source));assert.equal(event.lifetime,identities.identity(target));event.message.header.from[0]=8;assert.equal(packet.header.from[0],1);
 world.registry.set(3,{id:3,areaId:2});assert.notEqual(raw.frame(world,5,6,packet).events[0].lifetime,event.lifetime);world.registry.delete(3);assert.equal(raw.frame(world,5,6,packet).events[0].lifetime,0);assert.equal(world.registry.size,1);
});
