const {test}=require('node:test'),assert=require('node:assert/strict');
const {RawCombatEvents}=require('./raw-combat-events.cjs');
test('casting scalars precede the world snapshot with the same actor lifetime and private cloned data',()=>{
 const raw=new RawCombatEvents(),object={id:1,objectType:5,areaId:12,replicated:{animation:15,cast:{spell:107,silent:1}}},world={areaId:12,registry:new Map([[1,object]]),presentationChanges:[{id:1,action:'movement',changes:{animation:15}}]};
 const result=raw.frame(world,2,3);assert.deepEqual(result.events,[{id:1,action:'cast-state',animation:15,cast:{spell:107,silent:1},lifetime:raw.identity(object),ageMs:0}]);
 result.events[0].cast.spell=58;assert.equal(object.replicated.cast.spell,107);
 object.replicationRemoved=true;assert.equal(raw.frame(world,2,3),null);
 delete object.replicationRemoved;world.presentationChanges[0].changes={position:[1,2,3]};assert.equal(raw.frame(world,2,3),null);
 world.presentationChanges[0].changes={animation:0};delete object.replicated.cast;assert.equal(raw.frame(world,2,3),null);
});
test('raw combat delivery retains records and distinct identical rounds without preparing assets',()=>{
 const raw=new RawCombatEvents(),object={id:1,areaId:12,objectType:5},world={areaId:12,registry:new Map([[1,object]]),presentationChanges:[{id:1,action:'attack-animation',records:[{type:1,result:1,damage:7}]}]};
 const first=raw.frame(world,2,3),next=raw.frame(world,2,3);
 assert.equal(first.connection,3);assert.equal(first.areaId,12);assert.equal(first.generation,2);assert.equal(first.events[0].lifetime,raw.object(object).nativeLifetime);assert.equal(next.serial,first.serial+1);
 assert.deepEqual(first.events[0].records,world.presentationChanges[0].records);first.events[0].records[0].damage=0;assert.equal(world.presentationChanges[0].records[0].damage,7);
 assert.equal(Object.hasOwn(object,'nativeLifetime'),false);
});
test('removed/out-of-area actors are excluded; recycled IDs get a new lifetime',()=>{
 const raw=new RawCombatEvents(),old={id:1,areaId:12},registry=new Map([[1,old]]),world={areaId:12,registry,presentationChanges:[{id:1,action:'cast-animation',animation:17,record:{type:4}}]};
 const lifetime=raw.frame(world,1,1).events[0].lifetime;old.replicationRemoved=true;assert.equal(raw.frame(world,1,1),null);
 registry.set(1,{id:1,areaId:13});assert.equal(raw.frame(world,1,1),null);registry.set(1,{id:1,areaId:12});assert.ok(raw.frame(world,1,1).events[0].lifetime>lifetime);
});
