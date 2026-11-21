'use strict';
// Source-only PRIVATE diagnostic adapter. No native/runtime/registry writes.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const project=path.resolve(__dirname,'../..');
const sha=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
const source='systems/native_render/particle_stream_group.gd';
const original='native.call("dispatch",15,{"enabled":sparse_enabled,"stride":120,"min_members":1800,"coarse_phases":coarse_enabled,"setup_boundary":setup_enabled,"reset":true})';
const instrumented='native.call("dispatch",15,{"enabled":true,"stride":120,"min_members":0,"coarse_phases":true,"setup_boundary":setup_enabled,"reset":true})';
function groupOverlay(bytes){const text=bytes.toString();assert.equal(text.split(original).length,2,'Exact existing sampler config must occur once');return Buffer.from(text.replace(original,instrumented));}
function proposal(){
 const baseline=path.join(project,'.cache/native-live-review/reviewed-arelith-b/project'),before=fs.readFileSync(path.join(baseline,source)),after=groupOverlay(before);
 const helper='tools/nwn64/phase_review_census.gd',helperBytes=fs.readFileSync(path.join(project,helper));
 return{version:1,private:true,productionPromotion:false,acceptedNativeSHA256:'485741af15f0581a3c60c0f9a8ae738888eba08716c7a5c2c2d1bd550828963d',source:{relative:source,beforeSHA256:sha(before),afterSHA256:sha(after),changes:1},helper:{relative:helper,bytes:helperBytes.length,sha256:sha(helperBytes)},finalReportAdapter:'report.private_particle_phase_review=preload("res://tools/nwn64/phase_review_census.gd").collect(world)',seam:'Immediately after report.world=world.snapshot(), before any world close; coordinator composes with NWN65 final census.',generations:[2,3],nativeProfile:false,gdProfile:false,sampler:{enabled:true,coarse_phases:true,stride:120,min_members:0,reset:true},noBuilds:true,noLaunches:true};
}
module.exports={source,groupOverlay,proposal};
if(require.main===module)process.stdout.write(JSON.stringify(proposal(),null,2)+'\n');
