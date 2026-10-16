import fs from 'node:fs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {applyTurnResistance,turnResistanceHD,constructTurnResistance} from '../src/turn_resistance.js';
test('turning resistance apply/query/constructor owners match original instruction observations',()=>{
 const data=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-turn-resistance-observations.json',import.meta.url)));assert.equal(data.rows.length,499);
 for(const row of data.rows){const c=row.case,calls=[],o={nativeStatsIsPCb0:c.pc??0,effects:(c.effects??[]).map(([type,n])=>({type,integers:[n]}))};let result=0,output=null;
  if(c.mode==='apply')result=applyTurnResistance(c.object?o:null,{durationType:c.durationType},c.loading,{dead:()=>{calls.push(['dead']);return c.dead;},asCreature:()=>{calls.push(['creature']);return c.creature?o:null;},rule:(name,fallback)=>{calls.push(['rule',name,fallback]);return c.rule;}});
  else if(c.mode==='query')result=turnResistanceHD(o);
  else if(c.mode==='remove')result=1;
  else{calls.push(['pop']);if(c.pop===0)result=-639;else{const effect=constructTurnResistance(c.ordinal??553,[c.value??0],99,{create:()=>({id:'0000000000000065',type:0,subtype:0,creatorId:0x7f000000,integers:Array(8).fill(0)}),setCreator:(e,id)=>{calls.push(['creator',id]);e.creatorId=id;}});output=effect;calls.push(['push']);if(c.push===0)result=-638;}}
  assert.deepEqual({result,calls,output},{result:row.result,calls:row.calls,output:row.output},JSON.stringify(c));
 }
});
