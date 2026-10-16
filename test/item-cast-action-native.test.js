import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {executeItemCast} from '../src/item_cast_action.js';
import {createObjectAction,setActionParameter} from '../src/object_actions.js';
import {setItemCharges,itemActiveUsesLeft} from '../src/item_presentation_state.js';
import {parse2da} from '../src/area.js';
import {SpellRuntime} from '../src/spell_runtime.js';
const oracle=()=>JSON.parse(fs.readFileSync(new URL('../backups/animations/native-item-cast-action-observations.json',import.meta.url)));
function fixture(c){
 const calls=[],actor={id:99,areaId:7,nativeField828:c.activated??0,nativeSpellImpact224:c.impactDone??0,nativeSpellSpontaneous228:11,
  nativeSpellId218:12,nativeSpellTarget214:13,nativeSpellTarget818:14,nativeCasterOverride824:15,nativeCasterOverride820:16,
  nativeSpellMetamagic22d:17,nativeSpellFeat23c:18,nativeTarget740:19,nativeSpellPoint208:[0,0,0],combatRound:{started:c.started??0}},
  target={masterId:c.masterId??0x7f000000},item={id:55,baseItem:c.baseItem??49,plot:c.plot??0,charges:c.charges??10,stackSize:c.stackSize??1,nativePriceDirty398:0,
  activeProperties:[{type:c.type??15,costValue:c.cost??1,remaining:c.remaining??1,usesPerDay:c.daily??1,subtype:33},...(c.others??[]).map(p=>({...p,subtype:33}))]},
  node=createObjectAction(46,0);
 const bits=v=>{const d=new DataView(new ArrayBuffer(4));d.setFloat32(0,v,true);return d.getInt32(0,true);};
 const values=[55,c.index??0,c.variant??0,c.targetId??100,...(c.point??[1.25,2.5,3.75]).map(bits),c.startDay??3,c.startTime??1000,c.consume??1];
 values.forEach((v,i)=>setActionParameter(node,i,i>=4&&i<=6?2:1,v));node.nativeField9c=c.releaseFlag??1;
 const p={activityManager:(_o,v)=>calls.push(['activityManager',v]),worldTime:o=>{calls.push(['worldTime',o.id]);return{day:c.nowDay??3,time:c.nowTime??9000};},
  dead:()=>{calls.push(['dead']);return c.dead??0;},dying:()=>{calls.push(['dying']);return c.dying??0;},
  object:id=>{calls.push(['object',id]);return c.targetExists===false?null:target;},asCreature:()=>{calls.push(['asCreature']);return c.targetCreature===false?null:target;},
  item:id=>{calls.push(['item',id]);return c.item===false?null:item;},activeProperty:(_i,index)=>{calls.push(['property',index>>>0]);return c.property===false?null:item.activeProperties[index]??null;},propertyCount:()=>item.activeProperties.length,
  propertyInt:(subtype,col)=>{calls.push(['propertyInt',subtype,col]);return col==='SpellIndex'?c.spellId??101:c.casterLevel??7;},
  spell:id=>{calls.push(['spell',id]);return c.spell===false||id!==((c.spellId??101)>>>0)&&c.childMissing?null:{id,castTime:id===((c.spellId??101)>>>0)?c.castTime??1000:c.childCastTime??2000};},
  subRadialCount:s=>s.id===((c.spellId??101)>>>0)?c.children??0:0,subRadialSpell:(_s,v)=>{calls.push(['subRadialSpell',v]);return c.childId??102;},
  elapsed:(now,then)=>{calls.push(['elapsed',now.day,now.time,then.day,then.time]);return c.elapsed??0;},modelType:()=>{calls.push(['modelType']);return c.model??'P';},
  startRound:(_o,n)=>{calls.push(['startRound',n]);actor.combatRound.started=1;},decrementRound:(_o,...a)=>calls.push(['decrementRound',...a]),pause:(_o,...a)=>calls.push(['pause',...a]),pauseTimer:(_o,...a)=>calls.push(['pauseTimer',...a]),
  playerCharacter:()=>{calls.push(['playerCharacter']);return c.pc??1;},difficulty:n=>{calls.push(['difficulty',n]);return c.difficulty??1;},opportunity:(_o,...a)=>calls.push(['opportunity',...a]),
  usesLeft:(i,n)=>{calls.push(['usesLeft',n]);return itemActiveUsesLeft(i,n);},setCharges:(i,n,v)=>{calls.push(['setCharges',n>>>0,v]);return setItemCharges(i,n,v);},
  projectileTime:(_o,n)=>{calls.push(['projectileTime',n]);actor.nativeSpellProjectileTime220=c.projectileTime??450;},setAnimation:(o,n)=>calls.push(['animation',o===target?'target':'actor',n]),
  impact:(_o,...a)=>{calls.push(['impact',...a]);actor.nativeSpellImpact224=1;},removeSpellActions:()=>calls.push(['removeSpellActions']),removeRoundSpell:()=>calls.push(['removeRoundSpell']),pendingEquipment:()=>calls.push(['pendingEquipment']),
  feedback:(_o,n)=>calls.push(['feedback',n]),enqueue:(...a)=>calls.push(['enqueue',...a]),activeChanged:(_i,n)=>calls.push(['activeChanged',n])};
 return{calls,actor,item,node,p};
}
test('item casting matches original action timing, resources, variants, recipient animation and cleanup',async()=>{
 for(const row of oracle().rows){const {case:c}=row,f=fixture(c),label=JSON.stringify(c);
  const rules=c.rulesOverrides?{ruleset:parse2da(`2DA V2.0\n\nLabel Value\n${Object.entries(c.rulesOverrides).map(([label,value],i)=>`${i} ${label} ${value}`).join('\n')}`)}:{};
  assert.equal(await executeItemCast(f.actor,f.node,rules,f.p),row.result,label);
  assert.deepEqual(f.calls,row.calls,label);
  assert.deepEqual(f.item.activeProperties.map(({type,costValue,remaining,usesPerDay})=>({type,costValue,remaining,usesPerDay})),row.properties,label);
  for(const [key,value]of Object.entries({charges:row.charges,stackSize:row.stackSize,nativePriceDirty398:row.priceDirty}))assert.equal(f.item[key],value,label+' '+key);
  assert.equal(f.node.nativeField9c,row.releaseFlag,label);assert.deepEqual([7,8].map(i=>f.node.parameterData[i]>>>0),row.start,label);
  assert.equal(f.node.parameterCount,10,label+' native timer writes preserve parameter count');
  const offsets={'1856':'nativeTarget740','1864':'nativeAttackField748','2088':'nativeField828','536':'nativeSpellId218','532':'nativeSpellTarget214','548':'nativeSpellImpact224','552':'nativeSpellSpontaneous228','2072':'nativeSpellTarget818','2080':'nativeCasterOverride820','2084':'nativeCasterOverride824'};
  for(const [offset,value]of Object.entries(row.actor))assert.equal(f.actor[offsets[offset]],value,label+' '+offset);
  assert.deepEqual(f.actor.nativeSpellPoint208,row.point,label);assert.equal(f.actor.nativeSpellMetamagic22d,row.meta,label);assert.equal(f.actor.nativeSpellFeat23c,row.feat,label);
 }
});
test('item casting reads the live creature appearance for nonhumanoid animations',()=>{
 const session={items:{castProviders:()=>({})},combat:{},characterRules:{appearance:parse2da('2DA V2.0\n\nMODELTYPE\n0 P\n1 S\n2 F\n')}};
 const p=new SpellRuntime(session).itemActionProviders(),actor={objectType:5,authored:{Appearance_Type:1}};
 assert.equal(p.modelType(actor),'S');actor.creatureData={Appearance_Type:2};assert.equal(p.modelType(actor),'F');
});
