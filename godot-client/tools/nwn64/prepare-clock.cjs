'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const project=path.resolve(__dirname,'../..'),sha=b=>crypto.createHash('sha256').update(b).digest('hex');
const baseline=JSON.parse(fs.readFileSync(path.join(project,'.cache/nwn64/baseline-source-pins.json')));
const label=process.argv[2]??'nwn64-clock-a';assert(/^nwn64-clock-[a-z]+$/.test(label));const stage=path.join(project,'.cache/native-render-gap/particles',label),view=path.join(stage,'kernel-project');
assert(!fs.existsSync(stage));fs.mkdirSync(view,{recursive:true});
const owned=new Set(['native/particle_kernel.cpp','native/particle_presentation.hpp']);
const pins=[];
for(const row of [...baseline.pins,{relative:'native/particle_clock_binding.hpp'}]){
 const data=fs.readFileSync(path.join(project,row.relative));
 if(row.sha256&&!owned.has(row.relative))assert.equal(sha(data),row.sha256,'Unrelated native source changed '+row.relative);
 const target=path.join(view,row.relative);fs.mkdirSync(path.dirname(target),{recursive:true});fs.writeFileSync(target,data,{flag:'wx'});
 pins.push({relative:row.relative,bytes:data.length,sha256:sha(data)});
}
const source={version:1,issue:'NWN-64',project:view,pins,scope:'Opt-in canonical ModelRigs clock reader at unchanged per-source boundary; guarded live dictionary reads, unchanged Callable fallback; no runtime/default promotion.'};
const file=path.join(stage,'kernel-source-pins.json');fs.writeFileSync(file,JSON.stringify(source,null,2)+'\n',{flag:'wx'});
const binary=path.join(project,'.cache/native-kernel/nwn-particle-kernel.dll');
const proposal={version:1,issue:'NWN-64',label,sourcePins:file,sourcePinsSha256:sha(fs.readFileSync(file)),files:pins.length,changed:pins.filter(row=>owned.has(row.relative)||!baseline.pins.some(before=>before.relative===row.relative)),acceptedBinarySha256:sha(fs.readFileSync(binary)),controlBuildReceipt:'.cache/native-render-gap/particles/nwn64-hit-control-a/kernel-build/build-receipt.json',compiler:'/O2 /fp:strict /EHsc /W4 /WX /std:c++17 /MD /LD, MSVC14.50.35717',selection:'--particle-clock-read=native; --particle-clock-read=reference wins; current accepted flags/default remain unchanged',safety:['No live clock/model values cached across callbacks, sources or frames','Current owner ObjectID, Script identity and original immutable source String rechecked every read via builtin ptrcalls','Exact canonical direct GDScript getter/plain field only; canonical path; derived/unknown/new script/source/schema/unsupported conversions use original Callable','Both state and packet/RNG comparisons plus reentry/mutation/reload/lifetime coverage required before component timing','Source-heavy 1750-source shared-presentation workload; profile=false for normal matched component timing; diagnostic profile passes separate']};
fs.writeFileSync(path.join(project,'.cache/nwn64/'+label+'-proposal.json'),JSON.stringify(proposal,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify(proposal));
