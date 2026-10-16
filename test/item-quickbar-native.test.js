import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {clientRelativeWeaponSize,clientItemWield,configureItemQuickbar,updateItemQuickbarCount} from '../src/item_quickbar.js';
import {GameUi} from '../src/game_ui.js';
import {initializeQuickbar,setQuickbarButton,getQuickbarButton} from '../src/quickbar.js';
const observations=()=>JSON.parse(fs.readFileSync(new URL('../backups/animations/native-item-quickbar-observations.json',import.meta.url)));
function fixture(c){
 const calls=[],actor={id:10},other={id:11},defaults={baseItem:50,identified:1,canUse:1,container:0,equipableSlots:0,qbBehaviour:1,stacking:1,weaponType:0,weaponWield:0,weaponSize:3,stackSize:3,owner:0x7f000000,properties:[{type:15,costValue:2}]},
 records=[{...defaults,...c.item},{...defaults,baseItem:51,equipableSlots:16,qbBehaviour:0,weaponType:1,stackSize:1,properties:[],...c.old}],items=records.map((d,i)=>({...d,id:20+i,activeProperties:d.properties})),button={type:0,itemId:21,secondaryItemId:0x7f000000,intParam:0xff00ff,...c.button};let hasIcon=Boolean(c.oldIcon);
 const p={controlled:()=>c.missingActor?null:actor,controlledId:()=>10,item:id=>c.missingItems?.includes(id)?null:items.find(i=>i.id===id)??null,
  baseInfo:i=>records.find(d=>d.baseItem===i.baseItem)?.missingBase?null:records.find(d=>d.baseItem===i.baseItem),canUse:i=>i.canUse,
  sizeCategory:()=>({status:c.sizeStatus??1,value:c.size??3}),property:(i,n)=>i.activeProperties[n]??null,
  propertySpell:(i,n)=>i.activeProperties[n]?.type===15?100+n:-1,
  spell:id=>id>=100&&id<116&&!c.missingSpells?.includes(id)?{id,icon:`icon${id}`,children:id===100?Array.from({length:c.variants??0},(_,i)=>110+i):[]}:null,
  subRadialSpell:(spell,i)=>spell.children[i]??-1,itemIcon:i=>`item${i.id}`,
  cachedUses:(_i,n)=>(c.cachedUses??33)+n,
  equippedOwner:i=>i.owner===10?actor:i.owner===11?other:null,
  clear:b=>{calls.push(['clear']);hasIcon=false;Object.assign(b,{type:0,itemId:0x7f000000,intParam:0});},
  destroyIcon:()=>{if(hasIcon)calls.push(['destroyIcon']);hasIcon=false;},
  icons:(_b,a,b)=>{calls.push(['icons',a,b??'null']);hasIcon=true;},
  createSpellIcon:spell=>{calls.push(['createSpellIcon',spell.icon]);return spell.icon;},releaseSpellIcon:icon=>calls.push(['releaseSpellIcon',icon]),
  feedback:code=>calls.push(['feedback',code]),animation:(_b,animation)=>calls.push(['animation',animation]),notify:()=>calls.push(['notify']),
  text:(_b,text)=>calls.push(['text',text]),enable:(_b,enable)=>calls.push(['enable',enable])};
 p.wield=(...args)=>clientItemWield(...args,p);p.refreshCount=b=>{calls.push(['refreshCount']);updateItemQuickbarCount(b,p);};return{p,actor,items,button,calls};
}
test('original whole-item quickbar configuration: guards, active metadata defaults, variants, icons, equipment pairs and highlight',()=>{
 for(const row of observations().config){const c=row.case,f=fixture(c);configureItemQuickbar(f.button,c.id??20,c.packed??0xff00ff,c.force??0,f.p);assert.deepEqual({button:f.button,calls:f.calls},{button:row.button,calls:row.calls},JSON.stringify(c));}
});
test('original item quickbar count: stack INT/WORD distinction, charges, unlimited and omitted callbacks',()=>{
 for(const row of observations().count){const c=row.case,f=fixture(c);f.button.itemId=20;f.button.intParam=c.packed??0;updateItemQuickbarCount(f.button,f.p);assert.deepEqual(f.calls,row.calls,JSON.stringify(c));}
});
test('original client wield classification preserves BYTE result, appearance status, shield and weapon policy',()=>{
 for(const row of observations().wield){const f=fixture(row.case);assert.equal(clientItemWield(f.actor,f.items[0],f.p),row.result,JSON.stringify(row.case));}
});
test('original client relative weapon size is unclamped and ignores table status',()=>{
 for(const row of observations().size){const f=fixture(row.case);assert.equal(clientRelativeWeaponSize(f.actor,f.items[0],f.p)>>>0,row.result,JSON.stringify(row.case));}
});

