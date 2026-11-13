'use strict';
const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const root = path.resolve(__dirname, '../..');
const trace = path.join(root, '.cache/nwn71/capture-viewport-entry-a/entry.tracy');
const exporter = path.join(root, '.cache/native-tracy/vendor/windows-0.13.0/tracy-csvexport.exe');
const existing = JSON.parse(fs.readFileSync(path.join(root, '.cache/nwn71/capture-viewport-entry-a/render-stages-a.json')));
function exportRows(filter) {
  const out = spawnSync(exporter, ['-u', '-f', filter, '-s', '\t', trace], { encoding: 'utf8', windowsHide: true, shell: false, maxBuffer: 16 * 1024 * 1024, timeout: 30000 });
  if (out.status !== 0) throw new Error(`${filter}: ${out.error || out.stderr}`);
  const lines = out.stdout.split(/\r?\n/);
  if (lines.shift() !== 'name\tsrc_file\tsrc_line\tns_since_start\texec_time_ns\tthread\tvalue') throw new Error('Unexpected header');
  return lines.filter(Boolean).map(line => { const c = line.split('\t'); return { name:c[0], thread:c[5], start_ns:Number(c[3]), end_ns:Number(c[3])+Number(c[4]), duration_ms:Number(c[4])/1e6, value:c[6] }; });
}
const stages = exportRows('NWN71/Viewport/');
const syncs = exportRows('NWNCapture/Render/sync_scope');
const pumps = exportRows('NWN71/RenderPump/flush');
const stats = rows => Object.groupBy(rows, r => r.name);
const summarize = groups => Object.entries(groups).map(([name, rows]) => { const sorted = rows.map(r => r.duration_ms).sort((a,b)=>a-b); return {name,count:rows.length,median_ms:sorted[Math.floor(sorted.length/2)],p95_ms:sorted[Math.floor(sorted.length*.95)],max_ms:sorted.at(-1)}; }).sort((a,b)=>b.max_ms-a.max_ms);
const render = existing.rows.filter(r => r.name === 'render viewport' || r.name === 'viewport->draw_viewports');
const topSyncs = syncs.slice().sort((a,b)=>b.duration_ms-a.duration_ms).slice(0,12).map(s=>({start_s:s.start_ns/1e9,duration_ms:s.duration_ms,thread:s.thread,stages:stages.filter(r=>r.start_ns<s.end_ns&&r.end_ns>s.start_ns&&r.duration_ms>1).sort((a,b)=>b.duration_ms-a.duration_ms).slice(0,16).map(r=>({name:r.name,start_s:r.start_ns/1e9,ms:r.duration_ms,thread:r.thread})),render:render.filter(r=>r.start_ns<s.end_ns&&r.end_ns>s.start_ns&&r.duration_ms>5).sort((a,b)=>b.duration_ms-a.duration_ms).slice(0,10).map(r=>({name:r.name,start_s:r.start_ns/1e9,ms:r.duration_ms,thread:r.thread}))}));
const result = {trace,counts:{stages:stages.length,syncs:syncs.length,pumps:pumps.length},stageSummary:summarize(stats(stages)),syncSummary:summarize(stats(syncs)),pumpSummary:summarize(stats(pumps)),topSyncs};
const report=path.join(root,'.cache/nwn71/capture-viewport-entry-a/viewport-summary-a.json');
fs.writeFileSync(report,JSON.stringify(result,null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify({report,counts:result.counts,stageSummary:result.stageSummary,syncSummary:result.syncSummary,pumpSummary:result.pumpSummary,topSyncs:topSyncs.slice(0,5)}));
