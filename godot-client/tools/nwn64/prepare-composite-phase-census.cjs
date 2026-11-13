'use strict';
// ONE PRIVATE source-only diagnostic view. Accepted runtime is unchanged.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../..');
const directory=path.join(root,'.cache/nwn64/phase-census-combined-a');
const baseline=path.join(root,'.cache/native-live-review/reviewed-arelith-b/project');
const manifestFile=path.join(baseline,'../manifest.json');
const sha=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
const read=file=>fs.readFileSync(file);
const pin=file=>({file,bytes:fs.statSync(file).size,sha256:sha(read(file))});
const acceptedEngine='753b3e188068efaf865bda3abd6322ebe44e3a98ef2f5d199c8af1a78624c98b';
const acceptedNative='485741af15f0581a3c60c0f9a8ae738888eba08716c7a5c2c2d1bd550828963d';
const rigHelper='tools/nwn65/final_native_run_census.gd';
const rigHelperSHA='13173bca435f170a72abd46325bb56c36d9764fbeeda84f6cb8cf8bc51f4c3bb';
const rigFixture='tools/nwn65/census_preflight.gd';
const rigFixtureSHA='0539b154a63560416a2811d710af86de72d85bd29127f7398e037ba90ff427ec';
const phase=require('./phase_review_overlay.cjs');
function safeTarget(base,relative){
 assert(relative&&!path.isAbsolute(relative)&&!relative.split(/[\\/]/).some(p=>!p||p==='.'||p==='..'));
 const file=path.resolve(base,relative),rel=path.relative(base,file);assert(!rel.startsWith('..')&&!path.isAbsolute(rel));return file;
}
function originalRows(){
 const manifest=JSON.parse(read(manifestFile)),excluded=[],rows=[];
 for(const row of manifest.files){
  const relative=path.relative(baseline,row.file).replaceAll('\\','/');
  if(relative.startsWith('../')||path.isAbsolute(relative)){excluded.push({file:row.file,relative,reason:'outside reviewed project; never copied'});continue;}
  assert.equal(safeTarget(baseline,relative),path.resolve(row.file));assert.equal(sha(read(row.file)),row.sha256,'Reviewed source changed '+relative);
  rows.push({...row,relative});
 }
 // The prior2294-input copies comprise2293 manifest project files plus the
 // current production helper. The manifest also pins four sibling launchers.
 assert.equal(rows.length,2293);
 assert.deepEqual(excluded.map(row=>row.relative).sort(),['../launcher/bootstrap-preload.cjs','../launcher/host-preload.cjs','../launcher/host.cjs','../launcher/native-window-screen.ps1'].sort());
 return{rows,excluded};
}
function worldOverlay(bytes){
 const needle='\tif is_instance_valid(world): report.world=world.snapshot()';const text=bytes.toString();assert.equal(text.split(needle).length,2,'Unique final-report seam required');
 return Buffer.from(text.replace(needle,'\tif is_instance_valid(world):\n\t\treport.world=world.snapshot()\n\t\treport.private_particle_phase_review=preload("res://tools/nwn64/phase_review_census.gd").collect(world)\n\t\treport.private_native_rig_census=preload("res://tools/nwn65/final_native_run_census.gd").collect(world)'));
}
function verify(prepared){
 for(const row of prepared.pins)assert.equal(sha(read(safeTarget(prepared.inputProject,row.relative))),row.sha256,'Composite source changed '+row.relative);
 assert.equal(sha(read(prepared.preferenceFile)),prepared.preferenceSHA256);
 assert.equal(sha(read(prepared.capture.timeline.file)),prepared.capture.timeline.sha256);assert.equal(sha(read(prepared.capture.provenance.file)),prepared.capture.provenance.sha256);
 return true;
}
function prepare(){
 assert(!fs.existsSync(directory),'Fresh composite label required');
 const {rows,excluded}=originalRows();
 assert.equal(sha(read(path.join(root,rigHelper))),rigHelperSHA);assert.equal(sha(read(path.join(root,rigFixture))),rigFixtureSHA);
 const originals=new Map(rows.map(row=>[row.relative,row]));
 assert.equal(originals.get('.tools/native-core/Godot_native_core_e_win64.exe').sha256,acceptedEngine);
 assert.equal(originals.get('.cache/native-kernel/nwn-particle-kernel.dll').sha256,acceptedNative);
 const overlays=new Map([
  ['systems/native_render/particle_stream_group.gd',phase.groupOverlay(read(originals.get('systems/native_render/particle_stream_group.gd').file))],
  ['native_live_world.gd',worldOverlay(read(originals.get('native_live_world.gd').file))]
 ]);
 const helpers=[phase.proposal().helper.relative,'tools/nwn64/phase_review_preflight.gd',rigHelper,rigFixture];
 for(const relative of helpers){assert(!originals.has(relative));overlays.set(relative,read(path.join(root,relative)));}
 const infrastructure='tools/native-production-selection.cjs';assert(!originals.has(infrastructure));overlays.set(infrastructure,read(path.join(root,infrastructure)));
 const inputProject=path.join(directory,'input-project'),pins=[];fs.mkdirSync(inputProject,{recursive:true});
 for(const row of rows){
  const file=safeTarget(inputProject,row.relative);fs.mkdirSync(path.dirname(file),{recursive:true});
  if(overlays.has(row.relative))fs.writeFileSync(file,overlays.get(row.relative),{flag:'wx'});
  else if(/\.(exe|dll)$/.test(row.relative))fs.linkSync(row.file,file);
  else fs.writeFileSync(file,read(row.file),{flag:'wx'});
  pins.push({relative:row.relative,...pin(file)});
 }
 for(const[relative,bytes]of overlays){if(originals.has(relative))continue;const file=safeTarget(inputProject,relative);fs.mkdirSync(path.dirname(file),{recursive:true});fs.writeFileSync(file,bytes,{flag:'wx'});pins.push({relative,...pin(file)});}
 const preferences={version:1,description:'ReviewedB normal render/layout; diagnostic source only; original particles enabled derivative',expected:{gamma:1.2,particles:true,fovDegrees:45,compactScenery:true}};
 for(const[key,name]of[['render','native-render-preferences.cfg'],['layout','native-menu-layout.cfg']]){const file=path.join(directory,'preference-seeds',key+'.cfg'),bytes=read(path.join(baseline,'../working-settings',name));fs.mkdirSync(path.dirname(file),{recursive:true});fs.writeFileSync(file,bytes,{flag:'wx'});preferences[key]={file,sha256:sha(bytes)};}
 const preferenceFile=path.join(directory,'preference-seeds.json');fs.writeFileSync(preferenceFile,JSON.stringify(preferences,null,2)+'\n',{flag:'wx'});
 const captureRoot=path.join(root,'.cache/nwn64/fog-recording-particles-a'),capture={directory:captureRoot,timeline:pin(path.join(captureRoot,'timeline.jsonl')),provenance:pin(path.join(captureRoot,'fog-provenance.json')),policy:'Existing original archive; only358 recorded view.particles values settrue; no asset/effect/model edits'};
 assert.equal(capture.timeline.sha256,'8e599c13ca1bcdcd22799e0364b20937a0ff0a02bca88eae635cb23aa5e7e334');assert.equal(capture.provenance.sha256,'682e177bcb8ae83223ea11f82849dca9aadc5c2358b57586b5246306902c2d8d');
 const result={version:1,private:true,sourceDiagnostic:true,runtimeAccepted:true,defaultPromotion:false,created:new Date().toISOString(),inputProject,manifest:pin(manifestFile),excluded,pins,overlays:[...overlays.keys()].filter(p=>originals.has(p)),addedHelpers:helpers,infrastructure:{relative:infrastructure,...pin(path.join(root,infrastructure))},preferenceFile,preferenceSHA256:sha(read(preferenceFile)),capture,argv:['--performance-runtime=verified-native','--render-profile=gameplay','--detailed-profiling=off'],generations:[2,3],sampler:{enabled:true,coarse_phases:true,stride:120,min_members:0},scope:'ONE immutable reviewedB source view with one sampler-config line and one final-report seam for64phase+65rig census; acceptedCoreE485/core16/environment unchanged; no native build/launch/wholeFPS claim.'};
 verify(result);const file=path.join(directory,'prepared.json');fs.writeFileSync(file,JSON.stringify(result,null,2)+'\n',{flag:'wx'});return{file,...pin(file)};
}
async function stage(){
 const preparedFile=path.join(directory,'prepared.json'),prepared=JSON.parse(read(preparedFile));verify(prepared);
 assert.equal(sha(read(path.join(root,prepared.infrastructure.relative))),prepared.infrastructure.sha256);
 const helper=require(path.join(root,prepared.infrastructure.relative));
 const staged=await helper.stageProductionSelection({project:prepared.inputProject,label:'phase-census-combined-a',argv:prepared.argv,preferenceSeeds:JSON.parse(read(prepared.preferenceFile)),env:{}});
 const s=staged.selection;assert.equal(s.profiling,'false');assert.equal(s.renderCore.engineSha256,acceptedEngine);assert.equal(s.renderCore.nativeKernelSha256,acceptedNative);
 assert.equal(s.renderCore.flags.length,16);assert(!s.flags.some(f=>/particle-clock-read|particle-coarse-timing|particle-sparse-timing/.test(f)));
 assert.deepEqual(s.environment,{NWN_PARTICLE_PRESENTATION:'shared',NWN_PARTICLE_LIGHTING:'pooled',NWN_PARTICLE_KERNEL:'compiled'});
 for(const relative of prepared.addedHelpers)assert(s.pins.some(row=>row.relative===relative),'Diagnostic helper omitted from staged source pins '+relative);
 verify(prepared);const result={privateDiagnosticSource:true,runtimeAccepted:true,defaultPromotion:false,prepared:preparedFile,preparedSHA256:sha(read(preparedFile)),selectionFile:staged.file,selectionSHA256:staged.sha256,sourceProject:s.sourceProject,engine:s.engine,renderCore:s.renderCore,environment:s.environment,profiling:s.profiling,preferences:s.preferences,capture:prepared.capture,generations:prepared.generations,noBuilds:true,noLaunches:true};
 const file=path.join(directory,'staged.json');assert(!fs.existsSync(file));fs.writeFileSync(file,JSON.stringify(result,null,2)+'\n',{flag:'wx'});return{file,...pin(file),...result};
}
module.exports={prepare,stage,verify,worldOverlay};
if(require.main===module){const operation=process.argv[2];Promise.resolve().then(()=>operation==='prepare'?prepare():operation==='stage'?stage():(()=>{throw Error('Use prepare|stage; never launches a client');})()).then(value=>process.stdout.write(JSON.stringify(value,null,2)+'\n')).catch(error=>{console.error(error.stack);process.exitCode=1;});}
