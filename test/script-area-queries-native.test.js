import fs from 'node:fs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {scriptAreaAboveGround,scriptAreaInterior} from '../src/script_area_queries.js';
const data=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-spell-area-queries-observations.json',import.meta.url)));
test('area queries match4160 complete original wrappers, low-byte bits and distinct invalid defaults',()=>{
 assert.equal(data.rows.length,4160);for(const row of data.rows){const c=row.case;if(!c.pop){assert.equal(row.result,0xfffffd81);assert.equal(row.output,null);assert.deepEqual(row.lookups,[]);continue;}
  const area=c.exists?{flags:c.flags}:null,result=(c.mode==='above'?scriptAreaAboveGround:scriptAreaInterior)(area);assert.equal(result|0,row.output|0,JSON.stringify(c));assert.equal(row.result,c.push?0:0xfffffd82);assert.deepEqual(row.lookups,[0x12345678]);
 }
});
