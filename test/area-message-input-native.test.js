import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {scriptSetAreaTransitionBmp,setAreaTransitionBmp,importAreaPackEntry,importAreaLoadScreen,loadingScreenString} from '../src/client_area_message.js';
test('area-message typed inputs and per-client script state match 256 original executions',async()=>{
 const data=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-area-message-input-observations.json',import.meta.url)));assert.equal(data.rows.length,256);
 for(const row of data.rows){
  const c=row.case;
  if(c.operation==='script'){
   const calls=[],client={nativeAreaTransitionBmp20:27,nativeUserTransitionBmp28:'custom'};
   await scriptSetAreaTransitionBmp([c.index,c.text],c.self,{client:id=>{calls.push(['client',id]);return c.client?client:null;},setBmp:setAreaTransitionBmp});
   assert.deepEqual({calls,bmp:client.nativeAreaTransitionBmp20,user:client.nativeUserTransitionBmp28},{calls:row.calls,bmp:row.bmp,user:row.user},JSON.stringify(c));
  }else if(c.operation==='entry'){
   const module={},fields=Object.fromEntries(Object.entries(c.fields).filter(([_k,v])=>v!==null));importAreaPackEntry(module,fields);assert.deepEqual(Object.values(module.nativeField108),row.fields,JSON.stringify(c));
  }else if(c.operation==='screen'){
   const area={};importAreaLoadScreen(area,c.screen===null?{}:{LoadScreenID:c.screen});assert.equal(area.nativeLoadScreenId350,row.screen,JSON.stringify(c));
  }else{
   const table={columns:c.columns,orderedRows:c.cells.map(row=>Object.fromEntries(c.columns.map((key,i)=>[key,row[i]]))),orderedCells:c.cells,defaultValue:c.default};
   assert.deepEqual(loadingScreenString(table,c.row,c.column),{status:row.status,value:row.value},JSON.stringify(c));
  }
 }
});
