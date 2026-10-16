import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {scriptExploreArea,scriptTileExploration,scriptAutomapExploration} from '../src/automap_script.js';
test('five decoded automap script calls match 640 original VM wrapper executions',async()=>{
 const data=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-automap-script-observations.json',import.meta.url)));assert.equal(data.rows.length,640);
 for(const row of data.rows){
  const c=row.case,calls=[],actor={id:99,nativeAutoMapEnabled6e0:c.old},area={id:88},p={
   area:id=>{calls.push(['area',id]);return c.area?area:null;},client:id=>{calls.push(['client',id]);return c.client?{}:null;},creature:id=>{calls.push(['creature',id]);return c.creature?actor:null;},
   object:id=>{calls.push(['object',id]);return id===88&&c.area?area:id===99&&c.creature?actor:null;},
   asArea:o=>{calls.push(['asArea',o.id]);return c.areaType?o:null;},asCreature:o=>{calls.push(['asCreature',o.id]);return c.creatureType?o:null;},
   reveal:(o,...args)=>calls.push(['reveal',o.id,...args]),explored:(o,...args)=>{calls.push(['explored',o.id,...args]);return c.previous;},setTile:(o,...args)=>calls.push(['setTile',o.id,...args]),
  };
  const result=c.command===403?await scriptExploreArea(c.args,p):c.command<868?await scriptTileExploration(c.command,c.args,p):await scriptAutomapExploration(c.command,c.args,p);
  assert.deepEqual({calls,result:result??null,enabled:actor.nativeAutoMapEnabled6e0},{calls:row.calls,result:row.result,enabled:row.enabled},JSON.stringify(c));
 }
});
