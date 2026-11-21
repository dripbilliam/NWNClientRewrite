'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../..'),stage=path.join(root,'.cache/nwn74/inner-phase-clock-b');
const sha=file=>crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const run=JSON.parse(fs.readFileSync(path.join(stage,'run-receipt.json')));
assert(run.success&&run.fpsFileAbsent&&run.acceptedSourceUnchanged&&run.acceptedBinaryUnchanged);
const log=path.join(root,'reports/nwn74-inner-phase-clock-b.engine.log');assert.equal(sha(log),run.engineLogSha256);
const rows=fs.readFileSync(log,'utf8').split(/\r?\n/).filter(s=>s.startsWith('NWN74_INNER ')).map(line=>Object.fromEntries([...line.matchAll(/([a-z_]+)=([0-9]+)/g)].map(m=>[m[1],Number(m[2])])));
assert.equal(rows.length,run.phaseRows);
const settled=rows.filter(r=>r.frame>=2854&&r.frames===120&&r.scene_calls===120&&r.submitted_draws>=366475&&r.submitted_draws<=366480);
assert.equal(settled.length,7);
const phases=['scene','render_list_template','draw_list_wrapper','input_mask','vertex_array','pipeline','binding','push','draw'];
const result={issue:'NWN-74',private:true,diagnosticOnly:true,engineSha256:run.engineSha256,engineLogSha256:run.engineLogSha256,settledFrames:settled.length*120,settledRows:settled.length,drawsPerFrame:3054,sampleRule:'element index & 7 == 0',scope:'Nested wall durations; sampled per-draw timings include timestamp overhead and cannot be scaled to a whole-frame saving.',phases:{}};
for(const name of phases){const totalUs=settled.reduce((s,r)=>s+r[name+'_us'],0),calls=settled.reduce((s,r)=>s+r[name+'_calls'],0);result.phases[name]={totalUs,calls,meanUsPerFrame:Number((totalUs/result.settledFrames).toFixed(3)),meanUsPerCall:Number((totalUs/calls).toFixed(4))};}
const file=path.join(stage,'summary.json');assert(!fs.existsSync(file));fs.writeFileSync(file,JSON.stringify(result,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({file,sha256:sha(file),result}));
