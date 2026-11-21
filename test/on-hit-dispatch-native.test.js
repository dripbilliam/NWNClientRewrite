import fs from 'node:fs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {resolveOnHitProperty} from '../src/on_hit_property.js';
import {rulesetHash,rulesetInt} from '../src/combat_stats.js';
import {parse2da} from '../src/area.js';
const data=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-onhit-dispatch-observations.json',import.meta.url)));
test('on-hit property selection/chance/save/duration and subtype gates match complete original dispatcher',async()=>{
 assert.ok(data.rows.length>=640);
 for(const row of data.rows){
  const c=row.case,trace=[],actor={id:0x80000042},target={},item={id:[6,7,8,11,61].includes(c.base)?124:123},property={PropertyName:c.type??48,Subtype:c.subtype??9,CostValue:c.cost??4,Param1Value:c.param??3};
  const p={creature:()=>c.creature===false?null:target,int:async(kind,row,column)=>{const value=({Param1ResRef:c.paramRef??1,EffectChance:c.chance??50,DurationRounds:c.rounds??3,Value:c.dc??17})[column],found=c[({onhit:'onhitFound',duration:'durationFound',cost:'costFound'})[kind]]!==false;trace.push(['table',kind,row,column,Number(found),found?value:null]);return{found,value};},
   level:()=>{trace.push(['level']);return c.level??12;},random:()=>{trace.push(['random',c.random??0]);return c.random??0;},
   costTable:async id=>{trace.push(['costTable',id]);return'cost';},rulesDC:(name,value)=>{trace.push(['rulesDC',rulesetHash(name).toString(16).padStart(16,'0'),value]);return c.rulesDC??20;},
   save:async(_o,...args)=>{trace.push(['save',...args]);return c.saved??0;},constitution:()=>{const v=(c.constitution??2)&255;return v>=128?v-256:v;},race:()=>c.race??1,
   alignment:(_o,kind)=>{trace.push(['alignment',kind]);return c[kind]??0;},canSlay:()=>{trace.push(['canSlay']);return c.canSlay??1;},
   door:()=>c.door?{}:null,placeable:()=>c.placeable?{}:null,doorLevel:()=>c.doorLevel??20,placeableLevel:()=>c.placeableLevel??20,
   apply:(name,_a,_t,arg)=>trace.push(['apply',name,arg===property?'property':arg])};
  if(c.inventory!==false&&c.weapon!==false&&c.count!==0&&!c.nullProperty)await resolveOnHitProperty(actor,target,item,property,c.offhand??0,c.critical??0,p);
  assert.deepEqual(trace,row.trace.filter(r=>!['attack','weapon','ammo','property'].includes(r[0])),JSON.stringify(c));
 }
});
test('missing on-hit cost cells use the complete ONHIT_EFFECT_DC key while successful cells retain precedence',async()=>{
 assert.equal(rulesetHash('ONHIT_EFFECT_DC').toString(16),'e7ee69e2c0067ae9');
 for(const[found,labels,expected]of[[true,'0 ONHIT_EFFECT_DC 37\n1 NHIT_EFFECT_DC 71',17],[false,'0 ONHIT_EFFECT_DC 37\n1 NHIT_EFFECT_DC 71',37],[false,'0 NHIT_EFFECT_DC 71',20]]){
  const rules={ruleset:parse2da('2DA V2.0\n\nLabel Value\n'+labels)},dc=[],target={},property={PropertyName:48,Subtype:9,Param1Value:3,CostValue:4};
  await resolveOnHitProperty({id:99},target,{id:123},property,0,0,{creature:()=>target,int:async(kind,_row,column)=>kind==='cost'?{found,value:17}:{found:true,value:column==='Param1ResRef'?1:column==='EffectChance'?100:2},costTable:()=> 'cost',rulesDC:(name,value)=>rulesetInt(rules,name,value),random:()=>0,save:(_target,_save,value)=>{dc.push(value);return 1;},apply:()=>assert.fail('Successful save must reject the effect')});assert.deepEqual(dc,[expected]);
 }
});
