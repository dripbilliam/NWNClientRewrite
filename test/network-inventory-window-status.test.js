import fs from 'node:fs';import test from 'node:test';import assert from 'node:assert/strict';
import {NativeMessageReader} from '../src/native_message.js';import {readInventoryWindowStatus} from '../src/network_inventory_window_status.js';
test('96 original13/1 writer/receiver cases preserve raw open/owner fields separately from container25/1',()=>{
 const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-inventory-window-observations-v1.json',import.meta.url)));assert.equal(oracle.target,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');assert.equal(oracle.cases.length,96);
 for(const row of oracle.cases){const packet=Buffer.from(row.packet,'hex');assert.deepEqual([...packet.subarray(0,3)],[80,13,1]);const reader=new NativeMessageReader(row.case.format);reader.setReadMessage(packet.subarray(3),packet.length-3,0xffffffff,1);assert.deepEqual(readInventoryWindowStatus(reader),{kind:'inventory-window-status',open:row.case.open!==0,ownerId:row.case.ownerId});assert.equal(reader.messageReadOverflow(),0);assert.equal(reader.messageReadUnderflow(),0);}
});
