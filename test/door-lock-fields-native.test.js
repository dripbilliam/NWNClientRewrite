import fs from 'node:fs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {initializeDoorLocks,loadDoorLocks,doorOpenLockDC} from '../src/door_lock_fields.js';
import {getObjectLocked} from '../src/lock_query.js';
import {parseGff} from '../src/gff.js';
import {writeGff,gffRecord as R,gffField as F} from '../src/gff_writer.js';
const data=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-door-lock-fields-observations.json',import.meta.url)));
test('door lock constructor fields and typed load/defaults match original BYTE/BOOL read-store segments',()=>{
 assert.equal(data.rows.length,1501);
 for(const row of data.rows){const c=row.case,o={objectType:10};if(c.constructor===true)initializeDoorLocks(o);
  else{Object.assign(o,{nativeDoorOpenLockDC41f:c.oldDC,locked:c.oldLocked,nativeDoorKeyRequired450:c.oldLocked});const fields={};for(const name of['OpenLockDC','Locked','KeyRequired'])if(c[name])fields[name]=F(c[name].type,c[name].value);loadDoorLocks(o,parseGff(writeGff('UTD ',R(fields))).root);}
  assert.equal(doorOpenLockDC(o),row.openLockDC,JSON.stringify(c));assert.equal(getObjectLocked(o),row.locked,JSON.stringify(c));assert.equal(o.nativeDoorKeyRequired450,row.keyRequired,JSON.stringify(c));
 }
});
