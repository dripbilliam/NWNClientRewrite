"use strict";
// Source-only narrow algorithm pair: frozen policy0 vs same bytes plus identity
// reuse and six unit-cap replacements. No audit, budget, or lifecycle changes.
const fs=require("node:fs"),path=require("node:path"),crypto=require("node:crypto"),assert=require("node:assert/strict");
const project=path.resolve(__dirname,"../.."),label=process.argv[2]||"entry62-batch32-pair-a";
assert(/^[a-z0-9][a-z0-9-]{0,59}$/.test(label));
const sha=bytes=>crypto.createHash("sha256").update(bytes).digest("hex"),read=file=>fs.readFileSync(file),json=file=>JSON.parse(read(file));
const parentFile=path.join(project,".cache/nwn62/entry-pairs/entry62-policy-pair-a/pair.json"),parent=json(parentFile);
const directory=path.join(project,".cache/nwn62/entry-pairs",label);assert(!fs.existsSync(directory),"Refusing to overwrite pair");
const safe=relative=>!path.isAbsolute(relative)&&relative.split(/[\\/]/).every(part=>part&&part!=="."&&part!=="..");
const target=(root,relative)=>{assert(safe(relative));return path.join(root,relative);};
const pins=new Map(parent.baseline.pins.map(row=>[row.file,row.sha256]));pins.set(parent.commonInfrastructure.file,parent.commonInfrastructure.sha256);
for(const [file,expected]of pins)assert.equal(sha(read(target(parent.control,file))),expected,file);
function exact(source,before,after){assert.equal(source.split(before).length-1,1,before);return source.replace(before,after);}
const modifications=new Map();
const poolPath="systems/native_render/resource_pool.gd";
const poolBefore=read(target(parent.control,poolPath)).toString("utf8");
const oldLine="\t\tif Template.identity(pending.bundle,self)!=str(pending.key):cancel_template_step(pending);return {\"status\":\"pending\",\"phase\":\"policy-invalidated\",\"units\":0}";
const newLines="\t\t# The current source identity already includes any mutation to this exact\n\t\t# Dictionary and current pool policy. A distinct request still needs its\n\t\t# own pinned-source validation before it can resume or replace this job.\n\t\tvar pending_key: String=key if is_same(pending.bundle,bundle) else Template.identity(pending.bundle,self)\n\t\tif pending_key!=str(pending.key):cancel_template_step(pending);return {\"status\":\"pending\",\"phase\":\"policy-invalidated\",\"units\":0}";
modifications.set(poolPath,Buffer.from(exact(poolBefore,oldLine,newLines)));
assert.equal(exact(read(target(project,poolPath)).toString("utf8"),newLines,oldLine),read(path.join(project,".cache/nwn62/identity-reuse-before/resource_pool.gd")).toString("utf8"),"Canonical Pool has unrelated edits");
const replacements={
  "systems/native_render/object_stream.gd":[["_animated_instance.install_step(8,Template.step_budget(pool))","_animated_instance.install_step(32,Template.step_budget(pool))"],["pool.model_template_step(entry.bundle,_template_pending,8,Template.step_budget(pool))","pool.model_template_step(entry.bundle,_template_pending,32,Template.step_budget(pool))"],["templates[name].create_step(_clone_pending,8,Template.step_budget(pool))","templates[name].create_step(_clone_pending,32,Template.step_budget(pool))"]],
  "systems/native_render/area_stream.gd":[["pool.model_template_step(bundles[row.model],_template_pending,8,Template.step_budget(pool))","pool.model_template_step(bundles[row.model],_template_pending,32,Template.step_budget(pool))"],["templates[key].create_step(_clone_pending,8,Template.step_budget(pool))","templates[key].create_step(_clone_pending,32,Template.step_budget(pool))"]],
  "systems/native_render/creature_stream.gd":[["actor.install_step(8,Template.step_budget(budget_owner))","actor.install_step(32,Template.step_budget(budget_owner))"]],
};
for(const [file,rows]of Object.entries(replacements)){
  let source=read(target(parent.control,file)).toString("utf8");for(const [before,after]of rows)source=exact(source,before,after);
  assert.equal(source,read(target(project,file)).toString("utf8"),"Canonical candidate differs beyond approved cap replacements: "+file);
  modifications.set(file,Buffer.from(source));
}
const control=path.join(directory,"control-input"),candidate=path.join(directory,"candidate-input");
for(const [file,expected]of pins)for(const root of [control,candidate]){
  const source=target(parent.control,file),destination=target(root,file);fs.mkdirSync(path.dirname(destination),{recursive:true});
  if(/\.(exe|dll)$/.test(file))fs.linkSync(source,destination);else fs.writeFileSync(destination,read(source),{flag:"wx"});
}
const changes=[];
for(const [file,bytes]of modifications){fs.writeFileSync(target(candidate,file),bytes);changes.push({file,controlSHA256:pins.get(file),candidateSHA256:sha(bytes)});}
for(const [file,expected]of pins){assert.equal(sha(read(target(control,file))),expected);assert.equal(sha(read(target(candidate,file))),modifications.has(file)?sha(modifications.get(file)):expected,file);}
assert.equal(modifications.size,4);
const identity=root=>require(path.join(root,"tools/native-feature-manifest.cjs")).sourceIdentity(root).sha256;
const manifest={version:1,ticket:"NWN-62",kind:"narrow-source-only-unit-batch-pair",created:new Date().toISOString(),directory,control,candidate,parent:{file:parentFile,sha256:sha(read(parentFile)),leg:"control",project:parent.control},baselinePins:[...pins].map(([file,sha256])=>({file,sha256})),changes,identities:{control:identity(control),candidate:identity(candidate)},preferences:parent.preferences,argv:parent.argv,assertions:{controlByteExactFrozenPolicy0:true,candidateOnlyIdentityAndSixCaps:true,privateEntrySettingZeroBoth:true,stepTimeBudgetUnchanged:true,sharedBudget3000Both:true,noEnumerationOrLoadingMarkChange:true,all61Pre70SourcesPreserved:true,noCurrent65Or70Or72Or73:true,noBuildsOrLaunches:true}};
const manifestFile=path.join(directory,"pair.json");fs.writeFileSync(manifestFile,JSON.stringify(manifest,null,2)+"\n",{flag:"wx"});
async function stage(){
  assert.equal(sha(read(target(project,parent.commonInfrastructure.file))),parent.commonInfrastructure.sha256);
  const helper=require(target(project,parent.commonInfrastructure.file)),receipts=[];
  for(const [leg,root]of [["control",control],["candidate",candidate]]){
    const value=await helper.stageProductionSelection({project:root,label:label+"-"+leg,argv:parent.argv,preferenceSeeds:json(parent.preferences.file),env:{}});
    receipts.push({leg,file:value.file,sha256:value.sha256});
  }
  const staged={pair:manifestFile,pairSHA256:sha(read(manifestFile)),selections:receipts,noLaunches:true,noBuilds:true};
  fs.writeFileSync(path.join(directory,"staged.json"),JSON.stringify(staged,null,2)+"\n",{flag:"wx"});console.log(JSON.stringify(staged,null,2));
}
stage().catch(error=>{console.error(error.stack);process.exitCode=1;});
