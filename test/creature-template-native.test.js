import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {loadCreatureTemplateData} from '../src/creature_template.js';
const capture=JSON.parse(readFileSync(new URL('../backups/animations/native-creature-template-observations.json',import.meta.url)));
test('full creature template wrapper matches135 original runs including reversed stats result, tag override, resource and spell-use order',async()=>{
 assert.equal(capture.rows.length,135);
 for(const expected of capture.rows){
  const c=expected.case,calls=[],object={tag:'',templateResRef:'previous'};const result=await loadCreatureTemplateData(object,c.reference,c.tag,{
   resource:(type,signature,name)=>{calls.push(['resource',type,signature,name]);return{loaded:c.loaded};},release:(_r,flag)=>calls.push(['release',flag]),warning:text=>calls.push(['warning',text]),root:()=>{calls.push(['root']);return{};},
   readStats:(_o,_r,_data,...flags)=>{calls.push(['readStats',...flags]);object.tag='authored';return c.statsResult;},featBonuses:(_o,flag)=>calls.push(['featBonuses',flag]),setTemplate:(_o,name)=>{object.templateResRef=name;calls.push(['setTemplate',name]);},
   scripts:()=>calls.push(['scripts']),items:(_o,_r,_data,...flags)=>calls.push(['items',...flags]),spells:(_o,_r,_data,flag)=>calls.push(['spells',flag]),variables:()=>calls.push(['variables']),
   asTag:value=>{calls.push(['asTag',value]);return`SANITIZED:${value}`;},assignTag:(_o,value)=>{object.tag=value;calls.push(['assignTag',value]);},postProcess:()=>calls.push(['postProcess',object.tag,object.templateResRef]),updateSpellUses:(_o,level)=>calls.push(['updateSpellUses',level]),
  });assert.deepEqual({result,calls},{result:expected.result,calls:expected.calls},JSON.stringify(c));
 }
});
