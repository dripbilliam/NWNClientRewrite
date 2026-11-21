import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {incrementAreaPlayers,decrementAreaPlayers,activateOnFirstClient} from '../src/creature_area_lifecycle.js';
test('area first/last-player ownership matches 432 original executions with stale IDs and live list mutation',async()=>{
 const data=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-area-player-count-observations.json',import.meta.url)));assert.equal(data.rows.length,432);
 for(const row of data.rows){
  const c=row.case,calls=[],area={nativePlayerCount150:c.count},ids=c.ids.slice(),objects=data.kinds.map((kind,i)=>({id:100+i,objectType:kind,nativeAILevel7c:c.level,nativeStatic5a0:Number(i%2===0),scriptLength:Number(i%2===0)})),p={
   ids:()=>ids,object:id=>{calls.push(['object',id]);return objects.find(o=>o.id===id)??null;},
   setAILevel:(o,n)=>{calls.push(['ai',o.id,n]);if(!c.locked)o.nativeAILevel7c=n;if(c.truncate)ids.splice(1);},
   scriptName:(o,index)=>{calls.push(['scriptName',o.id,index]);return{length:o.scriptLength};},
  };
  for(const [name,kind]of [['asCreature',5],['asAreaEffect',11],['asTrigger',7],['asDoor',10],['asPlaceable',9]])p[name]=o=>{calls.push([name,o.id]);return o.objectType===kind?o:null;};
  p.activateOnEntry=o=>activateOnFirstClient(o,p);
  if(c.operation==='increment')await incrementAreaPlayers(area,p);else await decrementAreaPlayers(area,p);
  assert.deepEqual({calls,count:area.nativePlayerCount150,levels:objects.map(o=>o.nativeAILevel7c),ids},{calls:row.calls,count:row.count,levels:row.levels,ids:row.ids},JSON.stringify(c));
 }
});
