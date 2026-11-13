'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../..'),stage=path.join(root,'.cache/nwn74/inner-phase-clock-a');
const sha=file=>crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const run=JSON.parse(fs.readFileSync(path.join(stage,'run-receipt.json')));
assert(run.success&&run.fpsFileAbsent&&run.acceptedSourceUnchanged&&run.acceptedBinaryUnchanged);
const log=path.join(root,'reports/nwn74-inner-phase-clock-a.engine.log');
assert.equal(sha(log),run.engineLogSha256);
const rows=fs.readFileSync(log,'utf8').split(/\r?\n/).filter(s=>s.startsWith('NWN74_INNER ')).map(line=>{
 const entries=[...line.matchAll(/([a-z_]+)=([0-9]+)/g)].map(m=>[m[1],Number(m[2])]);
 return Object.fromEntries(entries);
});
assert.equal(rows.length,run.phaseRows);
const settled=rows.filter(r=>r.frame>=2796&&r.frames===120&&r.scene_calls===120);
assert.equal(settled.length,9);
const phases=['scene','setup_environment','fill_render_list','fill_instance_data','sort_primary','sort_secondary','render_list_template','draw_list_wrapper','pre_opaque'];
const result={issue:'NWN-74',diagnosticOnly:true,engineSha256:run.engineSha256,driverSha256:run.driverSha256,engineLogSha256:run.engineLogSha256,totalRows:rows.length,settledFrames:settled.length*120,settledStartFrame:settled[0].frame-119,settledEndFrame:settled.at(-1).frame,scope:'Inclusive wall microseconds per render frame; nested spans are not additive.',phases:{}};
for(const name of phases){const values=settled.map(r=>r[name+'_us']/r.frames).sort((a,b)=>a-b);const calls=settled.reduce((s,r)=>s+r[name+'_calls'],0);result.phases[name]={meanUsPerFrame:Number((values.reduce((s,v)=>s+v,0)/values.length).toFixed(3)),medianUsPerFrame:Number(values[4].toFixed(3)),minUsPerFrame:Number(values[0].toFixed(3)),maxUsPerFrame:Number(values.at(-1).toFixed(3)),calls,callsPerFrame:Number((calls/result.settledFrames).toFixed(3))};}
const file=path.join(stage,'summary.json');assert(!fs.existsSync(file));fs.writeFileSync(file,JSON.stringify(result,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({file,sha256:sha(file),result}));
