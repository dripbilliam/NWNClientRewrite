import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {scriptAppearanceType,scriptCreatureSize,scriptCreatureTail,importCreatureTail,scriptSubrace} from '../src/creature_appearance_state.js';
import {setActionMode} from '../src/combat_mode.js';
import {ModuleSession} from '../src/module_session.js';
import {OBJECT_INVALID} from '../src/game_object_array.js';
import {scriptSetDroppable,scriptGetDroppable} from '../src/item_droppable.js';
import {canonicalItemData} from '../src/native_item_runtime.js';
const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-spell-appearance-query-observations.json',import.meta.url)));
assert.equal(oracle.binarySha256,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');

test('decoded appearance/size/tail reads match full original VM wrappers with their distinct widths and absent-object defaults',()=>{
 assert.equal(oracle.queries.length,132);
 for(const row of oracle.queries){const c=row.case;if(c.pop===0||c.push===0)continue;
  const object=c.type===null?null:{objectType:c.type,creatureData:{Appearance_Type:c.value},authored:{Appearance:c.value},nativeSize718:c.value,stats:c.stats?{nativeTailE18:c.value}:null};
  const value=({appearance:scriptAppearanceType,size:scriptCreatureSize,tail:scriptCreatureTail})[c.command](object);
  assert.equal(value>>>0,row.pushed,JSON.stringify(c));assert.equal(row.result,0);
 }
});

test('SetActionMode matches complete SetMode owner across BYTE wrapping, raw integer requests and detect implicit mode',async()=>{
 assert.equal(oracle.modes.length,3420);
 for(const row of oracle.modes){const c=row.case,calls=[];await setActionMode({combatMode:c.mode,nativeField6ed:c.stealth},c.requested,c.value,{detect:()=>{calls.push(['detect']);return c.detect;},toggle:(_actor,mode)=>calls.push(['toggle',mode])});assert.deepEqual(calls,row.calls,JSON.stringify(c));}
});

test('decoded tail import matches original verified ReadStats block: DWORD new, BYTE legacy, then current constructor/runtime state',()=>{
 assert.equal(oracle.imports.length,36);
 for(const row of oracle.imports){const c=row.case,root={};if(c.new!==null)root.Tail_New=c.new;if(c.old!==null)root.Tail=c.old;assert.equal(importCreatureTail(root,c.current),row.result,JSON.stringify(c));}
 assert.equal(importCreatureTail({}),0);assert.throws(()=>importCreatureTail({Tail_New:'bad'}),/unavailable/);
});

test('session script bindings read live creature state and preserve canonical identity; tail uses runtime stats rather than a stale GFF field',async()=>{
 const s=new ModuleSession(null),o=s.register('creature','c',{authored:{Appearance_Type:123},creatureData:{Appearance_Type:65537},stats:{nativeTailE18:9}}),door=s.register('door','d',{authored:{Appearance:65538}}),placeable=s.register('placeable','p',{authored:{Appearance:0x80000001}}),item=s.register('item','i',{});
 assert.equal(s.commands.GetAppearanceType([o.id]),1);o.creatureData.Appearance_Type=45;assert.equal(s.commands.GetAppearanceType([o.id]),45);
 assert.equal(s.commands.GetAppearanceType([door.id]),65538);assert.equal(s.commands.GetAppearanceType([placeable.id]),1);
 assert.equal(s.commands.GetCreatureTailType([o.id]),9);o.creatureData.Tail_New=88;o.stats.nativeTailE18=257;assert.equal(s.commands.GetCreatureTailType([o.id]),257);
 o.nativeSize718=-3;assert.equal(s.commands.GetCreatureSize([o.id]),-3);
 for(const id of [OBJECT_INVALID,item.id]){assert.equal(s.commands.GetAppearanceType([id]),-1);assert.equal(s.commands.GetCreatureSize([id]),0);assert.equal(s.commands.GetCreatureTailType([id]),0);await s.commands.SetActionMode([id,9,1]);}
 const calls=[];s.combat.toggleMode=(actor,mode)=>calls.push([actor,mode]);o.combatMode=0;await s.commands.SetActionMode([o.id,9,0]);assert.deepEqual(calls,[]);await s.commands.SetActionMode([o.id,265,1]);assert.deepEqual(calls,[[o,9]]);assert.equal(s.registry.get(o.id),o);
});

test('script defensive casting uses the same real toggle/activity owner as radial input and never toggles an already requested state',async()=>{
 const s=new ModuleSession(null),area=s.register('area','area',{resRef:'test'}),actor=s.register('player','player',{areaId:area.id,authored:{},stats:{currentHP:10}}),associate=s.register('creature','a',{areaId:area.id,authored:{},stats:{}});
 s.player=actor;actor.combatRound={started:false};actor.associateIds=[associate.id];s.equippedItems=()=>[];const events=[];s.combat.enqueueEvent=(...args)=>events.push(args);
 await s.commands.SetActionMode([actor.id,10,1]);assert.equal(actor.combatMode,9);assert.equal(actor.nativeField6ee,1);assert.equal(actor.activities&0x40000,0x40000);assert.equal(await s.commands.GetActionMode([actor.id,10]),1);
 assert.deepEqual(events,[[10,actor.id,associate.id,0,{type:11,integers:[20010],objectIds:[]}]]);
 await s.commands.SetActionMode([actor.id,10,1]);assert.equal(events.length,1);assert.equal(actor.combatMode,9);
 await s.commands.SetActionMode([actor.id,10,2]);assert.equal(events.length,2);assert.equal(actor.combatMode,0);assert.equal(actor.nativeField6ee,0);assert.equal(actor.activities&0x40000,0);
 await s.commands.SetActionMode([actor.id,10,0]);assert.equal(events.length,2);
});

test('droppable raw INT cell matches full original set/get wrappers and remains shared with canonical inventory data',()=>{
 assert.equal(oracle.droppable.length,100);
 for(const row of oracle.droppable){const c=row.case,item=c.type===null?null:{objectType:c.type,droppable:c.previous};scriptSetDroppable(item,c.requested);assert.equal(item?.droppable??c.previous,row.after,JSON.stringify(c));assert.equal(scriptGetDroppable(item)>>>0,row.pushed,JSON.stringify(c));assert.equal(row.result,0);}
 const s=new ModuleSession(null),o=s.register('item','item',{authored:{Dropable:1}});o.nativeItemLoaded=true;
 for(const value of [0,1,2,-1]){s.commands.SetDroppableFlag([o.id,value]);assert.equal(s.commands.GetDroppableFlag([o.id]),value);assert.equal(canonicalItemData(o).Dropable,value);assert.equal(o.authored.Dropable,1);}
 assert.equal(s.commands.GetDroppableFlag([OBJECT_INVALID]),0);s.commands.SetDroppableFlag([OBJECT_INVALID,1]);assert.equal(s.registry.get(o.id),o);
});

test('subrace decoded delivery matches the complete original wrapper with captured CExoString copying, including embedded NUL text',()=>{
 assert.equal(oracle.subraces.length,40);
 for(const row of oracle.subraces){const c=row.case,o=c.type===null?null:{objectType:c.type,stats:c.stats?{}:null,creatureData:{Subrace:c.text}};assert.equal(scriptSubrace(o),row.pushed,JSON.stringify(c));assert.equal(row.result,0);}
 const s=new ModuleSession(null),o=s.register('creature','c',{stats:{},authored:{Subrace:'old'},creatureData:{Subrace:'new'}});assert.equal(s.commands.GetSubRace([o.id]),'new');o.creatureData.Subrace='changed';assert.equal(s.commands.GetSubRace([o.id]),'changed');assert.equal(s.commands.GetSubRace([OBJECT_INVALID]),'');
 o.creatureData.Subrace={entries:[]};assert.throws(()=>s.commands.GetSubRace([o.id]),/legacy localized subrace/);
});

test('EffectPetrify dedicated original constructor creates the shared type8 state15 with native subtype/INT defaults',()=>{
 const constructors=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-control-constructor-observations-v4.json',import.meta.url))),expected=constructors.rows.find(r=>r.ordinal===583).output;
 assert.equal(constructors.binarySha256,oracle.binarySha256);const s=new ModuleSession(null),effect=s.commands.EffectPetrify([],{self:99});
 assert.deepEqual({type:effect.type,subtype:effect.subtype,integers:effect.integers,creatorId:effect.creatorId},expected);
 const types=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-effect-script-type-observations-v3.json',import.meta.url)));
 assert.equal(s.commands.GetEffectType([effect]),types.rows.find(r=>r.type===8&&r.integer0===15&&r.all===0).value);
});
