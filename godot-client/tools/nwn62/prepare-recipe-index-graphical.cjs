"use strict";
// Source-only private normal-client pair. The coordinator owns every launch.
const fs=require("node:fs"),path=require("node:path"),crypto=require("node:crypto"),assert=require("node:assert/strict");
const project=path.resolve(__dirname,"../.."),operation=process.argv[2]||"prepare",label=process.argv[3]||"entry62-recipe-index-graphical-a";
assert(["prepare","stage"].includes(operation));assert(/^[a-z0-9][a-z0-9-]{0,59}$/.test(label));
const sha=bytes=>crypto.createHash("sha256").update(bytes).digest("hex"),read=file=>fs.readFileSync(file),json=file=>JSON.parse(read(file));
const directory=path.join(project,".cache/nwn62/entry-pairs",label),proposalFile=path.join(directory,"proposal.json");
const parentFile=path.join(project,".cache/nwn62/entry-pairs/entry62-final-proposal-a/proposal.json"),parent=json(parentFile);
const parentRoot=parent.candidate,parentPins=new Map(parent.pins.candidate.map(row=>[row.file,row.sha256]));
const source={
 "systems/native_render/native_model_recipe.gd":{
  control:[".cache/nwn62/placement-index-20261111-a/recipe-control.gd","39e60ac3254c74dbc5d043262bd0413c98779fd21732c6c291f44b28e5040a2a"],
  candidate:["systems/native_render/native_model_recipe.gd","9a4d5f0bbf9bcb7868ad7a1b4bfb68c2179f32a0c29a77be3ce620ead62dfff2"]},
 "systems/native_render/model_template.gd":{
  control:[".cache/nwn62/placement-index-20261111-a/template-old.gd","51f219b5fdcb99f9a929eb04941b4ebb8a1bb60271d5b9c88fe4c722036e4924"],
  candidate:["systems/native_render/model_template.gd","a1a7db550b24061c1352bfd5b64afa596fb9d9b303512f6ebb09d40e5b4b7cd3"]},
 "systems/native_render/model_placement_job.gd":{
  control:[".cache/nwn62/placement-index-20261111-a/placement-control.gd","5fbff7e5c0afb3b08647029dfbe69caca9bbd661a8a7579fd5a59dc588585da9"],
  candidate:["systems/native_render/model_placement_job.gd","6d1cede71b07ff570c871b3349dd0b143ad94c3357c36dcf60eb2120835dac18"]},
};
const commonWorld="native_live_world.gd";
const capture=path.join(project,".cache/loading-benchmark-worlds/arelith-archive-shaders-v1");
function verifyInputs(){
 assert.equal(sha(read(parentFile)),"94dd2089568fb7eee917064bc5463b34482d2e88e110ad56292e892992eed5e6");
 for(const [file,wanted]of parentPins)assert.equal(sha(read(path.join(parentRoot,file))),wanted,"Frozen parent drift: "+file);
 for(const branches of Object.values(source))for(const [file,wanted]of Object.values(branches))assert.equal(sha(read(path.join(project,file))),wanted,file);
 assert.equal(sha(read(path.join(capture,"recording.json"))),"1922ba3b82b44d1982978850a7d0ef3f67a24d56130ec3f859a689ff77affe20");
 assert.equal(sha(read(path.join(capture,"timeline.jsonl"))),"d955e6fef37015dc189ab480a76bb03b0cc2f44482bdee5a55b45561a23715ee");
 assert.equal(parentPins.get(".tools/native-core/Godot_native_core_e_win64.exe"),"753b3e188068efaf865bda3abd6322ebe44e3a98ef2f5d199c8af1a78624c98b");
}
function medianWorld(){
 const old=read(path.join(parentRoot,commonWorld)).toString(),current=read(path.join(project,commonWorld)).toString();
 const oldLine=old.split("\n").find(line=>line.includes("report.frame_intervals="));
 const currentLine=current.split("\n").find(line=>line.includes("report.frame_intervals="));
 const medianLine=current.split("\n").find(line=>line.includes("var median_ms: float="));
 assert(oldLine&&currentLine&&medianLine);
 assert.equal(currentLine.replace('"median_ms":median_ms,',""),oldLine,"Median must be the only report-row difference");
 assert.equal(old.split(oldLine).length,2,"Ambiguous frame report");
 return Buffer.from(old.replace(oldLine,medianLine+"\n"+currentLine));
}
function prepare(){
 verifyInputs();assert(!fs.existsSync(directory),"Fresh stage label required");
 const common=medianWorld(),inputs={},pins={};
 for(const leg of ["control","candidate"]){
  const root=path.join(directory,leg+"-input");inputs[leg]=root;const legPins=new Map(parentPins);
  for(const [file,wanted]of parentPins){
   const from=path.join(parentRoot,file),to=path.join(root,file);fs.mkdirSync(path.dirname(to),{recursive:true});
   if(/\.(exe|dll)$/i.test(file))fs.linkSync(from,to);else fs.copyFileSync(from,to,fs.constants.COPYFILE_EXCL);
   assert.equal(sha(read(to)),wanted,file);
  }
  for(const [file,branches]of Object.entries(source)){
   const [relative,wanted]=branches[leg],bytes=read(path.join(project,relative));assert.equal(sha(bytes),wanted);
   fs.writeFileSync(path.join(root,file),bytes);legPins.set(file,wanted);
  }
  fs.writeFileSync(path.join(root,commonWorld),common);legPins.set(commonWorld,sha(common));
  for(const [file,wanted]of legPins)assert.equal(sha(read(path.join(root,file))),wanted,"Staged input drift: "+file);
  pins[leg]=[...legPins].map(([file,sha256])=>({file,sha256}));
 }
 const control=new Map(pins.control.map(row=>[row.file,row.sha256])),candidate=new Map(pins.candidate.map(row=>[row.file,row.sha256]));
 const differences=[...control].filter(([file,hash])=>candidate.get(file)!==hash).map(([file])=>file).sort();
 assert.deepEqual(differences,Object.keys(source).sort(),"The pair differs beyond the three index components");
 const identity=root=>require(path.join(root,"tools/native-feature-manifest.cjs")).sourceIdentity(root).sha256;
 const proposal={version:1,ticket:"NWN-62",kind:"private-normal-recipe-index-graphical-pair",created:new Date().toISOString(),directory,inputs,parent:{file:parentFile,sha256:sha(read(parentFile)),leg:"candidate",identity:parent.identities.candidate},pins,differences,source,commonMedian:{file:commonWorld,sha256:sha(common),inverseOnlyMedian:true},identities:{control:identity(inputs.control),candidate:identity(inputs.candidate)},engineSHA256:parentPins.get(".tools/native-core/Godot_native_core_e_win64.exe"),capture:{directory:capture,recordingSHA256:sha(read(path.join(capture,"recording.json"))),timelineSHA256:sha(read(path.join(capture,"timeline.jsonl"))),generation:4},argv:parent.argv,preferences:parent.preferences,plannedOrder:["control","candidate","candidate","control"],plannedFlags:["--steady-ms=10000","--settle-ms=5000","--preview"],acceptance:["Strict source, driver, runtime and render-selection pins; exit success","Same protocol objects, known base/terrain counts, no new admission or callback errors","Both legs engage recipe clones; exact content and snapshot counts","First playable, terrain and full-known-base loading latency; max template/actor/tile callback and frame median/p95/p99","Secondary unfocused monitor and same camera/FOV; ready and shutdown screenshots inspected"],limitations:["Frozen final-proposal normal source cohort; only recipe/template/placement differ, with common median telemetry","Derived generation-4 capture has explicitly missing original assets; no live Arelith acceptance","Graphical/FPS measurement requires coordinator exclusive lease; no launch in this script"],stageCommand:`node tools/nwn62/prepare-recipe-index-graphical.cjs stage ${label}`};
 fs.writeFileSync(proposalFile,JSON.stringify(proposal,null,2)+"\n",{flag:"wx"});
 console.log(JSON.stringify({proposal:proposalFile,sha256:sha(read(proposalFile)),differences,identities:proposal.identities,noLaunches:true}));
}
async function stage(){
 const proposal=json(proposalFile);assert.equal(proposal.kind,"private-normal-recipe-index-graphical-pair");
 for(const leg of ["control","candidate"])for(const pin of proposal.pins[leg])assert.equal(sha(read(path.join(proposal.inputs[leg],pin.file))),pin.sha256,pin.file);
 const helperPath=path.join(project,"tools/native-production-selection.cjs");assert.equal(sha(read(helperPath)),parentPins.get("tools/native-production-selection.cjs"));
 const helper=require(helperPath),selections=[];
 for(const leg of ["control","candidate"]){
  const receipt=await helper.stageProductionSelection({project:proposal.inputs[leg],label:label+"-"+leg,argv:proposal.argv,preferenceSeeds:json(proposal.preferences.file),env:{}});
  selections.push({leg,file:receipt.file,sha256:receipt.sha256,identity:receipt.selection.mainSourceIdentity.sha256});
 }
 const output={proposal:proposalFile,proposalSHA256:sha(read(proposalFile)),selections,noBuilds:true,noLaunches:true};
 fs.writeFileSync(path.join(directory,"staged.json"),JSON.stringify(output,null,2)+"\n",{flag:"wx"});
 console.log(JSON.stringify(output));
}
if(operation==="prepare")prepare();else stage().catch(error=>{console.error(error.stack);process.exitCode=1;});