function uiFixture(c={}){
 const f=fixture(c),actor=f.actor;for(const item of f.items)item.objectType=6;actor.areaId=100;initializeQuickbar(actor);
 const session={player:actor,registry:new Map(f.items.map(i=>[i.id,i])),items:{baseInfo:f.p.baseInfo,castProviders:()=>({canUse:async()=>1}),quickbarProviders:(_presentation,{canUse}={})=>({...f.p,canUse:()=>canUse})}},
  ui=Object.assign(Object.create(GameUi.prototype),{session,getSession:()=>ui.session,itemQuickbarPresentation:new Map(),notify:()=>{},updateQuickbar:()=>{},saveQuickbarLayout:()=>{},quickbarDescription:()=>({label:'item'})});
 return{...f,session,ui,actor};
}
test('asynchronous item eligibility preserves a rejected destination and serializes later assignments',async()=>{
 const f=uiFixture();setQuickbarButton(f.actor,0,{type:2,intParam:77});
 let release,entered;const started=new Promise(r=>{entered=r;});f.session.items.castProviders=()=>({canUse:()=>{entered();return new Promise(r=>{release=r;});}});
 const item=f.ui.assignQuickbar(0,{type:1,itemId:20}),clear=f.ui.assignQuickbar(1,{type:4,intParam:123});await started;
 assert.equal(getQuickbarButton(f.actor,0).type,2);assert.equal(getQuickbarButton(f.actor,1).type,0);release(0);
 assert.equal(await item,false);assert.equal(getQuickbarButton(f.actor,0).intParam,77);assert.equal(await clear,true);assert.equal(getQuickbarButton(f.actor,1).intParam,123);
});
test('pending eligibility cannot assign after character/area/session changes or canonical item removal',async()=>{
 for(const mutate of [f=>{f.actor.areaId++;},f=>{f.session.player={id:11};},f=>{f.ui.session={};},f=>{f.session.registry.delete(20);}]){
  const f=uiFixture();let release,entered;const started=new Promise(r=>{entered=r;});f.session.items.castProviders=()=>({canUse:()=>{entered();return new Promise(r=>{release=r;});}});
  const assigning=f.ui.assignQuickbar(0,{type:1,itemId:20});await started;mutate(f);release(1);assert.equal(await assigning,false);assert.equal(getQuickbarButton(f.actor,0).type,0);
 }
});
test('restored item wrapper rebuilds default spell selection and paired canonical IDs with force1',()=>{
 const f=uiFixture();f.ui.itemQuickbarPresentation.set(getQuickbarButton(f.actor,0),{unavailable:true});assert.equal(f.ui.configureItemShortcut(0,{type:1,itemId:20,intParam:0xff00ff},1),true);assert.equal(getQuickbarButton(f.actor,0).intParam,0xff0000);assert.equal(f.ui.itemQuickbarPresentation.get(getQuickbarButton(f.actor,0)).unavailable,undefined);
 const pair=uiFixture({item:{equipableSlots:32,weaponType:1,weaponWield:0,properties:[],qbBehaviour:0}}),binding={type:1,itemId:21,secondaryItemId:20,intParam:0xff00ff};
 assert.equal(pair.ui.configureItemShortcut(0,binding,1),true);const restored=getQuickbarButton(pair.actor,0);assert.deepEqual([restored.itemId,restored.secondaryItemId,restored.intParam],[21,20,0xff00ff]);
});
