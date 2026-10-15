import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {reflexAdjustedDamage} from '../src/reflex_damage.js';
import {floatingText} from '../src/floating_text.js';
import {broadcastFloatyData} from '../src/combat_broadcast.js';
import {scriptDistanceBetweenLocations} from '../src/script_geometry.js';
const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-spell-shared-feedback-observations.json',import.meta.url)));
test('Reflex damage/save/visual order, floating feedback and location distance match native instructions',async()=>{
  for(const row of oracle.rows){const c=row.case,calls=[],actor={id:99,objectType:c.objectType??5,areaId:99,position:[0,0,0]},viewer={id:100,objectType:5,areaId:c.viewerArea??99,
    position:(c.point??[30,0,0]).map((n,i,p)=>i===1?p[2]:i===2?-p[1]:n)},client={id:100,object:viewer};let result=null;
    if(c.mode==='reflex'){
      const args=c.argc===4?[99,c.damage??11,c.category??15,101]:[c.damage??11,99,c.dc??10,c.category??15,101];
      result=await reflexAdjustedDamage(args,{dcScratch:c.dcScratch??99,creature:()=>c.exists===false||actor.objectType!==5?null:actor,
        hasFeat:(_o,id)=>{calls.push(['feat',id]);return(c.feats??[]).includes(id)?c.featResult??1:0;},
        save:(_o,...args)=>{calls.push(['save',...args]);return c.save??1;},evasionVisual:(_o,creator)=>calls.push(['visual',256,creator])});
    }else if(c.mode==='floating'){
      const args=[c.strRef??123,99];if(c.argc>=3)args.push(c.display??1);if(c.argc>=4)args.push(c.sound??1);
      await floatingText(525,args,{object:()=>c.exists===false?null:actor,broadcast:(_o,data)=>calls.push(['broadcast',data]),client:()=>c.client===false?null:{id:99},send:(client,type,data)=>calls.push(['send',client.id,type,data])});
    }else if(c.mode==='distance'){
      const distance=scriptDistanceBetweenLocations({areaId:c.area1??99,position:c.from??[1,2,3]},{areaId:c.area2??99,position:c.to??[4,6,7]});
      const v=new DataView(new ArrayBuffer(4));v.setFloat32(0,distance,true);result=v.getUint32(0,true);
    }else await broadcastFloatyData(actor,{objectIds:[99],integers:[123,1,...Array(7).fill(0),93]},
      {members:()=>c.faction===false?null:[100,100],client:()=>c.client===false?null:{...client,object:c.viewer===false?null:viewer},send:(client,type,data)=>calls.push(['send',client.id,type,data])});
    assert.equal(result,row.result,JSON.stringify(c));assert.deepEqual(calls,row.calls,JSON.stringify(c));
  }
});
test('legacy uninitialized Reflex DC remains explicit in live binding',async()=>{
  await assert.rejects(reflexAdjustedDamage([99,10,0,100],{}),/DC storage/);
});
