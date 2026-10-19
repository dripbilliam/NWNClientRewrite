import test from 'node:test';
import assert from 'node:assert/strict';
import {ModuleSession} from '../src/module_session.js';
import {parse2da} from '../src/area.js';
import {parseGff} from '../src/gff.js';
import {writeGff,gffField as F,gffRecord as R} from '../src/gff_writer.js';
import {OBJECT_INVALID} from '../src/game_object_array.js';
import {runtimeDiagnostics} from '../src/runtime_diagnostics.js';
function fixture(){
 const resources=new Map(),s=new ModuleSession({getResource:async(name,type)=>{const bytes=resources.get(`${name}:${type}`);if(!bytes)throw Object.assign(new Error(`Missing ${name}`),{code:'RESOURCE_NOT_FOUND'});return bytes;}});
 s.characterRules={baseitems:parse2da('2DA V2.0\n\nModelType PropColumn InvSlotWidth InvSlotHeight Stacking Container TenthLBS Category BaseCost ItemMultiplier StorePanel StorePanelSort ILRStackSize\n0 0 1 1 1 1 0 10 0 10 1 0 1 1\n1 0 1 1 1 1 0 10 0 20 1 2 0 1\n2 0 1 1 1 1 0 10 0 5 1 0 1 1\n3 0 1 1 1 1 0 10 0 2 1 8 0 1')};
 s.module=s.register('module','module',{});const object=s.register('store','store',{tag:'',authored:{},deferTagLookup:true});return{s,object,resources};
}
test('full UTM runtime owns five repositories, typed fields, scripts, pricing, locals, UUID and recursive destruction',async()=>{
 const {s,object:o,resources}=fixture(),begin=runtimeDiagnostics.records.length,uuid='01234567-89ab-cdef-0123-456789abcdef',row=(base,tag)=>R({BaseItem:F(5,base),Tag:F(10,tag),Cost:F(4,9999),AddCost:F(4,2),Infinite:F(0,2)});
 resources.set('utm:2051',writeGff('UTM ',R({Tag:F(10,'bad tag!'),ResRef:F(11,'authored'),LocName:F(12,{strRef:0xffffffff,entries:[{languageId:0,text:'Store'}]}),BlackMarket:F(0,2),BM_MarkDown:F(5,-3),StoreGold:F(5,77),IdentifyPrice:F(4,500),OnOpenStore:F(11,'open_script'),OnStoreClosed:F(11,'close_script'),
  WillNotBuy:F(15,[R({BaseItem:F(5,2)})]),WillOnlyBuy:F(15,[R({BaseItem:F(5,0)})]),StoreList:F(15,[R({ItemList:F(15,[row(0,'Expensive'),row(1,'OtherPanel'),row(2,'Cheap'),row(3,'InvalidPanel')])})]),UUID:F(10,uuid),VarTable:F(15,[R({Name:F(10,'Loaded'),Type:F(4,1),Value:F(5,9)})])})));
 assert.equal(await s.worldTemplates.load('store',o,'utm','override tag!'),1);assert.equal(o.templateResRef,'utm');assert.equal(o.tag,'overridetag');assert.equal(o.name,'Store');assert.equal(o.areaId,OBJECT_INVALID);assert.equal(o.locals.getInt('Loaded'),9);assert.equal(s.uuids.lookup(uuid),o.id);assert.equal(s.byTag(o.tag)[0],o);
 assert.equal(o.nativeStoreFields[0x378],1);assert.equal(o.nativeStoreFields[0x37c],-3);assert.equal(o.nativeStoreFields[0x38c],77);assert.equal(o.nativeStoreFields[0x390],100);
 assert.deepEqual(o.nativeStoreBuyArrays[0x398],{values:[2],capacity:16});assert.deepEqual(o.nativeStoreBuyArrays[0x3a8],{values:[],capacity:0});assert.equal(o.scripts.openStore,'open_script');o.scripts.openStore='changed';assert.equal(o.nativeStoreStrings[0x308],'changed');
 const names=repo=>[...repo.ids()].map(id=>s.registry.get(id).tag);assert.deepEqual(o.nativeStoreRepositories.map(names),[['Expensive','Cheap'],[],['OtherPanel'],[],['InvalidPanel']]);
 const children=o.inventory;assert.equal(children.length,4);for(const id of children){const item=s.registry.get(id);assert.equal(item.possessorId,o.id);assert.equal(item.identified,1);assert.equal(item.nativeInfinite444,1);assert.equal(item.nativePriceDirty398,0);assert.equal(item.nativeUnidentifiedPrice390,s.items.baseInfo(item).baseCost);assert.equal(await s.items.price(item),s.items.baseInfo(item).baseCost+2);}
 assert.equal(runtimeDiagnostics.records.slice(begin).filter(r=>r.code==='items.store-warning').length,1);assert.deepEqual(runtimeDiagnostics.records.slice(begin).filter(r=>r.severity==='error'),[]);
 const next=s.registry.nextObjectId[0];await s.lifecycle.destroy(o);for(const id of children)assert.equal(s.registry.get(id),undefined);assert.equal(s.registry.get(o.id),undefined);assert.equal(s.uuids.lookup(uuid),OBJECT_INVALID);assert.equal(s.registry.nextObjectId[0],next);assert.equal(o.nativeStoreName360,null);assert.equal(o.nativeStoreBuyArrays[0x398],null);assert.equal(o.scripts.openStore,'');
});
test('store saved-ID guard skips any existing canonical object and preserves the original final-allocation possession condition',async()=>{
 const {s,object:o}=fixture(),data=parseGff(writeGff('UTM ',R({StoreList:F(15,[R({ItemList:F(15,[R({BaseItem:F(5,0),ObjectId:F(4,500)}),R({BaseItem:F(5,0),ObjectId:F(4,s.module.id)})])})])}))).root;
 await s.worldTemplates.stores.load(o,data,1);
 assert.equal(s.registry.nextObjectId[0],501);assert.equal(s.registry.get(s.module.id),s.module);assert.deepEqual(o.inventory,[500]);assert.equal(s.registry.get(500).possessorId,OBJECT_INVALID,'Final existing-ID skip clears R15; the original acquires earlier items without SetPossessor');
 await s.lifecycle.destroy(o);assert.equal(s.registry.get(500),undefined);assert.equal(s.registry.nextObjectId[0],501);
});
test('concrete property pricing uses active definition/subtype/cost tables and charge configuration',async()=>{
 const {s}=fixture(),item=s.register('item','price',{authored:{},tag:''});
 s.characterRules.itempropdef=parse2da('2DA V2.0\n\nCost SubTypeResRef CostTableResRef\n0 **** subtype 1\n1 1.5 **** 0');
 s.characterRules.iprp_costtable=parse2da('2DA V2.0\n\nName\n0 ****\n1 cost\n2 unused\n3 uses');s.items.tables.set('subtype',Promise.resolve(parse2da('2DA V2.0\n\nCost\n0 2')));s.items.tables.set('cost',Promise.resolve(parse2da('2DA V2.0\n\nCost\n0 3')));s.items.tables.set('uses',Promise.resolve(parse2da('2DA V2.0\n\nCost\n0 0\n1 0\n2 1')));
 s.characterRules.iprp_spells=parse2da('2DA V2.0\n\nCost\n0 100');s.characterRules.ruleset=parse2da('2DA V2.0\n\nLabel Value\n0 MAX_CHARGES_FOR_ITEM_COST 100');
 item.baseItem=0;item.charges=50;item.passiveProperties=[{type:0,subtype:0,costValue:0,durationType:2}];item.activeProperties=[{type:15,subtype:0,costValue:2,durationType:2}];
 assert.equal(await s.items.price(item),36060);assert.equal(item.nativeBasePrice38c,36060);assert.equal(item.nativeUnidentifiedPrice390,10);assert.equal(item.nativePriceDirty398,0);
 item.nativePriceDirty398=1;s.characterRules.ruleset=parse2da('2DA V2.0\n\nLabel Value\n0 MAX_CHARGES_FOR_ITEM_COST 50');assert.equal(await s.items.price(item),36110);
 item.stackSize=3;item.identified=0;assert.equal(await s.commands.GetGoldPieceValue([item.id]),30);item.identified=1;assert.equal(await s.commands.GetGoldPieceValue([item.id]),108330);
 assert.equal(await s.commands.GetGoldPieceValue([s.module.id]),0);assert.equal(await s.commands.GetGoldPieceValue([OBJECT_INVALID]),0);
 // UMD restrictions request GetCost(0,1,1,1), including ILR factor and plot
 // override, through the same concrete pricing owner instead of a placeholder.
 const info=s.items.baseInfo(item);info.ilrStackSize=7;item.plot=1;
 assert.equal(await s.itemRestrictionProviders().itemCost(item,0,1,1,1),252770);assert.equal(await s.commands.GetGoldPieceValue([item.id]),0);
});
