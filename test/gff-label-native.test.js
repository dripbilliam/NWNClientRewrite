import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {nativeGffLabel,readNativeGff} from '../src/native_gff_fields.js';
import {parseGff} from '../src/gff.js';
import {writeGff,gffRecord,gffField} from '../src/gff_writer.js';
const native=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-gff-label-observations.json',import.meta.url)));
test('GFF query names match original16-byte label lookup and field-index selection',()=>{
 for(const row of native.rows){
  const label=nativeGffLabel(row.query),ordinal=row.order.findIndex(index=>row.labels[index]===label),fieldIndex=ordinal<0?null:row.order[ordinal];
  const data=parseGff(writeGff('UTP ',gffRecord(Object.fromEntries(row.order.map(index=>[row.labels[index],gffField(4,500+index)]))))).root,result=readNativeGff(data,row.query,4,-1);
  assert.equal(ordinal<0?0xffffffff:ordinal,row.ordinal,JSON.stringify(row));assert.equal(fieldIndex,row.fieldIndex,JSON.stringify(row));
  assert.equal(result.status,Number(row.value!==null));assert.equal(result.value,row.value??-1);
 }
 assert.equal(native.rows.length,144);
});
