import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {EntityDisclosureLifetimes} from '../src/network_entity_lifetimes.js';
import {NetworkWorld} from '../src/network_world.js';
import {entityLifetimeTrace} from '../godot-client/tests/entity_lifetime_world_fixture.mjs';
test('actual World to raw framing preserves coalesced disclosure retirements without changing renderer lifetime',()=>{
 const trace=entityLifetimeTrace();assert.equal(trace.stages.length,10);assert.equal(trace.stages.filter(s=>s.frames.length).length,8);
 const [first,repeat,coalesced,packet,rollback,area,removed,recreated,reset,reconnect]=trace.stages;
 assert.equal(first.disclosure,repeat.disclosure);assert.notEqual(first.disclosure,coalesced.disclosure);assert.notEqual(packet.disclosure,coalesced.disclosure);
 assert.equal(rollback.disclosure,packet.disclosure);assert.equal(area.disclosure,packet.disclosure);assert.equal(removed.disclosure,null);
 assert.ok(recreated.disclosure>packet.disclosure);assert.ok(reset.disclosure>recreated.disclosure);assert.equal(reconnect.disclosure,first.disclosure);
 assert.equal(first.renderLifetime,coalesced.renderLifetime);assert.equal(first.renderLifetime,packet.renderLifetime);
 for(const stage of trace.stages)for(const frame of stage.frames){assert.equal(frame.connection,stage.connection);assert.equal(frame.generation,stage.generation);}
});
test('retirement work visits only incoming delete records, not a registry enumeration',()=>{
 const helper=new EntityDisclosureLifetimes(),a={},b={},tokens=[helper.token(a),helper.token(b)],lookups=[];
 const registry={get(id){lookups.push(id);return id===1?a:b;}};
 helper.observeAccepted([...Array.from({length:1000},(_,id)=>({action:'update',id})),{action:'delete',id:1}],registry);
 assert.deepEqual(lookups,[1]);assert.notEqual(helper.token(a),tokens[0]);assert.equal(helper.token(b),tokens[1]);
 const copy=helper.snapshot();copy.diagnostics.retired=999;assert.equal(helper.snapshot().diagnostics.retired,1);
});
test('reset keeps monotonic counters; exhaustion is explicit null metadata without changing live state',()=>{
 const helper=new EntityDisclosureLifetimes({maximumSerial:2}),a={id:1,replicated:{rank:4}},b={id:2};
 assert.equal(helper.token(a),1);helper.reset();assert.equal(helper.token(a),2);
 const before=structuredClone(b);assert.equal(helper.token(b),null);assert.deepEqual(b,before);assert.equal(helper.snapshot().diagnostics.exhausted,1);
 const tagged=helper.transportRow(b,{...b,nativeLifetime:99});assert.equal(tagged.clientKnownLifetime,null);assert.equal(tagged.nativeLifetime,99);assert.equal(Object.hasOwn(b,'clientKnownLifetime'),false);
});
test('repeated create alone and a rejected transaction do not retire a retained proxy',()=>{
 const world=new NetworkWorld({onDiagnostic:()=>{}}),id=0x80000002;world.areaId=0x80000001;
 world.apply({kind:'object-updates',records:[{action:'create',objectType:5,id,state:{}}]});const proxy=world.registry.get(id),token=world.entityDisclosures.token(proxy);
 world.apply({kind:'object-updates',records:[{action:'create',objectType:5,id,state:{}}]});assert.equal(world.entityDisclosures.token(proxy),token);
 assert.throws(()=>world.apply({kind:'object-updates',records:[{action:'delete',objectType:5,id,remove:0},{action:'create',objectType:5,id:1,state:{}}]}));
 assert.equal(world.registry.get(id),proxy);assert.equal(world.entityDisclosures.token(proxy),token);assert.equal(proxy.replicationRemoved,false);
});
test('actual host uses the same production disclosure tagger tested by the pipeline',()=>{
 const host=fs.readFileSync(new URL('../godot-client/tools/native-session-host.cjs',import.meta.url),'utf8');
 assert.match(host,/objects:\[\.\.\.session\.world\.registry\.objects\.values\(\)\]\.map\(object=>session\.world\.entityDisclosures\.transportRow\(object,\{\.\.\.rawCombat\.object\(object\),nativeActorNameState:session\.world\.nativeActorNameTransport\(object\)\}\)\)/);
 assert.match(host,/actorNameHistory:session\.world\.nativeActorNameHistory\(\)/);
});
