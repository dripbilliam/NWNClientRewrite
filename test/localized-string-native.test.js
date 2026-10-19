import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {getLocalizedString} from '../src/localized_string.js';
import {nativeAssignedString} from '../src/native_gff_fields.js';
const observations=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-localized-string-observations.json',import.meta.url)));
test('localized-string coordinator matches original output retention, fallback order and gender state',async()=>{
 assert.equal(observations.target,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');
 for(const {case:c,status,text,gender,calls:expected}of observations.cases){
  const out={value:'previous'},calls=[];let state=c.initialGender;
  const actual=await getLocalizedString({strRef:42},c.language,out,c.gender,c.translate,{
   internal:(loc,key,out)=>{key>>>=0;calls.push(['internal',key]);const entry=c.entries[key];if(entry===undefined)return 0;out.value=nativeAssignedString(entry);return 1;},
   hasTalkTable:()=>Boolean(c.table),setGender:value=>{state=value;},fetch:(ref,parse)=>{calls.push(['fetch',ref,parse,state]);return{status:c.fetchStatus,text:c.fetchText};},
  });
  assert.equal(actual,status,JSON.stringify(c));assert.equal(out.value,text);assert.equal(state,gender);assert.deepEqual(calls,expected);
 }
});
