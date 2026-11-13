'use strict';
// Offline report analysis only. No engine launch or timing is performed here.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../..'),sha=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
const legs={};
function capacity(world){
 const owners=new Map();
 function remember(row){
  if(!row?.available)return;
  const key=String(row.owner_instance_id),old=owners.get(key);
  if(!old){owners.set(key,structuredClone(row));return;}
  assert.equal(old.maximum_workers,row.maximum_workers,'Reported worker limit changed across owner snapshots');
  for(const [name,value]of Object.entries(row.counters))old.counters[name]=Math.max(old.counters[name]??0,value);
  old.running=Math.max(old.running??0,row.running??0);old.pending=Math.max(old.pending??0,row.pending??0);
 }
 function walk(value){
  if(!value||typeof value!=='object')return;
  if(Array.isArray(value)){for(const item of value)walk(item);return;}
  if(Object.hasOwn(value,'asset_worker_capacity'))remember(value.asset_worker_capacity);
  if(Array.isArray(value.active_asset_worker_capacity))for(const row of value.active_asset_worker_capacity)remember(row);
  for(const [name,item]of Object.entries(value))if(!['asset_worker_capacity','active_asset_worker_capacity'].includes(name))walk(item);
 }
 walk(world);
 const rows=[...owners.values()],events={dispatches:0,completed_slot_reuses:0,backlog_bound_blocks:0};
 for(const row of rows)for(const name of Object.keys(events))events[name]+=row.counters[name]??0;
 return {observedOwners:rows.length,eventCounters:events,allReservedActiveAtMostW:rows.every(row=>row.counters.maximum_reserved_active<=row.maximum_workers),allRetainedAtMost2W:rows.every(row=>row.counters.maximum_inflight<=2*row.maximum_workers),owners:rows};
}
for(const mode of ['control','candidate']){
 const file=`reports/nwn62-entry-final-a-${mode}.json`,bytes=fs.readFileSync(path.join(root,file)),r=JSON.parse(bytes),n=r.native,w=n.world,cache=n.render_cache_before_release;
 for(const field of ['success','sourceUnchanged','driverUnchanged','runtimeUnchanged'])assert.equal(r[field],true,mode+' '+field);
 assert.equal(r.engineOrLifetimeError,false);assert.equal(n.workers_remaining,0);assert.equal(w.pending_batches,0);assert.equal(w.failed_admissions,0);assert.deepEqual(w.failed_objects,{});assert.deepEqual(w.errors,[]);
 assert.equal(w.entities,630);assert.equal(w.terrain.tiles,121);assert.equal(w.terrain.failed_tiles,0);assert.equal(w.base_scenery.resolved,553);assert.equal(w.base_scenery.failed,0);assert.equal(w.base_scenery.pending,0);assert.equal(w.base_scenery.omitted_static,0);
 const creatureBatches=w.batches.filter(batch=>Object.hasOwn(batch,'planned_creatures'));
 legs[mode]={file,sha256:sha(bytes),strictSuccess:true,selection:r.productionSelection,measurement:r.measurement,protocolCount:n.protocol_objects.length,protocolJSONSHA256:sha(JSON.stringify(n.protocol_objects)),admitted:w.entities,tiles:w.terrain.tiles,baseExpected:w.base_scenery.expected,baseResolved:w.base_scenery.resolved,unknownPlaceables:w.base_scenery.unknown_placeables,classificationComplete:w.base_scenery.classification_complete,failed:0,pending:0,firstPlayableMs:w.playable_ms,loadingScreenElapsedMs:n.loading_screen.history[0].elapsed_ms,terrainAdmissionMs:w.terrain_admission_ms,terrainCompleteSinceTerrainStartMs:w.terrain.complete_ms,fullKnownBaseMs:w.base_scenery_first_known_complete_ms,creatureMaximumPublicationMs:Math.max(0,...creatureBatches.map(batch=>batch.max_publication_ms??0)),creatureBatchPublications:creatureBatches.map(batch=>({plannedCreatures:batch.planned_creatures,plannedItems:batch.planned_items,maximumPublicationMs:batch.max_publication_ms,publicationCPUms:batch.publication_ms})),maximumTilePublicationMs:w.terrain.max_tile_publish_ms,maximumTerrainPublishPassMs:w.terrain.max_publish_ms,adoptionTimings:w.adoption_timings,frames:n.frame_intervals,entryCommit:n.entry_commit_entries,ordinaryPublicationBudget:cache.publication_budget,construction:cache.template_construction,materials:cache.materials_created,directNativeMaterials:cache.direct_native_materials??0,retained:cache.retained,capacity:capacity(w),staleResults:w.stale_results};
}
assert.equal(legs.control.protocolJSONSHA256,legs.candidate.protocolJSONSHA256);
assert.deepEqual(legs.control.retained,legs.candidate.retained);
const budget=legs.candidate.ordinaryPublicationBudget;
assert.equal(budget.budget_us,3000);assert.equal(budget.effective_budget_us,3000);assert.equal(budget.entry_budget_configured_us,0);assert.equal(budget.private_entry.requested_us,0);assert.equal(budget.private_entry.project_setting_us,0);assert.equal(budget.private_entry.activations,0);assert.equal(budget.private_entry.maximum_effective_us,3000);
assert(legs.candidate.capacity.allReservedActiveAtMostW);assert(legs.candidate.capacity.allRetainedAtMost2W);assert(legs.candidate.capacity.eventCounters.completed_slot_reuses>0);
const delta=name=>legs.candidate[name]-legs.control[name];
const result={ticket:'NWN-62',scope:'One strict same-cohort headless pre62 audited61 control versus final62 candidate; source/runtime selections fixed, common61/pre70 worker decode/73off, ordinary3ms/no entry allowance.',legs,deltas:{firstPlayableMs:delta('firstPlayableMs'),terrainAdmissionMs:delta('terrainAdmissionMs'),fullKnownBaseMs:delta('fullKnownBaseMs'),fullKnownBasePercent:100*delta('fullKnownBaseMs')/legs.control.fullKnownBaseMs},conclusion:'Publication and loading-frame tails improve while full known scenery completes539.354ms later(+13.76%) in this headless cohort. First playable improves52.707ms. This is a smoothing/loading tradeoff, not an established steady FPS gain. Normal graphical loading/steady comparison is required before acceptance.',limitations:['Headless window_can_draw=false invokes the inspected engine low-processor frame delay, even when low_processor_mode is false; do not alter engine pacing or publication policy to make this comparison pass.','Frame intervals include loading; no steady FPS window was requested. Per-phase adoption pose maximum regresses1.417to2.749ms and registration1.476to1.504ms; firstentry open/ACK maxima also vary. Do not claim every cost improved or a hard3ms ceiling.','Creature/item max_publication_ms measures those construction calls, not arbitrary object stream or every AssetService completion. Tile aggregate pass4.118ms still exceeds3ms; indivisible API calls remain measured limitations.','Bounded timeline measurement.completed=false despite exact final known630objects/121tiles/553base and clean retirement. Knownbase classification remains incomplete with32unknown-placeable provenance. Derived recording still has explicit missing assets; not full visual/live Arelith acceptance.','One cohort/control-first order is a regression screen; graphical results must be compared within their own new cohort, never by subtracting absolute endpoints from previous runs.']};
const out=path.join(root,'.cache/nwn62/checks/entry-final-a-review.json');assert(!fs.existsSync(out),'Preserve prior review');fs.writeFileSync(out,JSON.stringify(result,null,2)+'\n');
console.log(JSON.stringify({out,sha256:sha(fs.readFileSync(out)),deltas:result.deltas,capacity:legs.candidate.capacity.eventCounters,observedOwners:legs.candidate.capacity.observedOwners,tail:{control:legs.control.frames,candidate:legs.candidate.frames}},null,2));
