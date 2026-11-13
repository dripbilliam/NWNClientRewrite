"use strict";

// Read-only, source-pinned review of already saved normal-client captures.
const fs=require("node:fs");
const path=require("node:path");
const crypto=require("node:crypto");
const root=path.resolve(__dirname,"../..");
const names=["nwn74-forward-census-d","nwn74-material-dedup-e"];
const owned=["native_live_world.gd","systems/native_render/live_world.gd","systems/native_render/live_world_pending_appearances.gd","systems/native_render/live_world_quiescent_candidate.gd","systems/native_render/live_world_support.gd","systems/network_motion.gd","systems/native_render/creature_stream.gd"];
const measures=["nodes","orphan_nodes","resources","count_world_instances","count_world_desired","count_motion_rows","count_motion_stationary_settled","count_motion_active","count_pose_evaluations","count_pose_unchanged_transforms","count_pose_transform_updates","count_pose_animation_changes","world_motion_update_ms","world_pose_inputs_ms","world_motion_finish_ms","world_pending_plan_ms","world_adoption"];
const digest=file=>crypto.createHash("sha256").update(fs.readFileSync(file)).digest("hex");
function summary(row,index){
  const metrics=row.frame_profile?.metrics??{};
  const values={};
  for(const key of measures)if(metrics[key])values[key]={mean:metrics[key].mean??null,p95:metrics[key].p95??null,max:metrics[key].max??null};
  return {index,elapsed_ms:row.elapsedMs,ready:row.ready,pending_batches:row.pending_batches,entities:row.entities,values};
}
function review(name){
  const manifest=JSON.parse(fs.readFileSync(path.join(root,"reports",`${name}.json`),"utf8"));
  const rows=fs.readFileSync(path.join(root,"reports",`${name}.performance.jsonl`),"utf8").trim().split(/\r?\n/).filter(Boolean).map(JSON.parse);
  const firstReady=rows.findIndex(row=>row.ready),settled=rows.findIndex(row=>row.ready&&row.pending_batches===0&&row.entities===1918);
  const half=rows.findIndex(row=>Number(row.frame_profile?.metrics?.count_world_instances?.mean??0)>=900);
  const selected=[0,firstReady,half,settled,rows.length-1].filter((index,offset,all)=>index>=0&&all.indexOf(index)===offset);
  const pins={};
  for(const file of owned){
    const key=Object.keys(manifest.sourceSha256??{}).find(value=>value.replaceAll("\\","/")===file);
    const captured=key?manifest.sourceSha256[key]:null;
    const current=digest(path.join(root,file));
    pins[file]={captured,current,matches_current:captured?.toLowerCase()===current};
  }
  return {name,success:manifest.success,source_unchanged_in_capture:manifest.sourceUnchanged,rows:rows.length,selected:selected.map(index=>summary(rows[index],index)),pins};
}
const result={ticket:"NWN-78",scope:"Existing normal-client profiles only; current source hash comparison is read-only, no new FPS measurement or claim that divergent source is identical",captures:names.map(review)};
const output=path.join(__dirname,"persistent-world-capture-review.json");
fs.writeFileSync(output,JSON.stringify(result,null,2)+"\n");
process.stdout.write(JSON.stringify({output,captures:result.captures.map(row=>({name:row.name,rows:row.rows,selected:row.selected.length,source_divergence:Object.entries(row.pins).filter(([,value])=>!value.matches_current).map(([file])=>file)}))})+"\n");
