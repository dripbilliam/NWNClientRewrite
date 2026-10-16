import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

test('original packer matches every defined bit and final counters for installed live-session area bodies',()=>{
 const data=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-live-area-pack-observations.json',import.meta.url))),live=JSON.parse(fs.readFileSync(new URL('../backups/animations/live-area-pack.json',import.meta.url))),cases=JSON.parse(fs.readFileSync(new URL('../backups/animations/live-area-pack-cases.json',import.meta.url)));
 assert.equal(data.rows.length,10);assert.equal(live.reports.length,10);assert.equal(live.failures.length,0);assert.equal(cases.cases.length,10);
 assert.ok(data.rows.some(r=>r.objects>=204));assert.ok(data.rows.some(r=>r.tiles===144));
 for(const row of data.rows){
  const source=cases.cases.find(r=>r.case.format===row.format&&r.case.id===row.areaId),report=live.reports.find(r=>r.format===row.format&&r.areaId===row.areaId);assert.ok(source);assert.ok(report);assert.equal(report.error,null);assert.equal(row.result,1);assert.deepEqual(row.diagnostics,[]);
  assert.deepEqual(row.observation,source.observation);assert.equal(row.sourceHex,source.packetHex);assert.equal(row.definedMaskHex,source.definedMaskHex);
  const native=Buffer.from(row.nativeHex,'hex'),bytes=Buffer.from(row.sourceHex,'hex'),mask=Buffer.from(row.definedMaskHex,'hex');assert.equal(native.length,report.packetBytes);assert.equal(bytes.length,native.length);assert.equal(mask.length,native.length);
  for(let i=0;i<bytes.length;i++)assert.equal(bytes[i]&mask[i],native[i]&mask[i],`area ${row.areaId}, mode ${row.format}, byte ${i}`);
  assert.deepEqual([...mask.subarray(0,3)],[0,0,0]);assert.equal(report.notTransmitted,true);
 }
});
