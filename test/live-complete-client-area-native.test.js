import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {NativeMessageReader} from '../src/native_message.js';

test('complete original ClientArea sender, area packer, writers and envelope match ten assembled installed messages',()=>{
 const load=name=>JSON.parse(fs.readFileSync(new URL(`../backups/animations/${name}.json`,import.meta.url))),native=load('native-live-complete-client-area-observations'),source=load('live-complete-client-area');
 assert.equal(native.rows.length,10);assert.equal(source.cases.length,10);assert.equal(source.reports.length,10);
 for(const row of native.rows){
  const index=source.cases.findIndex(c=>c.case.format===row.format&&c.case.id===row.areaId);assert.ok(index>=0);
  const fixture=source.cases[index],report=source.reports[index],bytes=Buffer.from(row.nativeHex,'hex'),expected=Buffer.from(fixture.packetHex,'hex'),mask=Buffer.from(fixture.definedMaskHex,'hex');
  assert.equal(row.result,1);assert.deepEqual(row.diagnostics,[]);assert.deepEqual(row.observation,fixture.observation);assert.equal(row.sourceHex,fixture.packetHex);assert.equal(row.definedMaskHex,fixture.definedMaskHex);
  assert.equal(bytes.length,expected.length);assert.equal(mask.length,bytes.length);assert.equal(bytes.length,report.packetBytes);assert.deepEqual([...bytes.subarray(0,3)],[80,4,1]);assert.deepEqual([...mask.subarray(0,3)],[255,255,255]);
  for(let i=0;i<bytes.length;i++)assert.equal(bytes[i]&mask[i],expected[i]&mask[i],`area ${row.areaId}, format ${row.format}, byte ${i}`);
  assert.deepEqual(row.trace.find(call=>call[0]==='transportBoundary'),['transportBoundary',42,bytes.length,0]);assert.ok(row.trace.some(call=>call[0]==='clearLastMap'));assert.deepEqual(row.trace.filter(call=>call[0]==='setBmp').at(-1),['setBmp',-1]);
  assert.equal(report.bodyPrefixDecoded,true);assert.equal(report.notTransmitted,true);
  const reader=new NativeMessageReader(row.format);assert.equal(reader.setReadMessage(bytes.subarray(3),bytes.length-3,42,1),1);
  assert.equal(reader.readInt(),report.selectedScreen);for(const coordinate of [...fixture.case.clientArea.point,Math.fround(Math.atan2(Math.fround(fixture.case.clientArea.orientation[1]),Math.fround(fixture.case.clientArea.orientation[0])))])assert.equal(reader.readFloat(),Math.fround(coordinate));
  assert.equal(reader.readBool(),0);assert.equal(reader.readObjectIdClient(),(row.areaId|0x80000000)>>>0);
 }
});
