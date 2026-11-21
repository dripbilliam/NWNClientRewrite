import fs from 'node:fs';import path from 'node:path';import {fileURLToPath} from 'node:url';import {stage,hash,particleChanges} from './stage_library.mjs';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..'),root=path.join(project,'.cache/native-140fps/root');
const parentFile=path.join(root,'icon-fence-runtime-v3/manifest.json'),parent=JSON.parse(fs.readFileSync(parentFile)),compactFile=path.join(root,'compact-observation-v1/manifest.json'),compact=JSON.parse(fs.readFileSync(compactFile));
const compactNames=['native_live_world.gd','systems/native_render/presentation_counters.gd','systems/native_render/compact_observation.gd'];
const changes=compactNames.map(relative=>({relative,before:parent.pins.find(p=>p.relative===relative)?.sha256??null,after:compact.pins.find(p=>p.relative===relative).sha256,from:path.join(compact.project,relative)}));
const a=stage(project,parentFile,'compact-fenced-v1',changes,[compactFile]);
function particle(parent,label,receipt){const file=path.join(project,'.cache/native-140fps/particles-agent',receipt,'candidate-built-sources.json');return stage(project,parent,label,particleChanges(file),[file]);}
const b=particle(a.file,'compact-random-fenced-v2','native-shared-random-v2');
const c=particle(b.file,'compact-clock-fenced-v3','native-owned-clock-v3');
const d=particle(c.file,'compact-lease-fenced-v1','managed-pose-leases-v1');
const materialFile=path.join(project,'.cache/native-140fps/loading-agent/material-pose-v1/manifest.json'),material=JSON.parse(fs.readFileSync(materialFile));
const e=stage(project,c.file,'compact-material-fenced-v1',material.changed.map(p=>({...p,from:path.join(material.candidate,p.relative)})),[materialFile]);
const poseFile=path.join(project,'.cache/native-140fps/render-agent/clock-pose-guarded-v1/manifest.json'),pose=JSON.parse(fs.readFileSync(poseFile)),cp=JSON.parse(fs.readFileSync(c.file));if(pose.builds!==1)throw Error('Pose build is not finalized');
const poseChanges=['native/model_pose_storage.hpp','native/particle_kernel.cpp','.cache/native-kernel/nwn-particle-kernel.dll','.cache/native-kernel/build-manifest.json'].map(relative=>{const p=pose.pins.find(p=>p.relative===relative),from=path.join(pose.project,relative);if(hash(fs.readFileSync(from))!==p.sha256)throw Error('Frozen pose source differs');return{relative,from,before:cp.pins.find(p=>p.relative===relative)?.sha256??null,after:p.sha256};});
const f=stage(project,c.file,'compact-pose-fenced-v1',poseChanges,[poseFile]);
const report=path.join(project,'reports/native-perf140-runtime-followups-v2.json');fs.writeFileSync(report,JSON.stringify({compact:a,random:b,clock:c,lease:d,material:e,pose:f},null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({report,compact:a,random:b,clock:c,lease:d,material:e,pose:f}));
