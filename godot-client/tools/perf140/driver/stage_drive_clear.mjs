// Prepared source only. Running this performs a substantial guarded copy/hash
// pass; wait for a root-owned CPU lane and completed physical-WOK regression.
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {stage,hash} from './stage_library.mjs';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..');
const [agentLabel,expectedManifestSha256]=process.argv.slice(2);
if(!/^drive-preview-clear-provenance-[a-z0-9-]+$/.test(agentLabel??'')||!/[a-f0-9]{64}/.test(expectedManifestSha256??'')||expectedManifestSha256.length!==64)throw Error('Explicit reviewed metadata successor and SHA256 required');
const parentFile=path.join(project,'.cache/native-140fps/root/drive-envelope-fenced-v1/manifest.json');
if(hash(fs.readFileSync(parentFile))!=='cce71cea6e3ae8116d4747c97f1e161eed9350cd85386dc372578d9f6d4cdfc1')throw Error('Frozen root envelope differs');
const parent=JSON.parse(fs.readFileSync(parentFile));
const originalFile=path.join(project,'.cache/native-140fps/loading-agent/drive-preview-clear-v1/manifest.json');
if(hash(fs.readFileSync(originalFile))!=='85f8eb412cc424c360ccd771271597bf8001135ac0af2eca037249c9edf57749')throw Error('Frozen clear V1 differs');
const original=JSON.parse(fs.readFileSync(originalFile));
if(original.parent.sha256!=='d83cb44f55efbad8b1d8b840675f1f202b6047bb3592e5aeb6a92479c5352458')throw Error('Original envelope lineage differs');
const sourceFile=path.join(project,'.cache/native-140fps/loading-agent',agentLabel,'manifest.json');
if(hash(fs.readFileSync(sourceFile))!==expectedManifestSha256)throw Error('Reviewed metadata successor differs');
const source=JSON.parse(fs.readFileSync(sourceFile));
if(source.parent.sha256!==hash(fs.readFileSync(originalFile))||path.resolve(source.parent.file)!==originalFile)throw Error('Metadata successor lineage differs');
const changes=original.changes.map(p=>({...p,from:path.join(source.project,p.relative)}));
const expected=['native/drive_clear_kernel.hpp','native/drive_clear_bridge_decls.hpp','native/drive_clear_bridge.hpp','systems/native_render/drive_clear_cache.gd','native/particle_kernel.cpp','native/scene_geometry.hpp','systems/native_render/drive_collision_indexed.gd','.cache/native-kernel/nwn-particle-kernel.dll'].sort();
if(JSON.stringify(changes.map(p=>p.relative).sort())!==JSON.stringify(expected))throw Error('Unexpected clear runtime scope');
for(const p of original.pins){
  if(p.relative==='.cache/native-kernel/build-manifest.json')continue;
  if(source.pins.find(s=>s.relative===p.relative)?.sha256!==p.sha256)throw Error('Metadata successor changed runtime source: '+p.relative);
}
const proofRelative='.cache/native-kernel/drive-clear-build-proof.json';
const sourceProof=source.pins.find(p=>p.relative===proofRelative);
if(!sourceProof||sourceProof.sha256!=='f19c7f383953cf25b058daf51c06155fbaa019709b779e0da5231919578cb571')throw Error('Actual compile proof is absent or differs');
const proofFile=path.join(source.project,proofRelative);
if(hash(fs.readFileSync(proofFile))!==sourceProof.sha256)throw Error('Compile proof bytes differ');
const build=JSON.parse(fs.readFileSync(proofFile,'utf8').replace(/^\uFEFF/,''));
if(!build.success||build.sharedOutputWrites!==0||build.binarySha256!=='101efc79d3c2985d2267d05f9ffbd01578d2f14bbf52bad575ef921cd2412417'||path.resolve(build.project)!==original.project)throw Error('Actual build provenance differs');
for(const [relative,sha256]of Object.entries(build.sources))if(source.pins.find(p=>p.relative===relative)?.sha256!==sha256)throw Error('Built native source differs: '+relative);
changes.push({relative:proofRelative,from:proofFile,before:null,after:sourceProof.sha256});
const label='drive-clear-fenced-v2',folder=path.join(project,'.cache/native-140fps/root',label),draft=folder+'-draft';
if(fs.existsSync(folder)||fs.existsSync(draft))throw Error('Existing derivative evidence preserved');
const relative='.cache/native-kernel/build-manifest.json',metadataFile=path.join(source.project,relative);
const metadataSha=source.pins.find(p=>p.relative===relative)?.sha256;
if(!metadataSha||hash(fs.readFileSync(metadataFile))!==metadataSha)throw Error('Corrected build metadata differs');
const metadata=JSON.parse(fs.readFileSync(metadataFile));
if(metadata.binarySha256!==build.binarySha256||metadata.compiledSourceRoot!==build.project||metadata.successorCompilations!==0||metadata.sourceReceiptSha256!==sourceProof.sha256)throw Error('Corrected compile metadata is inconsistent');
// A new relocation is explicit. The original compilation root/receipt is never
// relabeled as the source of a compilation that did not happen in this copy.
metadata.binary=path.join(folder,'project/.cache/native-kernel/nwn-particle-kernel.dll');
metadata.relocatedSourceProject=path.join(folder,'project');
metadata.relocationParent={file:metadataFile,sha256:metadataSha};
fs.mkdirSync(draft);const from=path.join(draft,'build-manifest.json');fs.writeFileSync(from,JSON.stringify(metadata,null,2)+'\n');
changes.push({relative,from,before:parent.pins.find(p=>p.relative===relative).sha256,after:hash(fs.readFileSync(from))});
console.log(JSON.stringify(stage(project,parentFile,label,changes,[originalFile,sourceFile,proofFile])));
