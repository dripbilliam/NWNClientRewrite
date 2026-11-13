'use strict';
// Source staging only; isolated final62 candidate at private shared3/4ms.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const project=path.resolve(__dirname,'../..'),label='entry62-shared4-pair-b',directory=path.join(project,'.cache/nwn62/entry-pairs',label);assert(!fs.existsSync(directory));
const sha=value=>crypto.createHash('sha256').update(value).digest('hex'),read=file=>fs.readFileSync(file),json=file=>JSON.parse(read(file));
const proposalFile=path.join(project,'.cache/nwn62/shared4-proposal-b/manifest.json'),proposal=json(proposalFile);assert.equal(sha(read(proposalFile)),'555a0d32e431d8cd1b0e3043616d727ec51bd1d9512923e783d0f4754a7006ec');
const parentFile=proposal.parent.file,parent=json(parentFile);assert.equal(sha(read(parentFile)),proposal.parent.sha256);
const pins=parent.pins.candidate,poolPath='systems/native_render/resource_pool.gd',helperPath='tools/nwn62/shared_budget_ledger_audit.gd';
for(const pin of pins)assert.equal(sha(read(path.join(parent.candidate,pin.file))),pin.sha256,pin.file);
for(const pin of proposal.files)assert.equal(sha(read(path.join(proposal.directory,pin.file))),pin.sha256,pin.file);
const commonPool=read(path.join(proposal.directory,'common',poolPath)).toString('utf8');
assert(commonPool.includes('if _completion_depth==0:elapsed=Time.get_ticks_usec()-began;publication_us+=elapsed'));
assert.equal(commonPool.split('if _completion_depth==0:elapsed=Time.get_ticks_usec()-began;publication_us+=elapsed').length-1,2,'Lazy clock guards for construction/publication must remain');
const control=path.join(directory,'control-input'),candidate=path.join(directory,'candidate-input'),views={control,candidate};
for(const pin of pins)for(const destination of Object.values(views)){
 const from=path.join(parent.candidate,pin.file),to=path.join(destination,pin.file);fs.mkdirSync(path.dirname(to),{recursive:true});
 if(/\.(exe|dll)$/.test(pin.file))fs.linkSync(from,to);else fs.writeFileSync(to,read(from),{flag:'wx'});
}
const testPath='tests/nwn62_shared_budget_test.gd',test=read(path.join(project,testPath));
const inputPins={};
for(const [leg,destination]of Object.entries(views)){
 const expected=new Map(pins.map(pin=>[pin.file,pin.sha256]));
 for(const relative of [poolPath,helperPath]){const bytes=read(path.join(proposal.directory,'common',relative)),to=path.join(destination,relative);fs.mkdirSync(path.dirname(to),{recursive:true});fs.writeFileSync(to,bytes);expected.set(relative,sha(bytes));}
 const settings=read(path.join(proposal.directory,leg,'project.godot'));fs.writeFileSync(path.join(destination,'project.godot'),settings);expected.set('project.godot',sha(settings));
 fs.writeFileSync(path.join(destination,testPath),test,{flag:'wx'});expected.set(testPath,sha(test));
 inputPins[leg]=[...expected].map(([file,sha256])=>({file,sha256}));for(const pin of inputPins[leg])assert.equal(sha(read(path.join(destination,pin.file))),pin.sha256,leg+'/'+pin.file);
}
const changes=inputPins.control.filter(pin=>pin.sha256!==inputPins.candidate.find(row=>row.file===pin.file)?.sha256).map(pin=>pin.file);assert.deepEqual(changes,['project.godot']);
const controlSettings=read(path.join(control,'project.godot')).toString('utf8'),candidateSettings=read(path.join(candidate,'project.godot')).toString('utf8');assert.equal(candidateSettings.replace('private/publication_shared_budget_us=4000','private/publication_shared_budget_us=0'),controlSettings);
const identity=destination=>require(path.join(destination,'tools/native-feature-manifest.cjs')).sourceIdentity(destination).sha256;
const manifest={version:1,ticket:'NWN-62',label,directory,control,candidate,parent:{file:parentFile,sha256:sha(read(parentFile)),leg:'candidate'},proposal:{file:proposalFile,sha256:sha(read(proposalFile))},pins:inputPins,betweenViewChanges:changes,settings:proposal.setting,commonPoolSHA256:sha(commonPool),commonHelperSHA256:sha(read(path.join(proposal.directory,'common',helperPath))),identities:{control:identity(control),candidate:identity(candidate)},preferences:parent.preferences,argv:parent.argv,unchangedBounds:proposal.scope.unchangedBounds,assertions:{sourceOnly:true,noTestsOrLaunches:true,final3msSourceUnchanged:true,sharedCodeIdentical:true,onlyProjectSettingDiff:true,originalLazyClockGuards:true,noCLIEnvironmentRegistryBypass:true,pre70WorkerDecodeUnchanged:true}};
const manifestFile=path.join(directory,'pair.json');fs.writeFileSync(manifestFile,JSON.stringify(manifest,null,2)+'\n',{flag:'wx'});
async function stage(){
 const helperFile=path.join(project,'tools/native-production-selection.cjs'),expected=pins.find(pin=>pin.file==='tools/native-production-selection.cjs').sha256;assert.equal(sha(read(helperFile)),expected);const helper=require(helperFile),selections=[];
 for(const [leg,destination]of Object.entries(views)){const result=await helper.stageProductionSelection({project:destination,label:label+'-'+leg,argv:parent.argv,preferenceSeeds:json(parent.preferences.file),env:{}});selections.push({leg,file:result.file,sha256:result.sha256});}
 for(const pin of pins)assert.equal(sha(read(path.join(parent.candidate,pin.file))),pin.sha256,'Original final candidate changed');
 const staged={pair:manifestFile,pairSHA256:sha(read(manifestFile)),selections,noBuilds:true,noTests:true,noLaunches:true};fs.writeFileSync(path.join(directory,'staged.json'),JSON.stringify(staged,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify(staged,null,2));
}
stage().catch(error=>{console.error(error.stack);process.exitCode=1;});
