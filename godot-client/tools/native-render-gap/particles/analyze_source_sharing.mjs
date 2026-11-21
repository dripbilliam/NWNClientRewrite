import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';

// Cold, retained-evidence analysis only. Never query a running client.
const here=path.dirname(fileURLToPath(import.meta.url));
const project=path.resolve(here,'../../..');
const input=path.resolve(process.argv[2]??path.join(project,'reports/render-gap-setup-probe-v2-a-a.native.json'));
const output=path.resolve(process.argv[3]??path.join(project,'.cache/native-render-gap/particles/source-sharing-a.json'));
if(fs.existsSync(output))throw Error('Prior analysis is retained; choose a fresh output');
const bytes=fs.readFileSync(input),document=JSON.parse(bytes);
const census=document.render_gap?.source_census;
if(!Array.isArray(census?.rows))throw Error('No frozen source census rows at render_gap.source_census');
const sources=new Map(),poses=new Set();
for(const row of census.rows){
 const source=String(row.source_id??0),pose=String(row.pose_id??0);
 poses.add(pose);
 let group=sources.get(source);
 if(!group){group={source_id:source,members:0,pose_ids:new Set(),chunks:0,clocks:{},source_flags:{},selected_channels:0};sources.set(source,group);}
 ++group.members;group.pose_ids.add(pose);group.chunks+=row.chunk?1:0;group.selected_channels+=Number(row.selected_channels??0);
 const clock=String(row.clock??'unknown'),flags=String(row.source_model_flags??'unknown');
 group.clocks[clock]=(group.clocks[clock]??0)+1;group.source_flags[flags]=(group.source_flags[flags]??0)+1;
}
const groups=[...sources.values()].map(group=>({...group,pose_ids:[...group.pose_ids]})).sort((left,right)=>right.members-left.members);
const receipt={kind:'retained-source-identity-sharing-analysis',input,inputSha256:crypto.createHash('sha256').update(bytes).digest('hex'),members:census.rows.length,unique_source_ids:sources.size,unique_pose_ids:poses.size,singleton_sources:groups.filter(group=>group.members===1).length,repeated_source_members:groups.filter(group=>group.members>1).reduce((sum,group)=>sum+group.members,0),maximum_potential_same_frame_source_conversion_reuse:census.rows.length-sources.size,groups,limitations:['Source identity sharing is observed; changed transform frequency and numeric conversion cost are not recorded.','A fresh getter and lifetime/type validation must remain at every consume boundary.','The reuse upper bound applies only when current 12 float words match, after the existing per-endpoint conversion cache misses. Static local-cache hits have no new conversion work to eliminate.','No GDScript last_culled fields are used because the active native fast path leaves that mirror stale.']};
fs.mkdirSync(path.dirname(output),{recursive:true});fs.writeFileSync(output,JSON.stringify(receipt,null,2)+'\n');
console.log(JSON.stringify({...receipt,groups:groups.slice(0,12).map(({pose_ids,...group})=>({...group,unique_pose_ids:pose_ids.length}))}));
