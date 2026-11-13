"use strict";
// Source-only: frozen worker-wave B vs ONLY direct-material shader/Pool hunks.
const fs=require("node:fs"),path=require("node:path"),crypto=require("node:crypto"),assert=require("node:assert/strict");
const project=path.resolve(__dirname,"../.."),label=process.argv[2]||"entry62-direct-material-pair-a";
assert(/^[a-z0-9][a-z0-9-]{0,59}$/.test(label));
const sha=bytes=>crypto.createHash("sha256").update(bytes).digest("hex"),read=file=>fs.readFileSync(file),json=file=>JSON.parse(read(file));
const parentFile=path.join(project,".cache/nwn62/entry-pairs/entry62-worker-wave-pair-b/pair.json"),parent=json(parentFile);
const directory=path.join(project,".cache/nwn62/entry-pairs",label);assert(!fs.existsSync(directory),"Refusing overwrite");
const safe=relative=>!path.isAbsolute(relative)&&relative.split(/[\\/]/).every(part=>part&&part!=="."&&part!=="..");
const target=(root,relative)=>{assert(safe(relative));return path.join(root,relative);};
const pins=new Map(parent.baselinePins.map(row=>[row.file,row.sha256]));for(const row of parent.changes)pins.set(row.file,row.candidateSHA256);
for(const [file,expected]of pins)assert.equal(sha(read(target(parent.candidate,file))),expected,file);
function exact(source,before,after){assert.equal(source.split(before).length-1,1,before);return source.replace(before,after);}
const poolPath="systems/native_render/resource_pool.gd",materialPath="systems/native_render/native_model_material.gd";
const pool=read(target(project,poolPath)).toString("utf8"),poolBefore=read(path.join(project,".cache/nwn62/direct-material-before/resource_pool.gd")).toString("utf8");
const hit='\tif materials.has(key): stats.material_hits += 1; touch("material",key); return materials[key]';
const begin=pool.indexOf(hit)+hit.length,end=pool.indexOf('\n\tvar result := StandardMaterial3D.new()',begin);assert(begin>=hit.length&&end>begin);
const addition=pool.slice(begin,end);assert(addition.includes("configure_values(")&&addition.includes('stats["direct_native_materials"]')&&addition.includes("type_convert(null,TYPE_OBJECT)"));
assert.equal(exact(pool,addition,""),poolBefore,"Canonical Pool changes exceed exact direct-native insertion");
const frozenPool=read(target(parent.candidate,poolPath)).toString("utf8"),changedPool=exact(frozenPool,hit,hit+addition);
assert.equal(exact(changedPool,addition,""),frozenPool,"Frozen Pool inverse differs");
const material=read(target(project,materialPath));
assert.equal(sha(read(target(parent.candidate,materialPath))),sha(read(path.join(project,".cache/nwn62/direct-material-before/native_model_material.gd"))),"Frozen material does not match reviewed original");
const control=path.join(directory,"control-input"),candidate=path.join(directory,"candidate-input");
for(const [file]of pins)for(const root of [control,candidate]){
 const from=target(parent.candidate,file),to=target(root,file);fs.mkdirSync(path.dirname(to),{recursive:true});
 if(/\.(exe|dll)$/.test(file))fs.linkSync(from,to);else fs.writeFileSync(to,read(from),{flag:"wx"});
}
const changes=[{file:poolPath,controlSHA256:pins.get(poolPath),candidateSHA256:sha(changedPool)},{file:materialPath,controlSHA256:pins.get(materialPath),candidateSHA256:sha(material)}];
fs.writeFileSync(target(candidate,poolPath),changedPool);fs.writeFileSync(target(candidate,materialPath),material);
const changed=new Map(changes.map(row=>[row.file,row.candidateSHA256]));
for(const [file,expected]of pins){assert.equal(sha(read(target(control,file))),expected);assert.equal(sha(read(target(candidate,file))),changed.get(file)||expected,file);}
const identity=root=>require(path.join(root,"tools/native-feature-manifest.cjs")).sourceIdentity(root).sha256;
assert.equal(identity(control),parent.identities.candidate,"Control is not exact frozen worker-wave-B candidate");
const manifest={version:1,ticket:"NWN-62",kind:"final-native-material-publication-pair",created:new Date().toISOString(),directory,control,candidate,parent:{file:parentFile,sha256:sha(read(parentFile)),leg:"candidate",project:parent.candidate},baselinePins:[...pins].map(([file,sha256])=>({file,sha256})),changes,poolInverseByteExact:true,commonInstrumentation:parent.commonInstrumentation,identities:{control:identity(control),candidate:identity(candidate)},preferences:parent.preferences,argv:parent.argv,engagementCounter:"native.world.pool.direct_native_materials",assertions:{controlExactFrozenWorkerWaveB:true,candidateOnlyDirectMaterialAndPoolBranch:true,workerDecodeAndCapacityIdentical:true,private73OffAndAbsentBoth:true,sourceNoCurrent65Or70Or72Or73:true,noBudgetLoadingMarkOrClockChange:true,typedNullAndColorF32Preserved:true,legacyUnshadedAndInvalidFilterPreserved:true,noBuildsOrLaunches:true}};
const manifestFile=path.join(directory,"pair.json");fs.writeFileSync(manifestFile,JSON.stringify(manifest,null,2)+"\n",{flag:"wx"});
async function stage(){
 const helperPath=path.join(project,"tools/native-production-selection.cjs");assert.equal(sha(read(helperPath)),pins.get("tools/native-production-selection.cjs"));const helper=require(helperPath),selections=[];
 for(const [leg,root]of [["control",control],["candidate",candidate]]){const receipt=await helper.stageProductionSelection({project:root,label:label+"-"+leg,argv:parent.argv,preferenceSeeds:json(parent.preferences.file),env:{}});selections.push({leg,file:receipt.file,sha256:receipt.sha256});}
 const staged={pair:manifestFile,pairSHA256:sha(read(manifestFile)),selections,noBuilds:true,noLaunches:true};fs.writeFileSync(path.join(directory,"staged.json"),JSON.stringify(staged,null,2)+"\n",{flag:"wx"});console.log(JSON.stringify(staged,null,2));
}
stage().catch(error=>{console.error(error.stack);process.exitCode=1;});
