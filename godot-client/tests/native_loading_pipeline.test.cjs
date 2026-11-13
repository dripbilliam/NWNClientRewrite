const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const {resolveNativeLoadingPipeline:resolve}=require('../tools/native-loading-pipeline.cjs');
const streamed=['--base-scenery-owner=retained','--base-scenery-templates=retained','--base-scenery-template-probe=ready','--base-scenery-admission=timed','--base-scenery-stream=continuous','--model-template=recipe'];

test('ordinary/default changes no native arguments or unrelated profile options',()=>{
 const result=resolve(['--render-profile=gameplay','--native-lighting=enhanced','--server=not-opened.invalid']);
 assert.deepEqual(result.arguments,[]);assert.equal(result.summary.pipeline,'ordinary');assert.equal(result.summary.selection,'default');
 assert.equal(result.summary.shared_animation_preparation,false);assert.equal(result.summary.native_draw_cache,false);assert.equal(result.summary.native_cache_gib,25);
 assert.deepEqual(resolve(['--loading-pipeline=ordinary']).arguments,[]);
});
test('streamed forwards the complete reviewed six-flag family',()=>assert.deepEqual(resolve(['--loading-pipeline=streamed']).arguments,streamed));
test('merged adds terrain and BASE replacement without lighting/profile flags',()=>assert.deepEqual(resolve(['--loading-pipeline=merged']).arguments,[...streamed,'--static-scenery=merged','--base-scenery-draw=merged']));
test('shared animation and disk cache are independent of pipeline',()=>{
 assert.deepEqual(resolve(['--shared-animation-preparation=true']).arguments,['--shared-animation-preparation=true']);
 assert.deepEqual(resolve(['--shared-animation-preparation']).arguments,['--shared-animation-preparation=true']);
 assert.deepEqual(resolve(['--native-draw-cache=prepared']).arguments,['--native-draw-cache=prepared','--native-draw-cache-gib=25']);
 assert.deepEqual(resolve(['--native-draw-cache']).arguments,['--native-draw-cache=prepared','--native-draw-cache-gib=25']);
 assert.deepEqual(resolve(['--shared-animation-preparation=false','--native-draw-cache=off']).arguments,[]);
});
test('all options compose and retain exact lower/upper budget boundaries',()=>{
 for(const budget of [25,64,1024]){
  const result=resolve(['--loading-pipeline=merged','--native-draw-cache=prepared','--native-draw-cache-gib='+budget,'--shared-animation-preparation=true']);
  assert.deepEqual(result.arguments,[...streamed,'--static-scenery=merged','--base-scenery-draw=merged','--shared-animation-preparation=true','--native-draw-cache=prepared','--native-draw-cache-gib='+budget]);
  assert.equal(result.summary.native_cache_gib,budget);assert.equal(result.summary.native_cache_budget_explicit,true);
 }
});
for(const value of ['','0','24','1025','25.0','25.5','-25','+25','025','1e2','NaN','Infinity',' 25','25 ','9007199254740992'])test('invalid cache budget rejects: '+JSON.stringify(value),()=>assert.throws(()=>resolve(['--native-draw-cache=prepared','--native-draw-cache-gib='+value]),/budget/));
test('budget without enabled cache rejects before any launch side effect',()=>{
 assert.throws(()=>resolve(['--native-draw-cache-gib=25']),/requires/);
 assert.throws(()=>resolve(['--native-draw-cache=off','--native-draw-cache-gib=25']),/requires/);
 assert.throws(()=>resolve(['--native-draw-cache=prepared','--native-draw-cache-gib']),/budget/);
});
for(const [name,value] of [['loading-pipeline','bad'],['loading-pipeline','Streamed'],['loading-pipeline',''],['shared-animation-preparation','yes'],['shared-animation-preparation',''],['native-draw-cache','true'],['native-draw-cache','']])test('invalid selection rejects: '+name+'='+JSON.stringify(value),()=>assert.throws(()=>resolve(['--'+name+'='+value]),/Invalid/));
for(const name of ['loading-pipeline','shared-animation-preparation','native-draw-cache','native-draw-cache-gib'])test('repeated option rejects: '+name,()=>assert.throws(()=>resolve(['--'+name+'=ordinary','--'+name+'=ordinary']),/Repeated/));
test('returned data is detached across calls',()=>{
 const first=resolve(['--loading-pipeline=streamed']);first.arguments.length=0;first.summary.pipeline='changed';
 const second=resolve(['--loading-pipeline=streamed']);assert.deepEqual(second.arguments,streamed);assert.equal(second.summary.pipeline,'streamed');
});
test('malformed input rejects',()=>{assert.throws(()=>resolve(null),/strings/);assert.throws(()=>resolve([25]),/strings/);assert.throws(()=>resolve(['--loading-pipeline']),/Invalid/);});
test('normal host validates, reports and forwards options without importing rendering',()=>{
 const source=fs.readFileSync(path.join(__dirname,'../tools/native-session-host.cjs'),'utf8');
 assert.ok(source.includes("const loadingPipeline=require('./native-loading-pipeline.cjs').resolveNativeLoadingPipeline(process.argv.slice(2));"));
 assert.ok(source.includes('report.loadingPipeline=loadingPipeline.summary;'));assert.ok(source.includes('nativeArgs.push(...loadingPipeline.arguments);'));
 assert.ok(source.indexOf('resolveNativeLoadingPipeline(process.argv.slice(2))')<source.indexOf('const report='));
 const helper=fs.readFileSync(path.join(__dirname,'../tools/native-loading-pipeline.cjs'),'utf8');assert.doesNotMatch(helper,/require\(|spawn\(|import\(/);
});
