'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),{pathToFileURL}=require('node:url'),{spawnSync}=require('node:child_process');
const project=path.resolve(__dirname,'../..'),label=process.argv[2];if(!/^[a-z0-9-]+$/.test(label??''))throw Error('Explicit experiment label required');
const root=path.join(project,'.cache/native-presentation-parity/root/fps-max-v1','particle-loop-'+label),hash=b=>crypto.createHash('sha256').update(b).digest('hex');
const sourceProof=path.join(root,'source-proof.json'),source=JSON.parse(fs.readFileSync(sourceProof));
for(const variant of ['control','candidate']){
 const folder=path.join(root,variant),m=JSON.parse(fs.readFileSync(path.join(folder,'test-manifest.json'))),base=JSON.parse(fs.readFileSync(m.base.file));
 const focused=JSON.parse(fs.readFileSync(path.join(folder,'focused-a/summary.json')));if(!focused.success||focused.checks!==50176)throw Error('Focused correctness missing');
 const prefs=path.join(folder,'preference-seeds');fs.mkdirSync(prefs);for(const name of ['render','layout'])fs.copyFileSync(path.join(path.dirname(m.base.file),base.preferences[name].relative),path.join(prefs,name+'.cfg'),fs.constants.COPYFILE_EXCL);
 const selection={...base,kind:'private-particle-loop-selection',production:false,experimental:true,sourceProject:m.project,mainSourceIdentity:require('../native-feature-manifest.cjs').sourceIdentity(m.project),pins:m.pins,particleLoop:{variant,base:m.base,source:{file:sourceProof,sha256:hash(fs.readFileSync(sourceProof))},build:m.build,module:{file:path.join(m.project,'.cache/native-kernel/nwn-particle-kernel.dll'),sha256:m.build.binarySha256}}};
 const file=path.join(folder,'private-selection.json');fs.writeFileSync(file,JSON.stringify(selection,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({variant,file,sha256:hash(fs.readFileSync(file)),mainUnchanged:require('../native-feature-manifest.cjs').sourceIdentity(project).sha256===source.mainSource}));
}
const base=path.join(project,'tools/replay-native-loading.mjs');let code=fs.readFileSync(base,'utf8');
const replace=(before,after)=>{if(code.split(before).length!==2)throw Error('Driver seam differs: '+before.slice(0,90));code=code.replace(before,after);};
code=code.replace(/from '(\.\/[^']+)'/g,(_,name)=>'from '+JSON.stringify(pathToFileURL(path.resolve(path.dirname(base),name)).href));
replace('createRequire(import.meta.url)','createRequire('+JSON.stringify(pathToFileURL(base).href)+')');
replace("const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');",'const project='+JSON.stringify(project)+';');
replace("const productionSelection=await readReplayProductionSelection(arg('production-selection'),arg('production-selection-sha256'),project);",'const particleAdapter=require('+JSON.stringify(path.join(__dirname,'replay-adapter.cjs'))+");\nconst productionSelection=await particleAdapter.readSelection(arg('production-selection'),arg('production-selection-sha256'));");
replace("await readReplayProductionSelection(arg('production-selection'),arg('production-selection-sha256'),project)","await particleAdapter.readSelection(arg('production-selection'),arg('production-selection-sha256'))");
replace('Object.assign(runtimeFiles,sceneEngineFiles);','Object.assign(runtimeFiles,sceneEngineFiles,particleAdapter.runtimeFiles(productionSelection));');
replace(" await fs.writeFile(reportPath,JSON.stringify(report,null,2)+'\\n',{flag:'wx'});"," report.particleVerification=particleAdapter.verifyNative(productionSelection,report.native);\n if(report.particleVerification.status!=='observed'){report.success=false;report.failure??='Private particle actual-use verification rejected';}\n await fs.writeFile(reportPath,JSON.stringify(report,null,2)+'\\n',{flag:'wx'});");
if(code.includes('await readReplayProductionSelection('))throw Error('Private reader missing at final provenance boundary');
const driver=path.join(root,'private-driver.mjs');fs.writeFileSync(driver,code,{flag:'wx'});const parsed=spawnSync(process.execPath,['--check',driver],{windowsHide:true,encoding:'utf8'});if(parsed.status!==0)throw Error(parsed.stderr);
fs.writeFileSync(path.join(root,'driver-proof.json'),JSON.stringify({base:{file:base,sha256:hash(fs.readFileSync(base))},driver:{file:driver,sha256:hash(Buffer.from(code))},scope:'Private pinned generated replay with all normal source/runtime/camera/movement/display/preferences/cleanup gates; no production driver edits'},null,2)+'\n',{flag:'wx'});
