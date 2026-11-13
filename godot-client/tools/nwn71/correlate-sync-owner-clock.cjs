'use strict';
// Correlate absolute monotonic intervals emitted by the NWN-71 private probe.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const assert = require('node:assert/strict');

const root = path.resolve(__dirname, '../..');
const stage = path.join(root, '.cache/nwn71/sync-owner-clock-a');
const receipt = JSON.parse(fs.readFileSync(path.join(stage, 'run-receipt.json'), 'utf8'));
const input = path.join(root, 'reports/nwn71-sync-owner-clock-a.engine.log');
const bytes = fs.readFileSync(input);
const sha = crypto.createHash('sha256').update(bytes).digest('hex');
assert.equal(sha, receipt.engineLogSha256);
assert.equal(receipt.engineSha256, JSON.parse(fs.readFileSync(path.join(stage, 'build-receipt.json'), 'utf8')).binary.sha256);

const rows = [];
for (const line of bytes.toString('utf8').split(/\r?\n/)) {
  const match = line.match(/^(NWN71_CLOCK|NWN71_WAIT|NWN71_DEVICE_WAIT)\s+(.*)$/);
  if (!match) continue;
  const kv = Object.fromEntries([...match[2].matchAll(/(\w+)=([^\s]+)/g)].map(x => [x[1], x[2]]));
  const start = Number(kv.start_us), end = Number(kv.end_us), duration = Number(kv.duration_us);
  assert(Number.isSafeInteger(start) && Number.isSafeInteger(end) && Number.isSafeInteger(duration));
  assert.equal(end - start, duration);
  rows.push({type:match[1], ...kv, start_us:start, end_us:end, duration_us:duration});
}
assert.equal(rows.filter(x => x.type === 'NWN71_CLOCK').length, receipt.clockRows);
assert.equal(rows.filter(x => x.type === 'NWN71_WAIT').length, receipt.waitRows);
assert.equal(rows.filter(x => x.type === 'NWN71_DEVICE_WAIT').length, receipt.deviceRows);
const overlap = (a,b) => Math.max(0, Math.min(a.end_us,b.end_us)-Math.max(a.start_us,b.start_us));
function unionOverlaps(parent, children) {
  const intervals = children.map(child => [Math.max(parent.start_us,child.start_us),Math.min(parent.end_us,child.end_us)])
    .filter(([a,b]) => b>a).sort((a,b)=>a[0]-b[0]);
  let total=0, lastStart=null, lastEnd=null;
  for (const [a,b] of intervals) {
    if (lastStart === null) {lastStart=a;lastEnd=b;continue;}
    if (a>lastEnd) {total+=lastEnd-lastStart;lastStart=a;lastEnd=b;} else lastEnd=Math.max(lastEnd,b);
  }
  return total+(lastStart === null ? 0 : lastEnd-lastStart);
}
const summaries={};
for (const row of rows) {
  const key=row.type+':'+(row.kind || row.producer);
  const item=summaries[key] ||= {count:0,max_us:0,total_us:0};
  item.count++; item.max_us=Math.max(item.max_us,row.duration_us); item.total_us+=row.duration_us;
}
const waits=rows.filter(x=>x.type==='NWN71_WAIT');
const fences=rows.filter(x=>x.type==='NWN71_DEVICE_WAIT');
const draws=rows.filter(x=>x.type==='NWN71_CLOCK' && x.kind==='render_draw').sort((a,b)=>b.duration_us-a.duration_us);
const flushes=rows.filter(x=>x.type==='NWN71_CLOCK' && x.kind==='render_flush').sort((a,b)=>b.duration_us-a.duration_us);
function annotate(row) {
  const touchingWaits=waits.filter(w=>overlap(row,w)>0);
  const touchingFences=fences.filter(w=>overlap(row,w)>0);
  return {
    start_us:row.start_us,end_us:row.end_us,duration_us:row.duration_us,
    named_wait_union_us:unionOverlaps(row,touchingWaits),
    fence_union_us:unionOverlaps(row,touchingFences),
    waits:touchingWaits.map(w=>({producer:w.producer,group:w.group,shader:w.shader,overlap_us:overlap(row,w),duration_us:w.duration_us})).sort((a,b)=>b.overlap_us-a.overlap_us),
    fences:touchingFences.map(w=>({overlap_us:overlap(row,w),duration_us:w.duration_us})),
  };
}
const report={issue:'NWN-71',run:receipt.run,offline:true,noFps:true,engineLogSha256:sha,
  engineSha256:receipt.engineSha256,selectionSha256:receipt.selectionSha256,
  thresholds_us:{main_sync:20000,render_draw:20000,render_flush:20000,render_yield:20000,group_wait:2000,vulkan_fence:1000},
  summaries,draws:draws.map(annotate),flushes:flushes.map(annotate),
  firstDrawWithShaderWait:draws.map(annotate).find(d=>d.waits.some(w=>w.producer==='shader')) || null,
  mainSyncOverThreshold:rows.filter(x=>x.type==='NWN71_CLOCK' && x.kind==='main_sync').length,
};
const output=path.join(stage,'correlation.json');
fs.writeFileSync(output,JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify({output,rows:rows.length,summaries,topDraws:report.draws.slice(0,8),topFlushes:report.flushes.slice(0,5)},null,2));
