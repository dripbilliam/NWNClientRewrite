'use strict';
// Record private source proposals; never compile or edit shared engine sources.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const project=path.resolve(__dirname,'../..'),hash=b=>crypto.createHash('sha256').update(b).digest('hex');
const rel=['scene/3d/skeleton_3d.cpp','scene/3d/skeleton_3d.h','modules/nwn_particle_snapshot/rig_skin_publisher.cpp'];
const pin=p=>{const bytes=fs.readFileSync(p);return {file:p,bytes:bytes.length,sha256:hash(bytes)};};
const sources=rel.map(relative=>({relative,baseline:pin(path.join(project,'.cache/nwn65/engine-baseline',relative)),candidate:pin(path.join(project,'tools/nwn65/engine',relative))}));
const h=fs.readFileSync(sources[1].candidate.file,'utf8');assert(h.includes('void nwn_set_bone_pose_components('));
const out=path.join(project,'.cache/nwn65/engine-proposal.json');
const proposal={version:1,issue:'NWN-65',sources,translationUnits:['scene/3d/skeleton_3d.cpp','modules/nwn_particle_snapshot/rig_skin_publisher.cpp'],
 objectLayoutChanged:false,virtualMethodsChanged:false,scriptApiChanged:false,
 referenceArgument:'--rig-bone-components=reference',
 semantics:'Three exact component assignments share one index/tree/dirty-mark sequence. Unit scale remains exact Vector3(1,1,1); force-update, signal, continuation and reentry boundaries remain unchanged. TOOLS saving keeps original setters.',
 modifierProof:'make_bone_modified copies the unchanged pose_cache. Original setters only mark pose_cache_dirty; they do not rebuild pose_cache. Outside TOOLS saving, deferred dirty scheduling emits no authored callback, so repeated copies have identical final state.',
 existingSetterRejected:'set_bone_pose(Transform3D) decomposes scale rather than storing exact Vector3.ONE and is not numerically identical to the three original assignments.',
 requiredValidation:['Byte-exact original and accepted Core E reconstruction controls','rig_skin_publisher_test.gd and rig_skin_continuation_test.gd','component A-B-B-A publisher timing and exact poses/force/event/retirement comparisons','graphical skin parity on secondary display'],
 scope:'Private candidate only; no compilation, promotion, GPU/FPS acceptance or shared engine changes.'};
fs.writeFileSync(out,JSON.stringify(proposal,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({proposal:pin(out),translationUnits:proposal.translationUnits,sources:sources.map(s=>({relative:s.relative,baseline:s.baseline.sha256,candidate:s.candidate.sha256}))}));
