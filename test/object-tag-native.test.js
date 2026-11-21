import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {nativeObjectTag} from '../src/object_tag.js';
const native=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-object-tag-observations.json',import.meta.url)));
test('AsTAG and SetTag match original byte classification, stored length, empty and 63-byte limit',()=>{
 for(const row of native.rows)assert.equal(nativeObjectTag(row.input),row.result,JSON.stringify(row));
 assert.equal(native.rows.length,888);
});
