'use strict';
// Frozen, normal-client offline pair with the same private kernel in both legs.
// The accepted DLL, engine and user preferences are never changed.
const fs=require('node:fs');
const path=require('node:path');
const crypto=require('node:crypto');
const assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../..');
const scope=path.join(root,'.cache/nwn64/animation-snapshot-client-pair-a');
const sourceStage=path.join(root,'.cache/native-render-gap/particles/nwn64-animation-snapshot-c');
const referenceFile=path.join(root,'.cache/native-presentation-parity/production-replay/nwn62-completion-tail-c/production-selection.json');
const sha=file=>crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const write=(file,value)=>fs.writeFileSync(file,JSON.stringify(value,null,2)+'\n',{flag:'wx'});
const nativeRelative='.cache/native-kernel/nwn-particle-kernel.dll';

async function main(){
 assert(!fs.existsSync(scope),'Preserve the previous private pair');
 const receipt=JSON.parse(fs.readFileSync(path.join(sourceStage,'kernel-build/build-receipt.json')));
 const kernelPins=JSON.parse(fs.readFileSync(path.join(sourceStage,'kernel-source-pins.json')));
 assert(receipt.success&&receipt.exit===0&&sha(receipt.binary)===receipt.binarySha256,'Private kernel receipt differs');
 for(const pin of kernelPins.pins)assert.equal(sha(path.join(root,pin.relative)),pin.sha256,'Private kernel source differs: '+pin.relative);
 assert.equal(sha(path.join(root,nativeRelative)),kernelPins.acceptedDllSha256,'Accepted DLL changed');
 const reference=JSON.parse(fs.readFileSync(referenceFile));
 const seeds={version:1,expected:reference.preferences.expected,description:'NWN-64 reviewed Arelith B preference bytes, private kernel snapshot pair'};
 for(const name of ['render','layout'])seeds[name]={file:reference.preferences[name].source,sha256:reference.preferences[name].sha256};
 const helper=require(path.join(root,'tools/native-production-selection.cjs'));
 const sourceIdentity=require(path.join(root,'tools/native-feature-manifest.cjs')).sourceIdentity;
 const rows={};
 for(const mode of ['off','on']){
  const label='nwn64-private-snapshot-'+mode+'-a';
  const staged=await helper.stageProductionSelection({project:root,label,argv:[...reference.options,'--particle-animation-snapshot='+mode],preferenceSeeds:seeds,env:{}});
  const selection=staged.selection,project=selection.sourceProject;
  const target=path.join(project,nativeRelative);
  assert.equal(sha(target),kernelPins.acceptedDllSha256,'Staged accepted DLL differs');
  fs.copyFileSync(receipt.binary,target);
  assert.equal(sha(target),receipt.binarySha256);
  const pin=selection.pins.find(row=>row.relative===nativeRelative);
  assert(pin,'Staged DLL pin missing');pin.sha256=receipt.binarySha256;
  const buildManifestFile=path.join(project,'.cache/native-kernel/build-manifest.json');
  const buildManifest=JSON.parse(fs.readFileSync(buildManifestFile));
  assert.equal(buildManifest.binarySha256,kernelPins.acceptedDllSha256);
  buildManifest.binarySha256=receipt.binarySha256;
  buildManifest.privateBuildProof={file:path.join(sourceStage,'kernel-build/build-receipt.json'),sha256:sha(path.join(sourceStage,'kernel-build/build-receipt.json'))};
  buildManifest.scope='Private NWN-64 animation snapshot comparison; accepted DLL untouched';
  fs.writeFileSync(buildManifestFile,JSON.stringify(buildManifest,null,2)+'\n');
  const manifestPin=selection.pins.find(row=>row.relative==='.cache/native-kernel/build-manifest.json');
  assert(manifestPin);manifestPin.sha256=sha(buildManifestFile);
  selection.mainSourceIdentity=sourceIdentity(project);
  selection.nativeBuilds=1;
  selection.scope='Private normal-client original-scene comparison; same private particle DLL in both modes; no accepted artifact or Arelith claim';
  fs.writeFileSync(staged.file,JSON.stringify(selection,null,2)+'\n');
  const selectionSha=sha(staged.file);
  await helper.readProductionSelection(staged.file,selectionSha);
  rows[mode]={file:staged.file,sha256:selectionSha,sourceIdentity:selection.mainSourceIdentity.sha256,flags:selection.flags};
 }
 assert.equal(rows.off.sourceIdentity,rows.on.sourceIdentity,'Private pair source differs');
 assert.deepEqual(rows.off.flags.map(x=>x.replace('particle-animation-snapshot=off','particle-animation-snapshot=on')),rows.on.flags);
 const prior=JSON.parse(fs.readFileSync(path.join(root,'.cache/nwn62/packed-route-pair-a/staged.json')));
 assert.equal(sha(path.join(prior.capture,'recording.json')),prior.recordingSha256);
 fs.mkdirSync(scope,{recursive:true});
 const result={version:1,issue:'NWN-64',private:true,accepted:false,sourceIdentity:rows.off.sourceIdentity,engineSha256:reference.runtime.executableSha256,particleSha256:receipt.binarySha256,acceptedParticleSha256:kernelPins.acceptedDllSha256,recordingSha256:prior.recordingSha256,capture:prior.capture,selections:rows,scope:'Same private DLL/source/engine/settings/capture; only frame animation snapshot flag differs. No live acceptance.'};
 const file=path.join(scope,'staged.json');write(file,result);
 console.log(JSON.stringify({file,sha256:sha(file),sourceIdentity:result.sourceIdentity,particleSha256:result.particleSha256}));
}
main().catch(error=>{console.error(error.stack);process.exitCode=1;});
