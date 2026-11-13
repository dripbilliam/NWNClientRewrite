// Offline diagnostic partition checks. Never starts Godot or a server.
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {spawnSync} from 'node:child_process';
import assert from 'node:assert/strict';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const label='cold-summary-oracle-'+Date.now();
const folder=path.join(project,'.cache/native-140fps/particles-agent/checks',label);
fs.mkdirSync(folder,{recursive:true});
const emitters=[
 {id:1,native:true,origin_resource:'same',source_flags:1,active:0,chunk:true,birth_rate:0,life_exp:0,clock_valid:false,last_step_prepared:true,last_step_culled:false,clip_count:0,selected_channel_count:0,selected_constant_count:0,source_has_tile_index:false,source_parent_tile_index:0},
 {id:2,native:true,origin_resource:'same',source_flags:2,active:0,chunk:true,clock_valid:true,last_step_prepared:true,last_step_culled:true,selected_channel_count:3,selected_constant_count:3,source_has_tile_index:false,source_parent_tile_index:null},
 {id:3,native:true,origin_resource:'other',source_flags:null,active:2,chunk:false,clock_valid:false,last_step_prepared:true,last_step_culled:false,selected_channel_count:3,selected_constant_count:1,source_has_tile_index:true},
 {id:4,native:true,active:null,source_flags:-1,chunk:true,last_step_prepared:false,selected_channel_count:null,selected_constant_count:null},
 {id:5,native:false},
 {id:6,native:null}
];
const input=path.join(folder,'input.json');fs.writeFileSync(input,JSON.stringify({emitters}));
const run=spawnSync(process.execPath,[path.join(project,'tools/perf140/particles/summarize_cold.mjs'),input,label],{encoding:'utf8',windowsHide:true,timeout:15000});
fs.writeFileSync(path.join(folder,'stdout.log'),run.stdout??'');fs.writeFileSync(path.join(folder,'stderr.log'),run.stderr??'');
assert.equal(run.error,undefined);assert.equal(run.status,0,run.stderr);
const result=JSON.parse(fs.readFileSync(path.join(project,'.cache/native-140fps/particles-agent/cold-summaries',label+'.json')));
let checks=0;const equal=(actual,expected)=>{assert.deepEqual(actual,expected);++checks;};
for(const [field,value] of Object.entries({rows:6,native:4,fallback:1,unknownOwnership:1,empty:2,nonempty:1,unknownActive:1,lastCulled:1,lastAdmitted:2,unprepared:1,zeroBirth:1,zeroLife:1,chunk:3,emptyChunk:2,emptyChunkRadius1000:1,emptyChunkOtherKnownSource:1,emptyChunkUnknownSource:0,sourceRadius1000:1,unknownSourceFlags:2,actorClock:1,staticClock:2,unknownClock:1,noAssetClips:1,noSelectedChannels:1,constantOnlySelected:1,dynamicSelected:1,unknownSelectedChannels:1,tileSource:2,otherSource:1,unknownSourceOwnership:1}))equal(result.totals[field],value);
equal(result.groups.length,4);equal(result.origins.find(row=>row.origin==='same').rows,2);
equal(result.groups.filter(row=>row.origin==='same').map(row=>row.sourceFlags).sort(),[1,2]);
equal(result.groups.find(row=>row.origin===null).selectedChannels,null);
equal(result.origins.reduce((sum,row)=>sum+row.rows,0),4);
const receipt={success:true,checks,label,input,report:path.join(project,'.cache/native-140fps/particles-agent/cold-summaries',label+'.json'),scope:'Synthetic offline summary correctness only; no engine, server, GPU, FPS or world ownership claim.'};
fs.writeFileSync(path.join(folder,'checks.json'),JSON.stringify(receipt,null,2)+'\n');
console.log(JSON.stringify(receipt));
