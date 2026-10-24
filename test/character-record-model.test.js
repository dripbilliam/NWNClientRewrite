import test from 'node:test';
import assert from 'node:assert/strict';
import {networkCharacterRecord,recordAbilities,recordAlignmentRef,recordAttacks,recordDamageBonuses} from '../src/character_record_model.js';
const table=rows=>({rows:new Map(rows.map((r,i)=>[i,r])),orderedRows:rows,defaultValue:'****'});
const rules=()=>({ruleset:table([]),exptable:table([{XP:'0'},{XP:'1000'}]),classes:table([{Name:'100'}]),racialtypes:table([{Name:'101'}]),skills:table([{Name:'102',Description:'16777218',Icon:'custom_skill'},{Name:'104'}]),feat:table([{FEAT:'103',DESCRIPTION:'16777219',ICON:'custom_feat'}]),baseitems:table([])});
test('native record alignment thresholds and six score/modifier cells',()=>{
 assert.deepEqual([recordAlignmentRef(70,70),recordAlignmentRef(69,69),recordAlignmentRef(30,30),recordAlignmentRef(31,30),recordAlignmentRef(undefined,50)],[112,116,120,117,null]);
 const r=rules(),a=recordAbilities([20,14,14,10,10,15],[2,0,0,0,0,-1],r);assert.deepEqual(a.map(e=>e.modifier),[5,2,2,0,0,2]);assert.equal(a[0].modifierAdjustment,1);assert.equal(a[5].modifierAdjustment,-1);
 r.ruleset=table([{Label:'CHARGEN_ABILITY_NEUTRAL_VALUE',Value:'12'},{Label:'CHARGEN_ABILITY_MODIFIER_INCREMENT',Value:'3'}]);assert.equal(recordAbilities([20,12,12,12,12,12],[],r)[0].modifier,2);
});
test('server S fields preserve save order, current/temporary HP, visibility and custom TLK descriptions',async()=>{
 const r=rules(),actor={id:9,replicated:{name:{text:'Remote'},stats:{racialType:0,fieldD28:'Custom race',fieldDE4:80,fieldDE6:10,classes:[{id:0,level:1}]},hitPoints:{current:6,fieldE8:3,maximum:12}},playerState:{abilities:{current:[12,12,12,12,12,12]},combat:{armorClass:17},feats:[0]},inventoryStats:{field94:123,field98:9,field99:24,field9a:11,field9b:20,fields70:[20,14,14,10,10,15],fields7d:[2,0,0,0,0,0],skills:[{index:0,value:20,flag:1},{index:1,value:100,flag:0}]}};
 const refs=[],resolve=async v=>{if(v?.text!==undefined)return v.text;if(!v)return'';refs.push(v.strRef);return 'TLK '+v.strRef;},world={inventories:new Map(),registry:new Map([[9,actor]])};
 const m=await networkCharacterRecord(world,actor,{tables:r,resolve,portrait:async()=>null,identity:'server-a:9'});
 assert.equal(m.race,'Custom race');assert.equal(m.alignment,'TLK 118');assert.equal(m.currentHP,9);assert.equal(m.maximumHP,12);assert.equal(m.experience,123);assert.equal(m.nextExperience,1000);assert.equal(m.armorClass,17);assert.deepEqual(m.details.filter(d=>['TLK 317','TLK 318','TLK 319'].includes(d.label)).map(d=>d.value),[9,11,24]);assert.deepEqual(m.skills.map(e=>e.id),[0]);assert.equal(m.skills[0].value,20);assert.equal(m.skills[0].description,'TLK 16777218');assert.equal(m.feats[0].description,'TLK 16777219');assert.equal(m.feats[0].icon,'custom_feat');assert.equal(m.abilities[0].score,20);
 // Unreceived sheet stats stay unavailable; no local class/feat calculation.
 actor.inventoryStats={};const absent=await networkCharacterRecord(world,actor,{tables:r,resolve,portrait:async()=>null,identity:'server-b:9'});assert.equal(absent.experience,undefined);assert.equal(absent.details.find(d=>d.label==='TLK 317').value,undefined);assert.equal(absent.abilities[0].score,12);
});
test('native display attacks use replicated BAB, monk interval and universal received nodes',()=>{
 const r=rules(),info={field0:2,field1:3,field18:1,field3:-1,group0:[{field0:2,field2:6,field5:28,field3:0,field4:0},{field0:99,field2:6,field5:4,field3:0,field4:0}]};
 assert.equal(recordAttacks(info,12,false,r),'+17/+12');assert.equal(recordAttacks(info,12,true,r),'+17/+14');assert.equal(recordAttacks(info,12,false,r,true,[20]),'+13/+8');assert.equal(recordAttacks(info,-1,false,r),null);
 r.ruleset=table([{Label:'MULTIPLE_ATTACKS_BAB_PENALTY_MULTIPLIER',Value:'4'}]);assert.equal(recordAttacks(info,12,false,r),'+17/+13');
});

test('received damage rows use active text, colors, qualifiers and hand restrictions',async()=>{
 const r={iprp_damagecost:table(Array.from({length:7},()=>({GameString:'601'}))),damagetypes:table([{CharsheetStrref:'602',DamageTypeGroup:'0'}]),damagetypegroups:table([{ColorR:'255',ColorG:'128',ColorB:'0'}]),racialtypes:table([{NamePlural:'603'}])},resolve=async v=>({601:'1d6',602:'Custom damage',603:'Custom creatures',7603:'vs.',268:'Lawful'}[v.strRef]??'Other');
 const base={field0:3,field1:0,field2:1,field3:0,field4:0,field5:28},nodes=[base,{...base,field0:6,field3:2,field5:0},{...base,field2:2}];
 const m=await recordDamageBonuses(nodes,r,resolve,{hasMainWeapon:true});assert.deepEqual(m.map(d=>d.value),['+3 Custom damage','+1d6 Custom damage vs. Lawful Custom creatures']);assert.equal(m[0].parts[1].color,'rgb(255,128,1)');assert.equal((await recordDamageBonuses(nodes,r,resolve,{offhand:true})).length,1);
});
