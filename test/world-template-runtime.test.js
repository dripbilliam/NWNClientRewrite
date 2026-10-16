import test from 'node:test';
import assert from 'node:assert/strict';
import {ModuleSession} from '../src/module_session.js';
import {parseGff} from '../src/gff.js';
import {parse2da} from '../src/area.js';
import {writeGff,gffRecord as R,gffField as F} from '../src/gff_writer.js';
import {OBJECT_INVALID} from '../src/game_object_array.js';
import {runtimeDiagnostics} from '../src/runtime_diagnostics.js';
const data=fields=>parseGff(writeGff('UTP ',R(fields))).root;
function fixture(){
 const resources=new Map(),s=new ModuleSession({getResource:async(name,type)=>{const bytes=resources.get(`${name.toLowerCase()}:${type}`);if(!bytes)throw Object.assign(new Error(`Missing ${name}`),{code:'RESOURCE_NOT_FOUND'});return bytes;}});
 s.characterRules={baseitems:parse2da('2DA V2.0\n\nModelType BasePropColumn InvSlotWidth InvSlotHeight Stacking Container TenthLBS\n0 0 1 1 1 1 0 10'),placeables:parse2da('2DA V2.0\n\nLightColor\n0 7'),traps:parse2da('2DA V2.0\n\nTrapScript\n0 active_trap'),portraits:parse2da('2DA V2.0\n\nBaseResRef\n0 human')};
 for(const name of['placeables','traps','portraits'])s.items.tables.set(name,Promise.resolve(s.characterRules[name]));
 s.module=s.register('module','module',{});
 const construct=(key,requestedId=OBJECT_INVALID)=>s.register('placeable',key,{tag:'',authored:{},deferTagLookup:true},{requestedId});
 return{s,resources,construct};
}
test('full placeable template adapter uses native defaults, fields, scripts, locals and canonical identity',async()=>{
 const {s,resources,construct}=fixture(),o=construct('utp'),id=o.id,next=s.registry.nextObjectId[0];
 assert.deepEqual([o.nativeTrapType3d0,o.nativeTrapRecoverable3c8,o.nativeTrapActive3d4,o.nativeTrapFaction3d8],[255,1,1,0]);
 const fields={Tag:F(10,'bad tag!'),TemplateResRef:F(11,'authored'),Faction:F(4,7),TrapFaction:F(4,9),LootCreature:F(4,123),Useable:F(0,2),Static:F(0,1),HP:F(3,300),CurrentHP:F(3,-2),Fort:F(0,255),Will:F(0,7),TrapType:F(0,0),OnTrapTriggered:F(11,'default'),OnUsed:F(11,'use_me'),LightState:F(0,0),PortraitId:F(2,0),
  LocName:F(12,{strRef:0xffffffff,entries:[{languageId:2,text:'Name'}]}),VarTable:F(15,[R({Name:F(10,'loaded'),Type:F(4,1),Value:F(5,17)})])};
 resources.set('utp:2044',writeGff('UTP ',R(fields)));assert.equal(await s.worldTemplates.load('placeable',o,'utp'),1);
 assert.equal(o.id,id);assert.equal(s.registry.nextObjectId[0],next);assert.equal(o.areaId,OBJECT_INVALID);assert.equal(o.tag,'badtag');assert.equal(o.templateResRef,'authored');assert.equal(s.byTag('badtag')[0],o);
 assert.deepEqual([o.factionId,o.nativeTrapFaction3d8,o.nativeBodyBagSource510],[7,9,123]);assert.deepEqual([o.nativeStaticLoadOverride5a4,o.nativeStatic5a0,o.plot],[1,0,false]);assert.equal(o.usable,true);
 assert.deepEqual([o.authored.HP,o.currentHP,o.authored.Fort,o.authored.Will],[300,-2,255,7]);assert.equal(o.nativeGroundPile368,1);assert.equal(o.name,'Name');assert.equal(o.authored.LocName.entries[0].languageId,2);assert.equal(o.locals.getInt('loaded'),17);
 assert.deepEqual([o.nativePortraitId,o.nativePortraitResRef],[0,'po_human']);assert.deepEqual([o.nativeMessageFields[0x594],o.nativeMessageFields[0x598]],[0,1]);assert.equal(o.scripts.trapTriggered,'active_trap');assert.equal(o.scripts.used,'use_me');
 o.scripts.used='changed';assert.equal(o.nativeBodyBagStrings[0x4a0],'changed');
 // Reload uses typed defaults and direct portrait refs retain the numeric ID.
 fields.PortraitId=F(4,123);fields.Portrait=F(11,'custom');fields.OnTrapTriggered=F(11,'Default');fields.TrapActive=F(4,0);fields.GroundPile=F(0,0);resources.set('utp:2044',writeGff('UTP ',R(fields)));
 assert.equal(await s.worldTemplates.load('placeable',o,'utp','override'),1);assert.equal(o.nativeTrapActive3d4,1);assert.equal(o.nativeGroundPile368,1);assert.equal(o.scripts.trapTriggered,'Default');assert.deepEqual([o.nativePortraitId,o.nativePortraitResRef],[0,'custom']);assert.equal(o.tag,'override');
 await s.lifecycle.destroy(o);assert.equal(s.registry.get(id),undefined);assert.equal(s.registry.nextObjectId[0],next);assert.equal(o.scripts.used,'');assert.equal(o.nativePlaceableLocalized[0x308],null);assert.equal(o.nativePlaceableLocalized[0x330],null);
});
test('placeable item loading preserves existing repository entries, saved IDs and failed-construction cursor effects',async()=>{
 const {s,construct}=fixture(),o=construct('inventory'),begin=runtimeDiagnostics.records.length;
 const row=(id,tag,base=0)=>R({ObjectId:F(4,id),BaseItem:F(5,base),Tag:F(10,tag),Repos_PosX:F(2,256),Repos_Posy:F(2,257)});
 await s.worldTemplates.loadPlaceable(o,data({ItemList:F(15,[row(0x1234,'first'),row(0x1235,'bad',999)])}),1);
 const first=s.registry.get(0x1234);assert.ok(first);assert.equal(first.possessorId,o.id);assert.deepEqual([...o.nativeRepository.ids()],[first.id]);assert.equal(first.repositoryX,0);assert.equal(first.repositoryY,1);assert.equal(s.registry.get(0x1235),undefined);assert.equal(s.registry.nextObjectId[0],0x1236);
 await s.worldTemplates.loadPlaceable(o,data({ItemList:F(15,[row(0x1234,'second')])}),0);
 assert.deepEqual([...o.nativeRepository.ids()],[0x1236,0x1234]);assert.equal(s.registry.get(0x1236).tag,'second');assert.equal(s.registry.get(0x1236).possessorId,o.id);assert.equal(s.registry.nextObjectId[0],0x1237);
 assert.equal(runtimeDiagnostics.records.slice(begin).filter(r=>r.context.operation==='native-placeable-item-load').length,1);
 await s.lifecycle.destroy(o);assert.equal(s.registry.get(0x1234),undefined);assert.equal(s.registry.get(0x1236),undefined);assert.equal(s.registry.nextObjectId[0],0x1237);
});
test('explicit registration honors constructor override and rejects ID collisions without reassignment',()=>{
 const {s,construct}=fixture(),o=construct('explicit',500);assert.equal(o.id,500);assert.equal(o.nativeStaticLoadOverride5a4,0);assert.equal(s.registry.nextObjectId[0],501);
 assert.throws(()=>construct('collision',500),/Cannot allocate placeable/);assert.equal(s.registry.get(500),o);assert.equal(s.registry.nextObjectId[0],501);assert.equal(s.sources.has('collision'),false);
 const external=construct('external',0x80000200);assert.equal(external.id,0x80000200);assert.equal(external.nativeStaticLoadOverride5a4,0);assert.equal(s.registry.nextObjectId[0],501);
});
test('saved container items forward the load flag to child IDs and preserve separate tag sanitation',async()=>{
 const {s,construct}=fixture();s.characterRules.baseitems=parse2da('2DA V2.0\n\nModelType BasePropColumn InvSlotWidth InvSlotHeight Stacking Container TenthLBS\n0 0 1 1 1 1 0 10\n1 0 1 1 1 1 1 10');
 const o=construct('nested'),child=R({ObjectId:F(4,800),BaseItem:F(5,0),Tag:F(10,'Child Tag!')}),container=R({ObjectId:F(4,700),BaseItem:F(5,1),Tag:F(10,'Bag Tag!'),ItemList:F(15,[child])});
 await s.worldTemplates.loadPlaceable(o,data({ItemList:F(15,[container])}),1);
 const bag=s.registry.get(700),item=s.registry.get(800);assert.ok(bag);assert.ok(item);assert.equal(bag.tag,'BagTag');assert.equal(item.tag,'ChildTag');assert.equal(item.possessorId,bag.id);assert.equal(bag.possessorId,o.id);assert.deepEqual([...bag.nativeRepository.ids()],[800]);assert.equal(s.registry.nextObjectId[0],801);
 await s.lifecycle.destroy(o);assert.equal(s.registry.get(700),undefined);assert.equal(s.registry.get(800),undefined);assert.equal(s.registry.nextObjectId[0],801);
});
