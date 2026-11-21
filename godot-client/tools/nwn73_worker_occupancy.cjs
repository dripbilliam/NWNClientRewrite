// Summarize instrumented WorkerThreadPool task occupancy from a Tracy export.
// Scope elapsed time is not necessarily CPU time or observed core placement.
const fs = require('fs');
const [input, output, widthArg] = process.argv.slice(2);
if (!input || !output) throw new Error('usage: node nwn73_worker_occupancy.cjs input.json output.json [bin_ms]');
const widthMs = Number(widthArg || 1000);
if (!Number.isFinite(widthMs) || widthMs <= 0) throw new Error('bin_ms must be positive');
const tasks = JSON.parse(fs.readFileSync(input, 'utf8')).rows.filter(r => r.name === 'NWNCapture/Worker/task_scope');
if (!tasks.length) throw new Error('No WorkerThreadPool task scopes');
const first = Math.min(...tasks.map(r => r.start_ns));
const last = Math.max(...tasks.map(r => r.end_ns));
const width = Math.round(widthMs * 1e6);
function description(value) { return String(value || '').split(';').find(s => s.startsWith('description='))?.slice(12) || ''; }
const bins = [];
for (let left = first; left < last; left += width) {
  const right = Math.min(left + width, last);
  const intervals = new Map(); const descriptions = new Map(); let scopeCount = 0;
  for (const task of tasks) {
    const start = Math.max(left, task.start_ns), end = Math.min(right, task.end_ns);
    if (start >= end) continue;
    scopeCount++;
    if (!intervals.has(task.thread)) intervals.set(task.thread, []);
    intervals.get(task.thread).push([start, end]);
    const label = description(task.value);
    descriptions.set(label, (descriptions.get(label) || 0) + 1);
  }
  let occupiedNs = 0;
  for (const thread of intervals.values()) {
    thread.sort((a,b) => a[0]-b[0]);
    let stop = left;
    for (const [start,end] of thread) if (end > stop) { occupiedNs += end-Math.max(start,stop); stop=end; }
  }
  bins.push({relative_start_ms: +( (left-first)/1e6 ).toFixed(3), task_scopes: scopeCount,
    threads_with_tasks: intervals.size, occupied_thread_equivalents: +(occupiedNs/(right-left)).toFixed(3),
    task_descriptions: Object.fromEntries([...descriptions].sort((a,b)=>b[1]-a[1]).slice(0,8))});
}
const report = {input, scope:'Observed overlapping task-scope elapsed intervals. No CPU core placement, true CPU utilization, or uninstrumented task coverage claim.',
  duration_ms:+((last-first)/1e6).toFixed(3), task_scopes:tasks.length,
  threads_with_tasks:new Set(tasks.map(r=>r.thread)).size, bin_ms:widthMs, bins};
fs.mkdirSync(require('path').dirname(output), {recursive:true});
fs.writeFileSync(output, JSON.stringify(report,null,2)+'\n');
