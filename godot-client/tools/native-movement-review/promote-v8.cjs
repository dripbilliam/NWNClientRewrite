'use strict';
// Promote only the exact reviewed v8 bytes after independent visual review.
// Every changed existing file is backed up; no default flags or DLLs change.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const project=path.resolve(__dirname,'../..'),root=path.join(project,'.cache/native-presentation-parity/root/fps-max-v1/movement-native-review-a'),current=path.join(root,'sparse-pending-v8');
const sha=b=>crypto.createHash('sha256').update(b).digest('hex'),read=f=>JSON.parse(fs.readFileSync(f)),pin=f=>({file:f,sha256:sha(fs.readFileSync(f))}),identity=require('../native-feature-manifest.cjs').sourceIdentity;
if(process.argv[2]!=='install-reviewed')throw Error('Explicit reviewed install action required');
const before=identity(project),proof=read(path.join(current,'proof.json'));
if(before.sha256!==proof.mainAfter)throw Error('Main source drifted; do not overwrite');
const selectionFile=path.join(current,'graphics-a/candidate/private-selection.json'),selection=read(selectionFile);
require('../native-production-selection.cjs').validatePins(selection);
const visualFile=path.join(current,'visual-review.json'),visual=read(visualFile);
if(visual.success!==true||visual.scope!=='Bounded manual inspection of saved final control/candidate views; expected flame variation allowed')throw Error('Bounded visual review required');
for(const row of visual.pins)if(sha(fs.readFileSync(row.file))!==row.sha256)throw Error('Reviewed image changed');
const finalRun=read(path.join(current,'graphics-a/fps-movement-a-v8-a-candidate-a.result.json'));
const controlFile=path.join(root,'sparse-pending-v7/graphics-a/fps-movement-a-v7-a-control-a.result.json'),control=read(controlFile);
if(!finalRun.success||!control.success||finalRun.actualUse.status!=='observed')throw Error('Final source/runtime/motion/cleanup acceptance missing');
const driver8=read(path.join(current,'graphics-a/driver-proof.json')),driver7=read(path.join(root,'sparse-pending-v7/graphics-a/driver-proof.json'));
if(driver8.driver.sha256!==driver7.driver.sha256||driver8.base.sha256!==driver7.base.sha256)throw Error('Cross-batch control does not use the identical driver');
const controlSelection=read(path.join(root,'sparse-pending-v7/graphics-a/control/private-selection.json'));
for(const field of ['options','runtime','engineArguments','renderThread','flags','environment','featureSelection','renderConfiguration','loadingPipeline','profiling','preferences','cameraPolicy'])if(JSON.stringify(controlSelection[field])!==JSON.stringify(selection[field]))throw Error('Final control configuration differs: '+field);
if(controlSelection.mainSourceIdentity.sha256!==before.sha256)throw Error('Control is not the exact installed baseline');
for(const field of ['entities','desired','nodes','draws','triangles','particleFailures'])if(control.world[field]!==finalRun.world[field])throw Error('Final scene population differs: '+field);
const fps=(r,phase)=>r.sampledFps.find(p=>p.phase===phase)?.median;
if(!(fps(finalRun,'recorded-input-section')>fps(control,'recorded-input-section')))throw Error('Final candidate did not improve sampled movement-section FPS');
const checks=[
 ['sparse-pending-v7','check-native-world-quiescent-test'],['sparse-pending-v7','check-native-world-delta-test'],['sparse-pending-v7','check-native-world-snapshot-sidecar-test'],['sparse-pending-v7','check-candidate-name-signature-fixed'],
 ['sparse-pending-v8','check-a'],['sparse-pending-v8','check-publication'],['sparse-pending-v8','check-retirement'],['sparse-pending-v8','check-palette-cpu'],['sparse-pending-v8','check-palette-gpu']
].map(([version,name])=>path.join(root,version,name,'summary.json'));
for(const file of checks){const r=read(file);if(!r.success||r.mainBefore!==before.sha256||r.mainAfter!==before.sha256)throw Error('Focused gate failed: '+file);}
const v7=read(path.join(root,'sparse-pending-v7/proof.json'));
for(const p of v7.pins.filter(p=>p.variant==='candidate')){
 const p8=proof.pins.find(q=>q.variant==='candidate'&&q.relative===p.relative);if(!p8||p8.sha256!==p.sha256)throw Error('Planner source differs from lifecycle test cohort: '+p.relative);
}
const negativeFile=path.join(current,'check-palette-old-gpu/summary.json'),negative=read(negativeFile),negativeReport=read(path.join(current,'check-palette-old-gpu/report.json'));
if(negative.success||negative.errors.length||negative.exit.code!==1||!negativeReport.failures.some(f=>f.includes('exact published RGBAF bytes')))throw Error('Negative GPU control did not detect the original upload bug');
const positiveManifest=read(path.join(current,'check-palette-gpu/manifest.json')),negativeManifest=read(path.join(current,'check-palette-old-gpu/manifest.json'));
const differences=positiveManifest.pins.filter(p=>negativeManifest.pins.find(q=>q.relative===p.relative)?.sha256!==p.sha256).map(p=>p.relative);
if(JSON.stringify(differences)!==JSON.stringify(['systems/native_render/native_light_palette.gd']))throw Error('GPU negative control changes more than the palette');
const files=['native_live_world.gd','systems/native_render/live_world.gd','systems/native_render/live_world_pending_appearances.gd','systems/native_render/native_light_palette.gd'];
const promotion=path.join(current,'promotion');if(fs.existsSync(promotion))throw Error('Previous promotion preserved');
const changes=files.map(relative=>{
 const target=path.join(project,relative),source=path.join(selection.sourceProject,relative),sourceSha256=sha(fs.readFileSync(source)),existing=fs.existsSync(target);
 if(existing){const guard=proof.guarded.find(p=>p.relative===relative);if(!guard||sha(fs.readFileSync(target))!==guard.sha256)throw Error('Current file differs: '+relative);}
 else if(relative!=='systems/native_render/live_world_pending_appearances.gd')throw Error('Unexpected missing main file');
 return {relative,target,source,sourceSha256,existed:existing,beforeSha256:existing?sha(fs.readFileSync(target)):null};
});
const acceptance={version:1,success:true,sourceBefore:before.sha256,sourceCandidate:selection.mainSourceIdentity.sha256,final:pin(path.join(current,'graphics-a/fps-movement-a-v8-a-candidate-a.result.json')),control:pin(controlFile),focused:checks.map(pin),negative:pin(negativeFile),visual:pin(visualFile),sourceProof:pin(path.join(current,'proof.json')),changes,movementSampledFps:{control:fps(control,'recorded-input-section'),candidate:fps(finalRun,'recorded-input-section')},quietSampledFps:{control:fps(control,'post-input-quiet'),candidate:fps(finalRun,'post-input-quiet')},limits:['Final comparison uses an earlier exact-current control with byte-identical driver/configuration; baseline input medians varied68-77 across runs.','Earlier v5 ABBA supports the planner result; v8 additionally includes the independently tested palette ownership fix.','Sampled rolling FPS is not a per-frame trajectory comparison or an Arelith guarantee. Final steady quiet intervals show no claimed material gain.','One v7 run failed with an empty64512-byte texture update; it is retained and excluded. Original palette independently fails deterministic GPU pixel ownership; fixed palette passes.','Supported receive/removal/explicit invalidation boundaries own pending metadata. Raw same-size dictionary mutation without those boundaries remains unsupported, as with settled planning.'],scope:'Reviewed reversible normal-client source integration only. No runtime/default/quality/library or public-server automation changes; broader FPS goal remains active.'};
fs.mkdirSync(path.join(promotion,'before'),{recursive:true});
for(const c of changes)if(c.existed){const dest=path.join(promotion,'before',c.relative);fs.mkdirSync(path.dirname(dest),{recursive:true});fs.copyFileSync(c.target,dest,fs.constants.COPYFILE_EXCL);}
fs.writeFileSync(path.join(promotion,'acceptance.json'),JSON.stringify(acceptance,null,2)+'\n',{flag:'wx'});
for(const c of changes){fs.mkdirSync(path.dirname(c.target),{recursive:true});fs.writeFileSync(c.target,fs.readFileSync(c.source),{flag:c.existed?'w':'wx'});if(sha(fs.readFileSync(c.target))!==c.sourceSha256)throw Error('Installed bytes differ');}
const after=identity(project);
if(after.sha256!==selection.mainSourceIdentity.sha256)throw Error('Installed application does not match final graphical candidate');
const result={success:true,sourceBefore:before.sha256,sourceAfter:after.sha256,files:changes.map(c=>({relative:c.relative,before:c.beforeSha256,after:c.sourceSha256})),acceptance:pin(path.join(promotion,'acceptance.json')),dllChanges:0,flagChanges:0,scope:acceptance.scope};
fs.writeFileSync(path.join(promotion,'installed.json'),JSON.stringify(result,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify(result));
