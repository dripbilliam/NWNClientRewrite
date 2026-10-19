import fs from 'node:fs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {scriptFindSubString} from '../src/script_string.js';
import {scriptVectorMagnitude} from '../src/script_utilities.js';
import {decodeGffText} from '../src/gff_text.js';
const native=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-find-magnitude-observations.json',import.meta.url))),view=new DataView(new ArrayBuffer(4));
const value=bits=>{view.setUint32(0,bits,true);return view.getFloat32(0,true);},bits=v=>{view.setFloat32(0,v,true);return view.getUint32(0,true);};
test('FindSubString matches complete original wrapper/Find/strstr with stored byte bounds and embedded NULs',()=>{
 for(const row of native.rows.filter(r=>r.case.mode==='find')){const c=row.case;
  if(c.allocatedEmpty){if(!c.needle&&c.text)assert.equal(row.output,0);continue;} // separate native representation evidence, not a semantic empty-string comparison
  const valid=c.pop1&&c.pop2&&(c.argc<3||c.intPop);assert.equal(row.result,!valid?0xfffffd81:c.push?0:0xfffffd82);
  if(valid)assert.equal(scriptFindSubString(decodeGffText(Buffer.from(c.text,'hex')),decodeGffText(Buffer.from(c.needle,'hex')),c.argc<3?0:c.start),row.output|0,JSON.stringify(c));
 }
 assert.equal(scriptFindSubString('€é€','\x80',1),2);assert.throws(()=>scriptFindSubString('🙂','x'),/encoding/);
});
test('VectorMagnitude matches original FLOAT bits including finite overflow/underflow and NaN/Infinity inputs',()=>{
 assert.equal(native.rows.length,1477);
 for(const row of native.rows.filter(r=>r.case.mode==='magnitude')){const c=row.case;assert.equal(row.result,!c.pop1?0xfffffd81:c.push?0:0xfffffd82);if(c.pop1)assert.equal(bits(scriptVectorMagnitude(c.bits.map(value))),row.output,JSON.stringify(c));}
 assert.throws(()=>scriptVectorMagnitude([1,2]),/unavailable/);
});
