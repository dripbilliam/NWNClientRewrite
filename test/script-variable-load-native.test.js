import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {ScriptVariableTable} from '../src/script_variables.js';
import {loadScriptVariables} from '../src/script_variable_load.js';
import {readNativeGff} from '../src/native_gff_fields.js';
import {parseGff} from '../src/gff.js';
import {writeGff} from '../src/gff_writer.js';
const native=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-script-variable-load-observations.json',import.meta.url)));
const canonical=x=>JSON.parse(JSON.stringify(x));

test('variable load and location retrieval match full native owners with explicit structured/map boundaries',()=>{
 for(const row of native.rows){
  const c=row.case,calls=[],table=new ScriptVariableTable();
  for(const [name,fields]of Object.entries(c.initial??{}))for(const [type,value]of Object.entries(fields))table.set(name,type,value);
  if(c.get!==undefined){assert.deepEqual(table.getLocation(c.get),row.location,JSON.stringify(c));continue;}
  const data=parseGff(writeGff('UTW ',c.data??{type:0xffffffff,fields:{}})).root,adapter={
   setInt:(name,value,loading)=>{calls.push(['setInt',name,value,loading]);table.setInt(name,value,loading);},
   setFloat:(...a)=>table.setFloat(...a),setString:(...a)=>table.setString(...a),setObject:(...a)=>table.setObject(...a),setLocation:(...a)=>table.setLocation(...a),
  };
  loadScriptVariables(adapter,data,{
   read:(record,name,type,fallback)=>{calls.push(['read',type,name,fallback]);return readNativeGff(record,name,type,fallback);},
   loadCswy:()=>{calls.push(['loadCswy']);return c.cswy??null;},
   setCswy:(t,name,value)=>{assert.equal(t,adapter);calls.push(['setCswy',name,value]);table.set(name,'cswy',value);},
   createJson:()=>{calls.push(['jsonDefault']);return null;},
   parseJson:value=>{calls.push(['parseJson',value]);return c.jsonResult??null;},
   setJson:(t,name,value)=>{assert.equal(t,adapter);calls.push(['setJson',name,value]);table.set(name,'json',value);},
  });
  const label=JSON.stringify(c);assert.deepEqual(canonical(calls),row.calls,label);assert.deepEqual(canonical(Object.fromEntries(table.entries)),row.entries,label);
 }
 assert.equal(native.rows.length,237);
});

test('local location copies retain invalid-area nonzero vectors and return owned empty defaults',()=>{
 const t=new ScriptVariableTable(),value={areaId:0x7f000000,position:[1,0,0],nativeOrientation:[0,0,0]};t.setLocation('l',value);value.position[0]=99;assert.equal(t.getLocation('l').position[0],1);
 const first=t.getLocation('empty');first.position[0]=42;assert.deepEqual(t.getLocation('empty'),{areaId:0x7f000000,position:[0,0,0],nativeOrientation:[0,0,0]});
 t.setLocation('l',{areaId:0x7f000000,position:[0,0,0],nativeOrientation:[0,0,0]});assert.equal(t.entries.size,0);
 t.set('shared','json',false);t.setInt('shared',0);assert.equal(t.get('shared','json'),false);assert.equal(t.entries.size,1);t.deleteIndex('shared','json');assert.equal(t.entries.size,0);
});
