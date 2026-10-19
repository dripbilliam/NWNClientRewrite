import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {scriptLocationAccess} from '../src/script_location.js';
import {scriptNormalizeVector,scriptPrintString} from '../src/script_utilities.js';
import {decodeGffText} from '../src/gff_text.js';
const data=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-script-utilities-observations.json',import.meta.url))),storage=new DataView(new ArrayBuffer(4));
const value=bits=>{storage.setUint32(0,bits,true);return storage.getFloat32(0,true);},bits=number=>{storage.setFloat32(0,number,true);return storage.getUint32(0,true);};
test('location access matches original wrapper results, raw IDs, FLOAT angles and normalized-Y adjustment',()=>{
 let count=0;
 for(const row of data.rows.filter(r=>r.case.mode==='location')){const c=row.case;if(c.pop===0){assert.equal(row.result,0xfffffd81);assert.equal(row.frees,0);continue;}
  assert.equal(row.frees,1);if(![223,224,225].includes(c.command??225)){assert.equal(row.output,null);assert.equal(row.result,0);continue;}
  const location={areaId:c.areaId??0x80000001,position:(c.positionBits??[0,0,0]).map(value),nativeOrientation:c.vectorBits.map(value),orientation:12345},result=scriptLocationAccess(c.command??225,location);
  const actual=row.output.kind==='vector'?{kind:'vector',bits:result.map(bits)}:row.output.kind==='object'?{kind:'object',value:result}:{kind:'float',bits:bits(result)};
  assert.deepEqual(actual,row.output,JSON.stringify(c));assert.equal(row.result,c.push===0?0xfffffd82:0);count++;
 }
 assert.equal(count,730);
});
test('script normalization matches complete original wrapper including zero, underflow, near-unit and overflow',()=>{
 let count=0;for(const row of data.rows.filter(r=>r.case.mode==='normalize')){const c=row.case;if(c.pop===0){assert.equal(row.result,0xfffffd81);continue;}
  assert.deepEqual(scriptNormalizeVector(c.vectorBits.map(value)).map(bits),row.output.bits,JSON.stringify(c));assert.equal(row.result,c.push===0?0xfffffd82:0);count++;
 }assert.equal(count,714);
});
test('PrintString matches native fixed format, exact prefix1, C-string truncation and typed-pop failures',()=>{
 let count=0;for(const row of data.rows.filter(r=>r.case.mode==='print')){const c=row.case;if(c.pop===0||(c.argc>=2&&c.intPop===0)){assert.equal(row.result,0xfffffd81);assert.deepEqual(row.logs,[]);continue;}
  const text=c.nullString?'':decodeGffText(Buffer.from(c.hex,'hex')),logs=[];scriptPrintString(text,c.argc>=2?c.prefix:0,(message,metadata)=>logs.push({message,metadata}));
  assert.equal(logs.length,1);assert.deepEqual(logs[0].metadata,row.logs[0],JSON.stringify(c));assert.equal(logs[0].message,row.logs[0].format.replace('%s',()=>row.logs[0].text));assert.equal(row.result,0);count++;
 }assert.equal(count,121);
});
