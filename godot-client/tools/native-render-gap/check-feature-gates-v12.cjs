'use strict';
const fs=require('fs'),path=require('path'),assert=require('assert/strict'),crypto=require('crypto');
const project=path.resolve(__dirname,'../..'),dir=path.join(project,'.cache/native-render-gap/replays/hot-full-v7-a');
const selection=JSON.parse(fs.readFileSync(path.join(dir,'selection.json'))),file=path.join(project,'reports/render-gap-hot-full-v7-a-a.json'),report=JSON.parse(fs.readFileSync(file)),native=report.native;
const broken=require('./replay-adapter-v9.cjs'),fixed=require('./replay-adapter-v12.cjs');let checks=0;
assert.equal(broken.verifyNative(selection,native).status,'rejected');checks++;
const accepted=fixed.verifyNative(selection,native);assert.equal(accepted.status,'observed');assert.equal(accepted.features.skeletonForce,true);assert.equal(accepted.features.visibilityCache,true);checks+=3;
const cases=[
 ['--skeleton-force-pass=once',n=>n.render_gap.engine_features.skeleton_force_once.stable_calls=0],
 ['--visibility-chain-cache=epochs',n=>n.render_gap.engine_features.visibility_chain_cache.disabled=true],
 ['--particle-hot-parameters=bound',n=>n.render_gap.hot_parameters.owners=[]],
 ['--light-input-proof=segments',n=>n.render_gap.light_inputs.plain_segment_reuses=0],
 ['--light-input-read=typed',n=>n.render_gap.light_inputs.plain_claims=0],
 ['--pair-record-reuse=exact',n=>n.render_gap.engine_features.pair_reused=0],
 ['--light-pair-filter=consumers',n=>n.render_gap.engine_features.light_excluded=0],
 ['--particle-scene-direct=pod',n=>n.render_gap.particle_boundary.direct_enabled=false],
 ['--particle-coarse-timing',n=>n.render_gap.particle_sample.phase_clock_reads++],
 ['--rig-skin-publisher=native',n=>n.render_gap.skin_owners=[]]
];
for(const [flag,remove]of cases){const s={...selection,renderGap:{...selection.renderGap,extraFlags:[flag]}},n=structuredClone(native);assert.equal(fixed.verifyNative(s,n).status,'observed',flag+' positive');remove(n);assert.equal(fixed.verifyNative(s,n).status,'rejected',flag+' negative');checks+=2;}
const sha=b=>crypto.createHash('sha256').update(b).digest('hex'),out=path.join(project,'.cache/native-render-gap/analysis/feature-gates-v12.json');fs.mkdirSync(path.dirname(out),{recursive:true});fs.writeFileSync(out,JSON.stringify({success:true,checks,input:{file,sha256:sha(fs.readFileSync(file))},brokenAdapter:sha(fs.readFileSync(path.join(__dirname,'replay-adapter-v9.cjs'))),fixedAdapter:sha(fs.readFileSync(path.join(__dirname,'replay-adapter-v12.cjs'))),scope:'Verifier metadata regression only: real retained report input, positive and missing-activation rejection for independent gates. Rejected V9 run remains rejected; a fresh V10 replay is required for acceptance.'},null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({success:true,checks,out}));
