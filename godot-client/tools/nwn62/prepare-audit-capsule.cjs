"use strict";
const fs=require("node:fs"),path=require("node:path"),crypto=require("node:crypto"),assert=require("node:assert/strict");
const project=path.resolve(__dirname,"../..");
const hash=bytes=>crypto.createHash("sha256").update(bytes).digest("hex");
const read=file=>fs.readFileSync(file);
const json=file=>JSON.parse(read(file));
const label=process.argv[2]||"entry62-audit0-a";
assert(/^[a-z0-9][a-z0-9-]{0,59}$/.test(label));
const parentFile=path.join(project,".cache/nwn62/entry-pairs/entry62-policy-pair-a/pair.json");
const parent=json(parentFile);
const overlayRoot=path.join(project,".cache/nwn62/publication-audit-policy0-b");
const overlayFile=path.join(overlayRoot,"manifest.json"),overlay=json(overlayFile);
assert.equal(hash(read(overlayFile)),"37479578d497163d58f121f9022a00b277bfe326847570f940fbba94c9149c02");
assert.equal(path.resolve(overlay.sourceRoot),path.resolve(parent.control));
assert.equal(overlay.files.length,6);
const directory=path.join(project,".cache/nwn62/audit-inputs",label),input=path.join(directory,"project");
assert(!fs.existsSync(directory),"Refusing to overwrite audit input");
const safe=relative=>typeof relative==="string"&&!path.isAbsolute(relative)&&relative.split(/[\\/]/).every(part=>part&&part!=="."&&part!=="..");
const inside=(root,relative)=>{assert(safe(relative));const result=path.resolve(root,relative);assert(!path.relative(root,result).startsWith(".."));return result;};
const pins=new Map(parent.baseline.pins.map(row=>[row.file,row.sha256]));
pins.set(parent.commonInfrastructure.file,parent.commonInfrastructure.sha256);
// All validation precedes output. Ignore previously generated staging trees;
// only the parent's exhaustive reviewed source pins are copied.
for(const [relative,expected]of pins)assert.equal(hash(read(inside(parent.control,relative))),expected,relative);
for(const row of overlay.files){
  assert.equal(hash(read(inside(overlayRoot,row.path))),row.afterSHA256,row.path);
  if(row.beforeSHA256!==null)assert.equal(pins.get(row.path),row.beforeSHA256,row.path);
  else assert(!pins.has(row.path),"Unexpected existing helper");
}
fs.mkdirSync(input,{recursive:true});
const baselinePins=[];
for(const [relative,expected]of pins){
  const source=inside(parent.control,relative),destination=inside(input,relative);fs.mkdirSync(path.dirname(destination),{recursive:true});
  if(/\.(exe|dll)$/.test(relative))fs.linkSync(source,destination);else fs.writeFileSync(destination,read(source),{flag:"wx"});
  baselinePins.push({file:relative,sha256:expected});
}
for(const row of overlay.files){const destination=inside(input,row.path);fs.mkdirSync(path.dirname(destination),{recursive:true});fs.writeFileSync(destination,read(inside(overlayRoot,row.path)));pins.set(row.path,row.afterSHA256);}
for(const [relative,expected]of pins)assert.equal(hash(read(inside(input,relative))),expected,relative);
// Every unaffected byte equals frozen policy0; in particular identity logic,
// AssetService worker/decode, animation, motion, and private policy0 settings.
const allowed=new Set(overlay.files.map(row=>row.path));
for(const row of baselinePins)if(!allowed.has(row.file))assert.equal(hash(read(inside(input,row.file))),row.sha256,row.file);
const service="systems/native_data/asset_service.gd";
assert.equal(hash(read(inside(input,service))),hash(read(inside(parent.control,service))));
const pool=read(inside(input,"systems/native_render/resource_pool.gd")).toString("utf8");
assert(pool.includes("if _publication_audit_identity(pending.bundle,self)!=str(pending.key)"),"Original duplicate identity must remain observable");
const identity=require(path.join(input,"tools/native-feature-manifest.cjs")).sourceIdentity(input);
const manifest={version:1,ticket:"NWN-62",kind:"source-only-private-ledger-audit-input",created:new Date().toISOString(),directory,input,parent:{file:parentFile,sha256:hash(read(parentFile)),leg:"control",project:parent.control},overlay:{file:overlayFile,sha256:hash(read(overlayFile)),files:overlay.files},sourceIdentity:identity.sha256,pins:[...pins].map(([file,sha256])=>({file,sha256})),preferences:parent.preferences,argv:parent.argv,assertions:{allUnaffectedBytesExactPolicy0:true,oldDuplicateIdentityPreserved:true,noCurrent65Or70Or72Or73:true,noBudgetQuotaLoadingPolicyChange:true,originalInputsUntouched:true,noGameAssetsCopied:true,noBuildsOrLaunches:true}};
const manifestFile=path.join(directory,"manifest.json");fs.writeFileSync(manifestFile,JSON.stringify(manifest,null,2)+"\n",{flag:"wx"});
async function stage(){
  const helper=require(path.join(project,parent.commonInfrastructure.file));
  assert.equal(hash(read(path.join(project,parent.commonInfrastructure.file))),parent.commonInfrastructure.sha256,"Root staging helper changed");
  const receipt=await helper.stageProductionSelection({project:input,label,argv:parent.argv,preferenceSeeds:json(parent.preferences.file),env:{}});
  const staged={manifest:manifestFile,manifestSHA256:hash(read(manifestFile)),selection:receipt.file,selectionSHA256:receipt.sha256,sourceIdentity:identity.sha256,noLaunches:true,noBuilds:true};
  fs.writeFileSync(path.join(directory,"staged.json"),JSON.stringify(staged,null,2)+"\n",{flag:"wx"});console.log(JSON.stringify(staged,null,2));
}
stage().catch(error=>{console.error(error.stack);process.exitCode=1;});
