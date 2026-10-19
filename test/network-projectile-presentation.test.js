import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {networkProjectilePose} from '../src/network_projectile_presentation.js';
test('native projectile mirrors use replicated XYZ and preserve static pose when an update only changes animation',()=>{
 const object={staticState:{position:[1,2,3],orientation:[0,1,0]},replicated:{animation:14}},before=structuredClone(object);assert.deepEqual(networkProjectilePose(object),{position:[1,2,3],orientation:[0,1,0]});assert.deepEqual(object,before);
 object.replicated.position=[4,5,6];object.replicated.orientation={vector:[1,0,0]};assert.deepEqual(networkProjectilePose(object),{position:[4,5,6],orientation:[1,0,0]});assert.throws(()=>networkProjectilePose({replicated:{animation:14}}),/position/);
});
test('final vanilla ranger run renders and expires every server projectile, destroys its target and returns to ready',()=>{
 const r=JSON.parse(fs.readFileSync(new URL('../backups/animations/local-network-renderer-v43.json',import.meta.url))),wire=JSON.parse(fs.readFileSync(new URL('../backups/animations/network-attack-replay-v43.json',import.meta.url))),diagnostics=JSON.parse(fs.readFileSync(new URL('../backups/animations/local-network-renderer-v43-diagnostics.json',import.meta.url))),last=r.samples.at(-1),p=last.projectiles;
 assert.equal(r.connected,true);assert.equal(r.failure,undefined);assert.equal(r.sampleFailure,undefined);assert.equal(r.states.at(-1).phase,'closed');assert.equal(r.offscreen,true);assert.ok(r.paintFrames>2000);
 assert.equal(wire.attacks.length,7);assert.equal(wire.projectiles.length,7);assert.ok(wire.projectiles.every(p=>p.sourceId===0xffffffff&&p.targetId===0x80000012&&p.baseItem===8&&p.appearance===0));
 assert.equal(p.received,7);assert.equal(p.spawned,7);assert.equal(p.loaded,7);assert.equal(p.impacts,7);assert.equal(p.destroyed,7);assert.equal(p.failed,0);assert.deepEqual(p.active,[]);assert.equal(p.events.filter(e=>e.kind==='impactAttach'&&e.attached&&e.part==='a08_impact').length,7);
 assert.deepEqual(p.events.filter(e=>e.kind==='loaded').map(e=>e.id),[0,1,2,3,4,5,6]);assert.ok(last.combat.events.some(e=>e.clip==='bowshot'));assert.deepEqual(last.combat.actors.find(a=>a.id===0xffffffff),{id:0xffffffff,animation:1,pending:0,remaining:null,deferred:false});assert.equal(last.scene.objects.some(o=>o.id===0x80000012),false);
 assert.equal(diagnostics.some(d=>d.severity==='error'||/projectile-(receiver|update|model)-failed|scene-combat-unhandled/.test(d.code)),false);
 assert.deepEqual(wire.unhandled.map(u=>u.reason),['Inventory channel Q is unavailable']);assert.ok(diagnostics.some(d=>d.code==='network.scene-projectile-audio-unhandled'));
});
