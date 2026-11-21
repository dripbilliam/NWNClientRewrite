'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),{pathToFileURL}=require('node:url');
const project=path.resolve(__dirname,'../..'),[label,version,batch]=process.argv.slice(2);
if(!/^[a-z0-9-]+$/.test(label??'')||!/^v[0-9]+$/.test(version??'')||!/^[a-z0-9-]+$/.test(batch??''))throw Error('Review, prototype version and fresh graphical batch required');
const sha=b=>crypto.createHash('sha256').update(b).digest('hex'),helper=require('../native-production-selection.cjs'),identity=require('../native-feature-manifest.cjs').sourceIdentity;
const experiment=path.join(project,'.cache/native-presentation-parity/root/fps-max-v1','movement-native-review-'+label,'sparse-pending-'+version),proofFile=path.join(experiment,'proof.json'),proof=JSON.parse(fs.readFileSync(proofFile));
const focusedFile=path.join(experiment,'check-a/summary.json'),focused=JSON.parse(fs.readFileSync(focusedFile));
if(!focused.success||focused.checks<129||identity(project).sha256!==proof.mainAfter)throw Error('Current source or focused correctness gate missing');
for(const pin of proof.pins)if(sha(fs.readFileSync(path.join(experiment,pin.variant,pin.relative)))!==pin.sha256)throw Error('Private prototype drift');
const root=path.join(experiment,'graphics-'+batch);if(fs.existsSync(root))throw Error('Existing graphical batch preserved');fs.mkdirSync(root);
async function main(){
 const priorFile=path.join(project,'.cache/native-presentation-parity/production-replay/fps-max-v1-ordinary-workers-b/production-selection.json'),prior=JSON.parse(fs.readFileSync(priorFile));
 const seeds={version:1,expected:prior.preferences.expected,description:prior.preferences.description};
 for(const name of ['render','layout'])seeds[name]={file:path.join(path.dirname(priorFile),prior.preferences[name].relative),sha256:prior.preferences[name].sha256};
 const staged=await helper.stageProductionSelection({project,label:'fps-movement-'+label+'-'+version+'-'+batch+'-current',argv:prior.options.map(a=>a==='--world-snapshot-preparation=workers'?'--world-snapshot-preparation=script':a),preferenceSeeds:seeds});
 if(staged.selection.mainSourceIdentity.sha256!==proof.mainAfter)throw Error('Frozen current client differs');
 for(const variant of ['control','candidate']){
  const folder=path.join(root,variant),destination=path.join(folder,'project');fs.mkdirSync(destination,{recursive:true});
  const files=new Map(staged.selection.pins.map(p=>[p.relative,path.join(staged.selection.sourceProject,p.relative)]));
  if(variant==='candidate')for(const pin of proof.pins.filter(p=>p.variant==='candidate'))files.set(pin.relative,path.join(experiment,variant,pin.relative));
  const pins=[];for(const [relative,source]of files){const bytes=fs.readFileSync(source),dest=path.join(destination,relative);fs.mkdirSync(path.dirname(dest),{recursive:true});fs.writeFileSync(dest,bytes,{flag:'wx'});pins.push({relative,sha256:sha(bytes)});}
  fs.mkdirSync(path.join(folder,'preference-seeds'));for(const name of ['render','layout'])fs.copyFileSync(path.join(path.dirname(staged.file),staged.selection.preferences[name].relative),path.join(folder,'preference-seeds',name+'.cfg'),fs.constants.COPYFILE_EXCL);
  const selection={...staged.selection,kind:'private-movement-review-selection',production:false,experimental:true,sourceProject:destination,mainSourceIdentity:identity(destination),pins,movementReview:{variant,base:{file:staged.file,sha256:staged.sha256},source:{file:proofFile,sha256:sha(fs.readFileSync(proofFile))},focused:{file:focusedFile,sha256:sha(fs.readFileSync(focusedFile))},changes:variant==='control'?'Byte-exact current application':'Pure installed/inflight/failure filter reorder, common child timers, unresolved-ID planning subclass'},particleLoop:{module:{file:path.join(destination,'.cache/native-kernel/nwn-particle-kernel.dll'),sha256:sha(fs.readFileSync(path.join(destination,'.cache/native-kernel/nwn-particle-kernel.dll')))}}};
  helper.validatePins(selection);helper.validatePreferencePins(selection);
  fs.writeFileSync(path.join(folder,'private-selection.json'),JSON.stringify(selection,null,2)+'\n',{flag:'wx'});
 }
 const driverBase=path.join(project,'tools/replay-native-loading.mjs');let code=fs.readFileSync(driverBase,'utf8');
 const replace=(from,to)=>{if(code.split(from).length!==2)throw Error('Replay seam differs: '+from.slice(0,75));code=code.replace(from,to);};
 code=code.replace(/from '(\.\/[^']+)'/g,(_,name)=>'from '+JSON.stringify(pathToFileURL(path.resolve(path.dirname(driverBase),name)).href));
 replace('createRequire(import.meta.url)','createRequire('+JSON.stringify(pathToFileURL(driverBase).href)+')');
 replace("const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');",'const project='+JSON.stringify(project)+';');
 replace("const productionSelection=await readReplayProductionSelection(arg('production-selection'),arg('production-selection-sha256'),project);",'const movementAdapter=require('+JSON.stringify(path.join(__dirname,'replay-adapter.cjs'))+");\nconst productionSelection=await movementAdapter.readSelection(arg('production-selection'),arg('production-selection-sha256'));");
 replace("await readReplayProductionSelection(arg('production-selection'),arg('production-selection-sha256'),project)","await movementAdapter.readSelection(arg('production-selection'),arg('production-selection-sha256'))");
 replace('Object.assign(runtimeFiles,sceneEngineFiles);','Object.assign(runtimeFiles,sceneEngineFiles,movementAdapter.runtimeFiles(productionSelection));');
 replace(" await fs.writeFile(reportPath,JSON.stringify(report,null,2)+'\\n',{flag:'wx'});"," report.movementReviewVerification=movementAdapter.verifyNative(productionSelection,report.native);\n if(report.movementReviewVerification.status!=='observed'){report.success=false;report.failure??='Private movement actual-use verification rejected';}\n await fs.writeFile(reportPath,JSON.stringify(report,null,2)+'\\n',{flag:'wx'});");
 if(code.includes('await readReplayProductionSelection('))throw Error('Private reader missing at final boundary');
 const driver=path.join(root,'private-driver.mjs');fs.writeFileSync(driver,code,{flag:'wx'});
 const result={base:{file:driverBase,sha256:sha(fs.readFileSync(driverBase))},driver:{file:driver,sha256:sha(Buffer.from(code))},mainBefore:proof.mainAfter,mainAfter:identity(project).sha256,sourceProof:{file:proofFile,sha256:sha(fs.readFileSync(proofFile))},baseSelection:{file:staged.file,sha256:staged.sha256},scope:'Exact current control versus private combined planner candidate. Same ordinary loading/script metadata, profile off, gameplay preferences, route, camera, motion/display and cleanup gates. No main install.'};
 if(result.mainBefore!==result.mainAfter)throw Error('Main client changed');fs.writeFileSync(path.join(root,'driver-proof.json'),JSON.stringify(result,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({root,mainUnchanged:true,control:identity(path.join(root,'control/project')).sha256,candidate:identity(path.join(root,'candidate/project')).sha256}));
}
main().catch(e=>{console.error(e.stack);process.exitCode=1;});
