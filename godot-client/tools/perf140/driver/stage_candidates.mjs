import fs from 'node:fs';import path from 'node:path';import crypto from 'node:crypto';import {fileURLToPath} from 'node:url';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..'),hash=b=>crypto.createHash('sha256').update(b).digest('hex');
const commonFile=path.join(project,'.cache/native-140fps/root/common-v1/manifest.json'),common=JSON.parse(fs.readFileSync(commonFile));
function loading(label){const file=path.join(project,'.cache/native-140fps/loading-agent',label,'manifest.json'),r=JSON.parse(fs.readFileSync(file));return {file,changes:r.changed.map(v=>({...v,from:path.join(r.candidate,v.relative)}))};}
function render(relative,source,before){const from=path.join(project,'tools/perf140/render',source);return {file:from,changes:[{relative,before,after:hash(fs.readFileSync(from)),from}]};}
const weak=loading('weak-residency-v2'),material=loading('material-init-v2'),combined=loading('combined-loading-v1');
const lamp=render('systems/native_render/model_point_light.gd','model_point_light_candidate.gd','e803135ef951ea13d3d83267f0d671d2072e2df4d676bdf320a98fd9b4d1b9f6');
const palette=render('systems/native_render/native_light_palette.gd','native_light_palette_candidate.gd','2485df8c97d8ede450aa85ca8407812d35ecf5fd456c47d524b8921a22d3eb21');
const particleFile=path.join(project,'.cache/native-140fps/particles-agent/frame-pose-epochs-v2/candidate-built-sources.json'),particle=JSON.parse(fs.readFileSync(particleFile));
if(!particle.isolatedBuildFinalized||hash(fs.readFileSync(particle.baselineReceipt.file))!==particle.baselineReceipt.sha256)throw Error('Particle finalization/baseline receipt differs');
const particleBase=JSON.parse(fs.readFileSync(particle.baselineReceipt.file));
const particleChanges=[...particle.overrides.map(v=>v.relative),'.cache/native-kernel/nwn-particle-kernel.dll','.cache/native-kernel/build-manifest.json'].map(relative=>{
 const from=path.join(particle.sourceProject,relative),pin=particle.sourcePins.find(v=>v.relative===relative),base=particleBase.sourcePins.find(v=>v.relative===relative);const before=common.pins.some(v=>v.relative===relative)?base?.sha256??base?.finalSha256:null;
 if(hash(fs.readFileSync(from))!==(pin.sha256??pin.finalSha256))throw Error('Particle candidate changed');return {relative,from,before,after:pin.sha256??pin.finalSha256};
});
const variants=[['loading-weak-v1',[weak]],['loading-material-v1',[material]],['loading-combined-v1',[combined]],['render-lamp-v1',[lamp]],['render-palette-v1',[palette]],['particles-epochs-v1',[{file:particleFile,changes:particleChanges}]],['combined-first-wave-v1',[combined,lamp,palette,{file:particleFile,changes:particleChanges}]]];
const results=[];
for(const[label,parents]of variants){
 const stage=path.join(project,'.cache/native-140fps/root',label),copy=path.join(stage,'project');if(fs.existsSync(stage))throw Error('Existing derivative preserved: '+label);fs.mkdirSync(copy,{recursive:true});
 const changes=parents.flatMap(v=>v.changes),seen=new Set();for(const c of changes){if(seen.has(c.relative))throw Error('Overlapping candidate ownership');seen.add(c.relative);const p=common.pins.find(v=>v.relative===c.relative);if((p?.sha256??null)!==c.before)throw Error('Common baseline differs: '+label+'/'+c.relative);if(hash(fs.readFileSync(c.from))!==c.after)throw Error('Candidate changed: '+c.relative);}
 const pins=[];for(const p of common.pins){const bytes=fs.readFileSync(path.join(common.project,p.relative));if(hash(bytes)!==p.sha256)throw Error('Common source changed');const dest=path.join(copy,p.relative);fs.mkdirSync(path.dirname(dest),{recursive:true});fs.writeFileSync(dest,bytes);pins.push({...p});}
 for(const c of changes){const dest=path.join(copy,c.relative);fs.mkdirSync(path.dirname(dest),{recursive:true});fs.copyFileSync(c.from,dest);const p=pins.find(v=>v.relative===c.relative);if(p)p.sha256=c.after;else pins.push({relative:c.relative,sha256:c.after});}
 const receipt={version:1,label,project:copy,common:{file:commonFile,sha256:hash(fs.readFileSync(commonFile))},parents:parents.map(v=>({file:v.file,sha256:hash(fs.readFileSync(v.file))})),changes,pins,sharedNativeBuilds:0,serverConnections:0,graphicsAcceptance:false};const file=path.join(stage,'manifest.json');fs.writeFileSync(file,JSON.stringify(receipt,null,2)+'\n',{flag:'wx'});results.push({label,file,project:copy,changes:changes.map(v=>v.relative)});
}
const output=path.join(project,'reports/native-perf140-first-wave-candidates-v1.json');fs.writeFileSync(output,JSON.stringify(results,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify(results));
