import fs from 'node:fs';
import assert from 'node:assert/strict';
import test from 'node:test';
import {itemIconPlan,selectItemIcon} from '../src/item_icon.js';
import {inventoryEquipmentLayout,inventorySummary} from '../src/inventory_layout.js';
const original=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-item-icons-v1.json',import.meta.url)));
test('item icon recipes match original flat, layered, composite and armor construction',()=>{
 for(const c of original.cases){
  const base=c.type===3?16:1,row={ModelType:String(c.type),ItemClass:'WSwDg',DefaultIcon:'iit_bag',GenderSpecific:'1',InvSlotWidth:'1',InvSlotHeight:'4'},robe={HIDEPELVIS:String(c.hidden),HIDECHEST:String(c.hidden),HIDEBELT:String(c.hidden),HIDESHOR:String(c.hidden),HIDESHOL:String(c.hidden)},tables={baseitems:{rows:new Map([[base,row]])},capart:{rows:new Map([[6,{MDLNAME:'PELVIS'}],[7,{MDLNAME:'CHEST'}],[8,{MDLNAME:'BELT'}],[14,{MDLNAME:'SHOR'}],[15,{MDLNAME:'SHOL'}],[18,{MDLNAME:'ROBE'}]])},parts_robe:{rows:new Map([[c.robe,robe]])}},item={baseItem:base,parts:c.parts,colors:c.colors,partColors:c.overrides};
  tables.baseitems.columns=Object.keys(row);tables.baseitems.orderedRows=Array(base+1);tables.baseitems.orderedRows[base]=row;
  const before=JSON.stringify(item),plan=itemIconPlan(item,tables,{gender:c.gender===70?1:0});assert.equal(plan.kind,c.kind);assert.deepEqual(plan.layers.map(l=>l?.primary??''),c.names.map(n=>n.toLowerCase()),JSON.stringify({type:c.type,gender:c.gender,robe:c.robe,hidden:c.hidden}));
  if(c.kind==='armor')assert.deepEqual(plan.palettes,c.palettes.map(row=>row.map(v=>v&255)));if(c.palette)assert.deepEqual(plan.layers[0].palette,c.palette.map(v=>v&255));assert.equal(JSON.stringify(item),before);
 }
});
test('icon fallback probes are typed and missing armor layers choose native compact model',async()=>{
 const calls=[],plan={kind:'composite',width:1,height:4,layers:[{primary:'custom',fallback:'default',type:3}]};assert.equal((await selectItemIcon(plan,async(n,t)=>{calls.push([n,t]);return n==='default';})).layers[0].name,'default');assert.deepEqual(calls,[['custom',3],['default',3]]);
 const armor=await selectItemIcon({kind:'armor',layers:[{primary:'a',type:6},null,{primary:'b',type:6}],palettes:[[1],[2],[3]],fallback:'ipm_chest001'},async name=>name==='b');assert.equal(armor.model,'gui_icon_armr1l');assert.deepEqual(armor.layers[0].palette,[1]);
});
test('normal inventory excludes all four creature flags until explicitly enabled',()=>{
 const normal=inventoryEquipmentLayout();assert.equal(normal.length,14);assert.ok(normal.every(s=>s.slot<16384));assert.equal(new Set(normal.map(s=>s.slot)).size,14);assert.equal(inventoryEquipmentLayout(true).length,18);
 assert.deepEqual(inventorySummary({playerState:{combat:{field898:1529,field978:95}},inventoryStats:{field70:14}},{encumbrance:{rows:new Map([[14,{Normal:'1750'}]])}}),{gold:1529,weight:10,capacity:175});
});
