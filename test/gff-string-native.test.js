import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {readNativeGff,nativeAssignedString} from '../src/native_gff_fields.js';
import {parseGff} from '../src/gff.js';
import {writeGff,gffRecord,gffField} from '../src/gff_writer.js';
const native=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-gff-string-observations.json',import.meta.url)));
test('parsed GFF string bridge matches original reader and real explicit-length string assignment',()=>{
 for(const row of native.rows){
  const c=row.case;
  if(c.size!==undefined){assert.equal(row.status,Number(c.data&&c.size>=7));assert.equal(row.value,c.data&&c.size>=7?'abc':'fallback');continue;}
  const value=c.type===0||c.type===4?3:c.type===12?{strRef:3,entries:[]}:c.value;
  const data=parseGff(writeGff('UTW ',gffRecord(c.found?{Value:gffField(c.type,value)}:{}))).root;
  const result=readNativeGff(data,'Value',10,nativeAssignedString(c.default));
  assert.equal(result.status,row.status,JSON.stringify(c));assert.equal(result.value,row.value,JSON.stringify(c));assert.equal(result.value.length,row.length);
 }
 assert.equal(native.rows.length,162);
});
