import test from 'node:test';import assert from 'node:assert/strict';import {Group} from 'three';
import {ResourcePrefetch} from '../src/resource_prefetch.js';import {NetworkScene} from '../src/network_scene.js';
const gate=()=>{let resolve;const promise=new Promise(r=>resolve=r);return{promise,resolve};},turn=()=>new Promise(r=>setImmediate(r));

test('prefetch bounds independent source work, coalesces duplicate keys and skips retired requests',async()=>{
 const gates=Array.from({length:6},gate),started=[];let alive=true,peak=0,active=0;
 const q=new ResourcePrefetch({read:async request=>{started.push(request.key);peak=Math.max(peak,++active);await gates[request.key].promise;active--;},limit:2});
 q.enqueue(Array.from({length:6},(_,key)=>({key,current:()=>key!==4||alive})));q.enqueue([{key:3,current:()=>true}]);await turn();assert.deepEqual(started,[0,1]);alive=false;
 for(const g of gates)g.resolve();await q.idle();assert.equal(peak,2);assert.deepEqual(started,[0,1,2,3,5]);assert.equal(q.snapshot().skipped,1);assert.equal(q.snapshot().completed,5);q.close();q.enqueue([{key:7}]);assert.equal(q.snapshot().pending,0);
});

function sceneFixture(server='A'){
 const objects=new Map(),started=[],created=[],prepared=[],released=[],reports=[],gates=new Map(),world={localObjectId:1,registry:{objects,get:id=>objects.get(id)}};
 const scene=new NetworkScene({world,resolver:{server},loadAsset:async(name,resolver)=>{started.push(name);await gates.get(name)?.promise;if(name==='missing')throw Error('missing');return{model:{nodes:[],animations:[],server:resolver.server},textures:new Map()};},prepareAsset:async(_asset,name)=>prepared.push(name),instantiate:(asset,name)=>{created.push(name);return{root:new Group(),dispose(){},server:asset.model.server};},releaseAsset:asset=>released.push(asset),report:(...args)=>reports.push(args)});
 scene.area={id:7};scene.tables={placeables:{rows:new Map(Array.from({length:8},(_,i)=>[i,{ModelName:'source'+i}]))}};
 const add=(id,appearance)=>{const object={id,objectType:9,areaId:7,replicated:{appearance,position:[1,2,3]}};objects.set(id,object);return object;};return{scene,objects,started,created,prepared,released,reports,gates,add};
}

test('player source is first, background data overlaps a blocked NPC without constructing or preparing it early',async()=>{
 const f=sceneFixture();f.add(2,1);f.add(3,2);f.add(4,3);f.add(1,0);const player=gate(),npc=gate();f.gates.set('source0',player);f.gates.set('source1',npc);
 const work=f.scene.requestSync();await turn();assert.deepEqual(f.started,['source0']);assert.deepEqual(f.created,[]);player.resolve();await turn();
 assert.deepEqual(f.created,['source0']);assert.ok(f.started.includes('source2'));assert.ok(f.started.includes('source3'));assert.ok(!f.prepared.includes('source2'));assert.ok(!f.prepared.includes('source3'));
 npc.resolve();await work;assert.deepEqual(f.created,['source0','source1','source2','source3']);assert.equal(new Set(f.started).size,f.started.length);assert.equal(f.scene.objects.size,4);await f.scene.dispose();assert.equal(f.released.length,4);
});

test('foreground bypasses the queued prefetch and shares its actual owning cache promise',async()=>{
 const f=sceneFixture(),held=gate();f.gates.set('source0',held);f.gates.set('source1',held);for(let i=0;i<7;i++)f.add(i+2,i);
 f.scene.prefetchObjects([...f.objects.values()]);await turn();assert.deepEqual(f.started,['source0','source1']);
 const foreground=await f.scene.model('source6');assert.equal(foreground.server,'A');assert.deepEqual(f.started,['source0','source1','source6']);assert.deepEqual(f.prepared,['source6']);held.resolve();await f.scene.sourcePrefetch.idle();assert.equal(f.started.filter(n=>n==='source6').length,1);await f.scene.dispose();
});

test('queued obsolete appearances and closed scenes never read or instantiate their sources',async()=>{
 const f=sceneFixture(),held=gate();f.gates.set('source0',held);f.gates.set('source1',held);f.add(2,0);f.add(3,1);const stale=f.add(4,2);f.add(5,3);
 f.scene.prefetchObjects([...f.objects.values()]);await turn();stale.replicated.appearance=6;const closed=f.scene.dispose();held.resolve();await closed;assert.deepEqual(f.started,['source0','source1']);assert.deepEqual(f.created,[]);assert.deepEqual(f.prepared,[]);assert.equal(f.scene.assets.size,0);assert.equal(f.scene.sourcePrefetch.snapshot().queued,0);assert.equal(f.released.length,2);
});

