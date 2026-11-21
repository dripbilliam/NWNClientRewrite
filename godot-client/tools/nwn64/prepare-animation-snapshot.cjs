'use strict';
// Frozen private NWN-64 source and correctness project. Never writes the accepted DLL.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../..');
const label=process.argv[3]||'nwn64-animation-snapshot-a';
assert(/^nwn64-animation-snapshot-[a-z]$/.test(label));
const stage=path.join(root,'.cache/native-render-gap/particles',label);
const kernel=path.join(stage,'kernel-project');
const project=path.join(stage,'test-project');
const sha=file=>crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const file=(base,relative)=>path.join(base,relative);
function copy(source,destination){fs.mkdirSync(path.dirname(destination),{recursive:true});fs.copyFileSync(source,destination,fs.constants.COPYFILE_EXCL);}
const mode=process.argv[2];
if(mode==='prepare'){
 assert(!fs.existsSync(stage),'Private stage already exists');
 const manifest=JSON.parse(fs.readFileSync(file(root,'.cache/native-kernel/build-manifest.json')));
 const accepted=file(root,'.cache/native-kernel/nwn-particle-kernel.dll');
 assert.equal(sha(accepted),manifest.binarySha256,'Accepted DLL changed');
 const pins=[];
 const nativeFiles=[];
 function walk(directory){for(const entry of fs.readdirSync(directory,{withFileTypes:true})){
  const absolute=path.join(directory,entry.name);
  if(entry.isDirectory())walk(absolute);
  else if(/\.(cpp|hpp|inc)$/.test(entry.name))nativeFiles.push(path.relative(root,absolute).replaceAll('\\','/'));
 }}
 walk(file(root,'native'));
 for(const relative of nativeFiles){
  const source=file(root,relative),destination=file(kernel,relative);copy(source,destination);
  pins.push({relative,sha256:sha(destination)});
 }
 assert(pins.some(pin=>pin.relative==='native/particle_presentation.hpp'));
 fs.writeFileSync(file(stage,'kernel-source-pins.json'),JSON.stringify({version:1,issue:'NWN-64',project:kernel,pins,acceptedDllSha256:manifest.binarySha256,scope:'Current native closure with opt-in animation snapshot; private build only'},null,2)+'\n',{flag:'wx'});
 console.log(JSON.stringify({stage,pins:pins.length,acceptedDllSha256:manifest.binarySha256}));
}else if(mode==='stage-test'){
 const receipt=JSON.parse(fs.readFileSync(file(stage,'kernel-build/build-receipt.json')));
 assert(receipt.success&&receipt.exit===0&&!fs.existsSync(project),'Fresh private build/project required');
 const original=JSON.parse(fs.readFileSync(file(root,'.cache/native-render-gap/particles/hot-parameters-c/test-project-receipt.json')));
 const pins=[];
 for(const pin of original.pins){if(pin.relative==='.cache/native-kernel/nwn-particle-kernel.dll')continue;
  const source=file(original.project,pin.relative);assert.equal(sha(source),pin.sha256,'Frozen fixture drift: '+pin.relative);
  const destination=file(project,pin.relative);copy(source,destination);pins.push({relative:pin.relative,sha256:sha(destination)});
 }
 const binary=file(project,'.cache/native-kernel/nwn-particle-kernel.dll');copy(receipt.binary,binary);assert.equal(sha(binary),receipt.binarySha256);
 const fixture='tests/nwn64_animation_snapshot_test.gd';copy(file(root,fixture),file(project,fixture));
 pins.push({relative:'.cache/native-kernel/nwn-particle-kernel.dll',sha256:sha(binary)});
 pins.push({relative:fixture,sha256:sha(file(project,fixture))});
 fs.writeFileSync(file(stage,'test-project-receipt.json'),JSON.stringify({version:1,issue:'NWN-64',project,pins,acceptedDllSha256:JSON.parse(fs.readFileSync(file(stage,'kernel-source-pins.json'))).acceptedDllSha256,binarySha256:receipt.binarySha256,scope:'Private correctness test project; accepted DLL untouched'},null,2)+'\n',{flag:'wx'});
 console.log(JSON.stringify({project,pins:pins.length,binarySha256:receipt.binarySha256}));
}else if(mode==='add-heavy'||mode==='add-timing'){
 const receiptFile=file(stage,'test-project-receipt.json');
 const receipt=JSON.parse(fs.readFileSync(receiptFile));
 assert.equal(receipt.project,project);
 for(const pin of receipt.pins)assert.equal(sha(file(project,pin.relative)),pin.sha256,'Private test project drift: '+pin.relative);
 const fixture=mode==='add-heavy'?'tests/nwn64_animation_snapshot_heavy_test.gd':'tests/nwn64_animation_snapshot_timing_test.gd';
 copy(file(root,fixture),file(project,fixture));
 receipt.pins.push({relative:fixture,sha256:sha(file(project,fixture))});
 fs.writeFileSync(receiptFile,JSON.stringify(receipt,null,2)+'\n');
 console.log(JSON.stringify({fixture,sha256:sha(file(project,fixture)),pins:receipt.pins.length}));
}else throw Error('Use prepare, stage-test, add-heavy or add-timing');
