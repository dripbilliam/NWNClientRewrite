import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {spellCastRequest} from '../src/network_spell_input.js';
import {NetworkSpellTargeting} from '../src/network_spell_targeting.js';
import {NetworkWorld} from '../src/network_world.js';
import {parse2da} from '../src/area.js';
import {clientSpellUsesLeft} from '../src/network_spellbook.js';
import {clientCastAnimationCue,networkCastReleaseBase,networkCastAnimationRecord} from '../src/network_cast_animation.js';
const fixture=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-network-spell-input-observations.json',import.meta.url)));
test('240 original cast-action playback cases select500ms native FLOAT speed and preserve type4 target records',()=>{
 const f=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-network-spell-animation-observations.json',import.meta.url)));assert.equal(f.target,fixture.target);assert.equal(f.cases.length,240);
 for(const row of f.cases){const c=row.case,record={type:4},cue=clientCastAnimationCue(c.animation,c.length,record);assert.equal(row.calls.length,1);const n=row.calls[0];assert.equal(cue.animation,n.animation);assert.equal(cue.duration,n.duration);assert.equal(cue.speed,n.speed);assert.equal(cue.delay,n.delay);assert.equal(n.sameRecord,true);}
 assert.deepEqual([17,18,19,20,61].map(networkCastReleaseBase),[250,251,252,253,261]);assert.equal(networkCastReleaseBase(16),null);assert.deepEqual(networkCastAnimationRecord({targetType:1,target:0xffffffff,spell:123,field220:500}),{type:4,targetType:1,targetId:0xffffffff,position:[0,0,0],spellId:123,field38:500});
});
test('581 original client spell-use counts retain master, domain, ready BYTE and overlapping metamagic semantics',()=>{
 const f=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-network-spell-use-observations.json',import.meta.url)));assert.equal(f.target,fixture.target);assert.equal(f.cases.length,581);
 for(const row of f.cases){const c=row.case,p={classCount:()=>c.classCount??8,spell:id=>c.missingSpell?null:{id,master:id===1?c.master??1:2},classType:()=>10,level:()=>c.level,confirmDomain:()=>c.domainValid??1,metaCost:()=>c.metaCost??0,memorizes:()=>c.memo,usesLeft:()=>c.perDay,memorized:()=>c.slots};assert.equal(clientSpellUsesLeft(1,c.index,c.domain,c.meta,p),row.result,JSON.stringify(c));}
});
test('331 full original spell sender/server-reader cases retain native bytes, masks, positions and conversion admission',()=>{
 assert.equal(fixture.target,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');assert.equal(fixture.cases.length,331);
 for(const row of fixture.cases){const c=row.case;if(c.format!==1)continue;const actual=spellCastRequest({...c,position:c.point,spontaneous:Boolean(c.conversion),targetType:c.missingClientSpell?0:c.targetType??127}),native=Buffer.from(row.packet,'hex'),used=native.at(-1)>>>5,mask=255<<(8-used)&255;assert.equal(actual.length,native.length);assert.deepEqual(Buffer.from(actual.subarray(0,-1)),native.subarray(0,-1),JSON.stringify(c));assert.equal(actual.at(-1)&mask,native.at(-1)&mask,JSON.stringify(c));
  const cast=row.calls.find(v=>v.kind==='cast');if(cast){assert.equal(cast.spell,c.spellId);assert.equal(cast.classIndex,c.classIndex);assert.equal(cast.domainLevel,c.domainLevel);assert.equal(cast.metamagic,c.metamagic);assert.equal(cast.targetId,c.targetId===0x7f000000?c.targetId:(c.targetId&0x7fffffff)>>>0);assert.equal(cast.instant,0);assert.equal(cast.itemId,0xffffffff);}
 }
 for(const flag of ['noActor','noStats','badCast','blocked','missingServerSpell'])assert.ok(fixture.cases.filter(r=>r.case[flag]).every(r=>!r.calls.some(v=>v.kind==='cast')));
 assert.ok(fixture.cases.some(r=>r.case.conversion&&r.case.uses===0&&r.case.slots?.some(s=>s.ready&&!s.domain)&&r.calls.some(v=>v.kind==='cast'&&v.conversion===1)));
});
test('invalid spell input is rejected before serializing an unsigned ID or floating point payload',()=>{
 const base={spellId:1,targetType:127};for(const fields of [{spellId:-1},{spellId:0x100000000},{targetId:-1},{classIndex:256},{domainLevel:-1},{metamagic:NaN},{spontaneous:2},{targetType:65536},{position:[0,0,NaN]},{position:[0,0,1e50]}])assert.throws(()=>spellCastRequest({...base,...fields}));
});
test('native target preparation selects self, retains a ground/object target and rejects stale selections without local cast resolution',async()=>{
 const world=new NetworkWorld(),id=0xffffffff,areaId=0x80000001,actor={id,objectType:5,areaId,replicated:{position:[1,2,3]}};world.localObjectId=id;world.areaId=areaId;world.registry.addObjectAtPos(id,actor);let generation=1;const sent=[],states=[],spells=parse2da('2DA V2.0\n\nName TargetType Master SubRadSpell1\n0 1 1 0 ****\n1 2 4 1 ****\n2 3 2 2 ****\n3 4 9 3 ****\n4 5 1 4 5\n5 6 16 5 ****\n'),targeting=new NetworkSpellTargeting({world:()=>world,tables:()=>({spells}),context:()=>({generation}),submit:async r=>{sent.push(r);return{sent:true};},onChange:s=>states.push(s)}),binding=n=>({intParam:n,classIndex:0,domainLevel:0,metamagic:0});
 const before=structuredClone([...world.registry.objects]);await targeting.begin(binding(0));assert.equal(targeting.active,false);assert.equal(sent[0].targetId,id);assert.deepEqual(sent[0].position,[1,2,3]);
 await targeting.begin(binding(1));await assert.rejects(targeting.select(actor,[1,2,3]),/not valid/);assert.equal(targeting.active,true);await targeting.select(null,[4,5,6]);assert.equal(sent.at(-1).targetId,0x7f000000);assert.deepEqual(sent.at(-1).position,[4,5,6]);
 await targeting.begin(binding(2));await targeting.select({id:0x80000002,objectType:5},[7,8,9]);assert.equal(sent.at(-1).targetId,0x80000002);
 await targeting.begin(binding(4));assert.equal(targeting.pending.definition.targetType,16);assert.equal(targeting.pending.request.spellId,4);await targeting.select({id:0x80000003,objectType:10},[8,9,10]);assert.equal(sent.at(-1).spellId,4);
 await targeting.begin(binding(1));generation++;await assert.rejects(targeting.select(null,[0,0,0]),/old area/);assert.equal(targeting.active,false);assert.equal(states.at(-1),null);assert.equal(sent.length,4);assert.deepEqual([...world.registry.objects],before);
});
test('final vanilla caster consumes only server slots, cancels targeting, disables spent input and plays/cleans native cast visuals',()=>{
 const r=JSON.parse(fs.readFileSync(new URL('../backups/animations/local-network-renderer-v50.json',import.meta.url))),d=JSON.parse(fs.readFileSync(new URL('../backups/animations/local-network-renderer-v50-diagnostics.json',import.meta.url)));assert.equal(r.failure,undefined);assert.equal(r.sampleFailure,undefined);assert.equal(r.quickbarActions.length,12);assert.ok(r.paintFrames>1000);assert.equal(r.renderer.state.phase,'playing');assert.equal(r.states.at(-1).closed,true);assert.deepEqual(d.filter(e=>e.severity==='error'),[]);
 const chosen=r.samples.at(-1).quickbar.buttons[10],counts=[];assert.equal(chosen.type,2);for(const s of r.samples){const book=s.server.spellbooks?.[chosen.classIndex];if(!book)continue;const n=Object.values(book.memorized).flat().filter(v=>v?.spell===chosen.intParam&&v.ready).length;if(counts.at(-1)!==n)counts.push(n);}assert.deepEqual(counts,[2,1,0]);
 const packets=r.quickbarRequests.filter(e=>e.packet.startsWith('700612'));assert.equal(packets.length,2);assert.ok(packets[0].at>r.quickbarActions.find(e=>e.step.key==='Escape').at);assert.ok(packets.at(-1).at<r.quickbarActions.find(e=>e.step.afterMs===26000).at);assert.deepEqual(r.quickbarActions.filter(e=>e.step.mode==='targetState').map(e=>e.result.target),[null,null]);
 const clips=new Set(r.samples.flatMap(s=>s.scene?.objects.filter(o=>o.id===r.renderer.world.localObjectId).map(o=>o.clip)??[]));for(const name of ['conjure2','castup','castuplp','pause1'])assert.ok(clips.has(name));
 const visual=r.samples.at(-1).projectiles.casts;for(const kind of ['create','loaded','destroy'])assert.equal(visual.events.filter(e=>e.kind===kind).length,2);assert.equal(visual.events.filter(e=>e.kind==='play'&&e.played).length,2);assert.deepEqual(visual.active,[]);assert.deepEqual(visual.controllers,[]);assert.equal(d.some(e=>/cast-model-failed|cast-controller-failed|cast-animation-unhandled/.test(e.code)),false);
});