test('an obsolete queued appearance is skipped while its still-live replacement can be prefetched',async()=>{
 const f=sceneFixture(),held=gate();f.gates.set('source0',held);f.gates.set('source1',held);f.add(2,0);f.add(3,1);const changed=f.add(4,2);
 f.scene.prefetchObjects([...f.objects.values()]);await turn();changed.replicated.appearance=6;held.resolve();await f.scene.sourcePrefetch.idle();assert.ok(!f.started.includes('source2'));assert.equal(f.scene.sourcePrefetch.snapshot().skipped,1);
 f.scene.prefetchObjects([...f.objects.values()]);await f.scene.sourcePrefetch.idle();assert.ok(f.started.includes('source6'));assert.deepEqual(f.created,[]);await f.scene.dispose();
});

test('prefetch failures stay with their consumer and equal names cannot cross resource contexts',async()=>{
 const a=sceneFixture('A'),b=sceneFixture('B');for(const f of [a,b]){f.scene.tables.placeables.rows.set(0,{ModelName:'missing'});f.add(2,0);f.scene.prefetchObjects([...f.objects.values()]);await f.scene.sourcePrefetch.idle();assert.deepEqual(f.reports,[]);await assert.rejects(f.scene.model('missing'),/missing/);}
 assert.equal((await a.scene.model('same')).server,'A');assert.equal((await b.scene.model('same')).server,'B');await a.scene.dispose();await b.scene.dispose();
});

test('multipart creature source plans retain per-part palettes, PLT candidates, fallback bodies and mounts without instances',async()=>{
 const f=sceneFixture(),parts=Array(19).fill(0);parts[7]=3;parts[18]=3;
 const appearance={columns:['MODELTYPE','RACE','WING_TAIL_SCALE'],rows:new Map([[0,{MODELTYPE:'P',RACE:'h',WING_TAIL_SCALE:'1'}]])},columns=['label','name',...Array.from({length:19},(_,i)=>'hide'+i)],hide=Object.fromEntries(columns.slice(2).map(name=>[name,'1']));hide.hide7='0';
 Object.assign(f.scene.tables,{appearance,racialtypes:{rows:new Map([[0,{}]])},gender:{rows:new Map([[0,{GENDER:'m'}]])},phenotype:{rows:new Map([[2,{DefaultPhenoType:'0'}]])},capart:{rows:new Map([[7,{MDLNAME:'chest',NODENAME:'torso_g'}],[18,{MDLNAME:'robe',NODENAME:'torso_g'}]])},parts_robe:{columns,rows:new Map([[3,hide]])},tailmodel:{rows:new Map([[1,{MODEL:'horse'}]])}});
 const actor={id:9,objectType:5,areaId:7,replicated:{position:[0,0,0],stats:{racialType:0}},appearance:{appearance:0,head:1,gender:0,phenotype:2,skin:5,hair:6,tattoo1:7,tattoo2:8,fieldAA4:1,equipment:[{slot:2,item:{modelType:3,parts,colors:[2,3,4,5,6,7],partColors:{7:[10,11,12,13,14,15]}}}]}};f.objects.set(actor.id,actor);
 const original=f.scene.loadAsset;f.scene.loadAsset=async(...args)=>{if(args[0].startsWith('pmh2'))throw Error('missing phenotype');return original(...args);};
 f.scene.prefetchObjects([actor]);await f.scene.sourcePrefetch.idle();const keys=[...f.scene.assets.keys()].map(key=>JSON.parse(key));
 const chest=keys.find(([name])=>name==='pmh0_chest003');assert.deepEqual(chest[1],[5,6,14,15,12,13,10,11,7,8]);assert.ok(chest[2].includes('pmh2_chest003'));assert.ok(chest[2].includes('pmh0_chest003'));
 assert.ok(keys.some(([name])=>name==='pmh0'));assert.ok(keys.some(([name])=>name==='pmh0_head001'));assert.ok(keys.some(([name])=>name==='pmh0_robe003'));assert.deepEqual(keys.find(([name])=>name==='horse')[2],['horse']);assert.deepEqual(f.created,[]);assert.deepEqual(f.prepared,[]);assert.equal(f.scene.sourcePrefetch.snapshot().failed,0);await f.scene.dispose();
});
