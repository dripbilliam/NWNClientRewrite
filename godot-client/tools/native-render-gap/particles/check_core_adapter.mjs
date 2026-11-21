import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
import {fileURLToPath} from 'node:url';
const require=createRequire(import.meta.url),root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const adapter=require(path.join(root,'replay-adapter-v17.cjs'));
const pacing={enabled:true,main:[[]],render:[[]],cpu_windows:[[]],main_thread_policy:{available:true,thread_id:3352,expected_creation_100ns_exact:'134070000000000001'}};
function make(frames=501){const samples=Math.ceil(frames/120);return {enabled:true,stride:120,capacity:256,clocks_per_frame:0,frame_calls:frames,samples,dropped_distinct_cores:0,process_id:17032,frame_thread_id:3352,report_thread_id:3352,process_creation_100ns_exact:'134070000000000000',report_thread_creation_100ns_exact:'134070000000000001',topology:{error:0,rows:[{group:0,logical_processor_index:8,core_index:8,efficiency_class:1},{group:0,logical_processor_index:16,core_index:16,efficiency_class:0}]},histogram:[{group:0,number:8,count:samples}],records:Array.from({length:Math.min(samples,256)},(_,i)=>({frame:1+120*(Math.max(0,samples-256)+i),group:0,number:8}))};}
let checks=0;function check(value,message){checks++;assert.ok(value,message);}
check(adapter.coreSurveyUse(make(),pacing),'Current snapshot passes');
check(adapter.coreSurveyUse(make(40000),pacing),'Wrapped fixed ring passes with complete histogram');
const cases=[
 ['disabled',x=>x.enabled=false],['empty calls',x=>x.frame_calls=0],['sample count',x=>x.samples++],['stride',x=>x.stride=119],['capacity',x=>x.capacity=255],['overflow',x=>x.dropped_distinct_cores=1],['clock',x=>x.clocks_per_frame=1],['wrong report thread',x=>x.report_thread_id++],['wrong actual thread',x=>{x.frame_thread_id++;x.report_thread_id++;}],['missing creation',x=>delete x.process_creation_100ns_exact],['rounded creation',x=>x.report_thread_creation_100ns_exact=134070000000000001],['different creation',x=>x.report_thread_creation_100ns_exact='134070000000000002'],['topology error',x=>x.topology.error=5],['one efficiency class',x=>x.topology.rows[1].efficiency_class=1],['duplicate CPU',x=>x.topology.rows.push({...x.topology.rows[0]})],['unknown CPU',x=>x.histogram[0].number=99],['wrong histogram total',x=>x.histogram[0].count--],['duplicate histogram',x=>x.histogram.push({...x.histogram[0]})],['missing ring row',x=>x.records.pop()],['wrong ring phase',x=>x.records[0].frame++],['unknown record CPU',x=>x.records[0].number=99],['noninteger topology',x=>x.topology.rows[0].efficiency_class=0.5],['unsafe count',x=>x.frame_calls=Number.MAX_SAFE_INTEGER+1],['invalid process',x=>x.process_id=0],['zero FILETIME',x=>x.process_creation_100ns_exact='0'],['signed FILETIME overflow',x=>x.process_creation_100ns_exact='9223372036854775808']
];
for(const [name,change] of cases){const x=make();change(x);check(adapter.coreSurveyUse(x,pacing)===false,'Reject '+name);}
const selected={renderGap:{variant:'engine-control',extraFlags:['--particle-core-survey','--frame-pacing-metrics=on']},performanceOptions:{renderCore:{enabled:false}}};
let result=adapter.verifyNative(selected,{render_gap:{core_survey:make(),pacing}});check(result.status==='observed'&&result.features.coreSurvey===true&&result.features.pacing===true,'Full feature gate observes both independent sources');
result=adapter.verifyNative(selected,{render_gap:{core_survey:make(),pacing:{...pacing,main_thread_policy:{...pacing.main_thread_policy,thread_id:999}}}});check(result.status==='rejected'&&result.features.coreSurvey===false,'Full feature gate rejects different actual frame TID');
result=adapter.verifyNative({...selected,renderGap:{...selected.renderGap,extraFlags:[]}},{render_gap:{}});check(result.status==='observed'&&!Object.hasOwn(result.features,'coreSurvey'),'Unrequested diagnostic does not add a gate');
const source=fs.readFileSync(path.join(root,'replay-adapter-v16.cjs'));
const sourceSha=crypto.createHash('sha256').update(source).digest('hex');check(sourceSha==='dd65758b4db157ca705d53e0e6e8e1f3f6973ffb85fedf4d395b363406bf283b','Frozen V16 is unchanged');
console.log(JSON.stringify({success:true,checks,sourceV16Sha256:sourceSha,adapterV17Sha256:crypto.createHash('sha256').update(fs.readFileSync(path.join(root,'replay-adapter-v17.cjs'))).digest('hex'),scope:'Synthetic private adapter validation only; actual process/frame/FILETIME/topology proof requires the separately scheduled diagnostic.'}));
