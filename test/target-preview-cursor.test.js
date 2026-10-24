import test from 'node:test';import assert from 'node:assert/strict';import fs from 'node:fs';
import {parse2da} from '../src/area.js';import {castingSpell} from '../src/spell_metadata.js';import {spellTargetPreview,targetPreviewColor} from '../src/target_preview.js';import {nativeCursorResource,worldCursorId} from '../src/game_cursor.js';import {NetworkWorld} from '../src/network_world.js';import {NetworkSpellTargeting} from '../src/network_spell_targeting.js';import {NativeMessageWriter} from '../src/native_message.js';import {decodeServerGameMessage} from '../src/network_game_messages.js';

test('active spell dimensions retain fractional radii and map native shapes/range data without spell-ID rules',()=>{
 const spells=parse2da('2DA V2.0\n\nTargetType Range TargetShape TargetSizeX TargetSizeY TargetFlags\n0 6 L sphere 6.67 **** 3\n1 6 M rectangle 30 3 19\n2 6 S cone 11 **** 19\n3 6 T hsphere 2 8 4\n'),ranges=parse2da('2DA V2.0\n\nPrimaryRange\n0 0\n1 2.25\n2 8\n3 20\n4 40');
 for(const[id,shape,range]of [[0,1,40],[1,2,20],[2,3,8],[3,4,2.25]]){const spell=castingSpell({spells},id),preview=spellTargetPreview(spell,ranges);assert.equal(preview.shape,shape);assert.equal(preview.range,range);}
 assert.equal(castingSpell({spells},0).targetSizeX,Math.fround(6.67));const spell=castingSpell({spells},0),before=structuredClone(spell);assert.deepEqual(spellTargetPreview(spell,ranges,{shape:4,sizeX:1,sizeY:10,flags:5}),{shape:4,sizeX:1,sizeY:10,flags:5,range:40,spellId:0,featId:-1});assert.deepEqual(spell,before);
 assert.deepEqual(targetPreviewColor(3),[1,0,0,1]);assert.deepEqual(targetPreviewColor(1),[0,0,1,1]);assert.deepEqual(targetPreviewColor(4),[0,1,0,1]);assert.deepEqual(targetPreviewColor(0),[1,1,1,1]);
});

test('native mouse cursor IDs select installed up/down, arrow, pickup and custom resources',()=>{
 const metadata=JSON.parse(fs.readFileSync(new URL('../backups/animations/target-preview-cursor-resources-v1.json',import.meta.url)));const constants=new Map(metadata.constants.map(r=>[r.name,Number(r.value.trim())]));
 for(const[name,resource]of [['MAGIC','gui_mp_magicu'],['NOMAGIC','gui_mp_nomagicu'],['DOOR','gui_mp_dooru'],['PICKUP','gui_mp_pickupu'],['TALK','gui_mp_talku']]){const id=constants.get('MOUSECURSOR_'+name);assert.ok(Number.isInteger(id),name);assert.equal(nativeCursorResource(id),resource);assert.equal(nativeCursorResource(id+1),resource.slice(0,-1)+'d');}
 assert.equal(nativeCursorResource(59),'gui_mp_arrun00');assert.equal(nativeCursorResource(90),'gui_mp_arwalk15');assert.equal(nativeCursorResource(291),'gui_mp_custom99u');assert.equal(nativeCursorResource(292),'gui_mp_custom99d');assert.equal(nativeCursorResource(0),null);
});

test('hover cursors distinguish closed/open transition doors, use, pickup, reaction and valid/invalid targeting',()=>{
 const door={objectType:10,replicated:{animation:22,hasTransition:true}};assert.equal(worldCursorId(door),23);door.replicated.animation=50;assert.equal(worldCursorId(door),21);
 for(const[target,id]of [[{objectType:9,replicated:{field264:true}},25],[{objectType:9,staticState:{}},1],[{objectType:6},91],[{objectType:5,replicated:{reaction:2}},7],[{objectType:5,replicated:{reaction:1}},11]])assert.equal(worldCursorId(target),id);
 assert.equal(worldCursorId(null,{walkable:true}),3);assert.equal(worldCursorId(door,{targeting:{cursor:29},pressed:true}),30);assert.equal(worldCursorId(door,{targeting:{cursor:31}}),31);assert.equal(worldCursorId({objectType:9,replicated:{light:{field260:291}}}),291);assert.equal(worldCursorId({objectType:9,nativeMiscVisualFields:{[0x260]:17}}),17);
});

test('server per-spell overrides and script target data stay connection-owned; bad-target cursor is a cursor, not preview flags',()=>{
 const a=new NetworkWorld(),b=new NetworkWorld(),w=new NativeMessageWriter(1);w.create(32,0xffffffff,1);w.writeInt(58);w.writeInt(4);w.writeFloat(2.5,1,32);w.writeFloat(8,1,32);w.writeInt(19);w.setPrefix(Uint8Array.of(80,57,1));const packet=w.getWriteMessage().data,m=decodeServerGameMessage(packet);assert.deepEqual(m,{kind:'spell-targeting-data',spellId:58,shape:4,sizeX:2.5,sizeY:8,flags:19,major:57,minor:1});assert.throws(()=>decodeServerGameMessage(packet.subarray(0,packet.length-2)));a.apply(m);assert.equal(a.spellTargetingOverrides.get(58).shape,4);assert.equal(b.spellTargetingOverrides.size,0);a.reset();assert.equal(a.spellTargetingOverrides.size,0);
 const actor={id:7,objectType:5,replicated:{position:[0,0,0]}},world={localObjectId:7,registry:new Map([[7,actor]]),scriptTargeting:{version:1,objectMask:1,cursor:29,badCursor:31},scriptTargetingData:{shape:1,sizeX:6.67,range:40,flags:3}},targeter=new NetworkSpellTargeting({world:()=>world,tables:()=>({}),context:()=>({}),submit:async()=>{throw Error('Presentation must not submit');}});targeter.beginServer();assert.equal(targeter.presentation(actor).cursor,29);assert.equal(targeter.presentation(null).cursor,31);assert.equal(targeter.presentation(actor).preview,world.scriptTargetingData);
});
