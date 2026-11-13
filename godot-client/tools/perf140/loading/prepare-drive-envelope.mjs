import fs from 'node:fs';import path from 'node:path';import {fileURLToPath} from 'node:url';import {digest} from './processor-graph.mjs';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..'),label=process.argv[2];if(!/^drive-preview-envelope-[a-z0-9-]+$/.test(label??''))throw Error('Fresh owned envelope label required');
const stage=path.join(project,'.cache/native-140fps/loading-agent',label);if(fs.existsSync(stage))throw Error('Existing evidence preserved');
const parentFile=path.join(project,'.cache/native-140fps/loading-agent/drive-preview-index-v1/manifest.json'),parentBytes=fs.readFileSync(parentFile),parent=JSON.parse(parentBytes);if(digest(parentBytes)!=='9194c5c9ef2e4b9c0e87875c573e8de229ec2a0d0fd267c1e2aca5b78d17e2d2')throw Error('Frozen indexed parent differs');
const copy=path.join(stage,'project'),pins=new Map(),changes=[],preserved=[];fs.mkdirSync(copy,{recursive:true});
for(const pin of parent.pins){const bytes=fs.readFileSync(path.join(parent.project,pin.relative));if(digest(bytes)!==pin.sha256)throw Error('Parent source differs: '+pin.relative);const file=path.join(copy,pin.relative);fs.mkdirSync(path.dirname(file),{recursive:true});fs.writeFileSync(file,bytes);pins.set(pin.relative,pin.sha256);}
function once(s,a,b){if(s.split(a).length!==2)throw Error('Guarded source seam differs: '+a.slice(0,110));return s.replace(a,b);}
function functionBody(s,name){const start=s.indexOf('func '+name+'(');if(start<0)throw Error('Missing function: '+name);const rest=s.slice(start),m=/\n(?:static )?func /.exec(rest);return m?rest.slice(0,m.index):rest;}
function patch(relative,fn){const file=path.join(copy,relative),raw=fs.readFileSync(file,'utf8'),crlf=raw.includes('\r\n'),before=pins.get(relative);let text=fn(raw.replaceAll('\r\n','\n'));if(crlf)text=text.replaceAll('\n','\r\n');fs.writeFileSync(file,text);pins.set(relative,digest(Buffer.from(text)));changes.push({relative,before,after:pins.get(relative)});}
patch('systems/native_render/live_world.gd',s=>{
 s=once(s,'\tvar query_began:=FrameProfile.begin()\n\tvar clear: Callable=drive_collision.query(id)', '\tvar query_began:=FrameProfile.begin()\n\tvar preview_plan: Dictionary={}\n\tvar clear: Callable\n\tif drive_collision.has_method("query_preview"):\n\t\tvar planned_orientation: Vector3=planner.wire_facing(heading) if heading>=0 else state.orientation\n\t\tpreview_plan=planner.plan(state.position,planned_orientation,float(state.walkRate),float(state.runRate),flags)\n\t\tclear=drive_collision.query_preview(id,state.position,preview_plan.target,state.render)\n\telse:clear=drive_collision.query(id)');
 s=once(s,'\tvar plan: Dictionary=planner.plan(state.position,state.orientation,float(state.walkRate),float(state.runRate),flags)', '\tvar plan: Dictionary=preview_plan if not preview_plan.is_empty() else planner.plan(state.position,state.orientation,float(state.walkRate),float(state.runRate),flags)');return s;
});
const inc=fs.readFileSync(path.join(project,'tools/perf140/loading/drive_preview_envelope.gd.inc'),'utf8');
patch('systems/native_render/drive_collision_indexed.gd',s=>{
 const original=s;
 s=once(s,'func query(id:',inc+'\nfunc query(id:');
 for(const [from,to]of [
  ['\tspatial_ticket=spatial.begin(scope)','\tinvalidate_preview_geometry()\n\tspatial_ticket=spatial.begin(scope)'],
  ['func sync_full()->void:\n','func sync_full()->void:\n\tinvalidate_preview_geometry()\n'],
  ['func sync_delta(changed: Array,removed: Array)->void:\n','func sync_delta(changed: Array,removed: Array)->void:\n\tinvalidate_preview_geometry()\n'],
  ['func sync_source(id: int,object: Dictionary,order: int)->void:\n','func sync_source(id: int,object: Dictionary,order: int)->void:\n\tinvalidate_preview_geometry()\n'],
  ['func forget_source(id: int)->void:\n','func forget_source(id: int)->void:\n\tinvalidate_preview_geometry()\n'],
  ['func reindex_sources()->void:\n','func reindex_sources()->void:\n\tinvalidate_preview_geometry()\n'],
  ['func refresh_source(id: int)->void:\n','func refresh_source(id: int)->void:\n\tinvalidate_preview_geometry()\n'],
  ['func publish_model(key: String,value: Dictionary)->void:\n','func publish_model(key: String,value: Dictionary)->void:\n\tinvalidate_preview_geometry()\n'],
  ['func retire_index()->void:\n','func retire_index()->void:\n\tinvalidate_preview_geometry()\n'],
  ['\tif job.get("ticket",{})!=spatial_ticket or not spatial.snapshot().active:return\n','\tif job.get("ticket",{})!=spatial_ticket or not spatial.snapshot().active:return\n\tinvalidate_preview_geometry()\n'],
  ['\tif motion.is_empty():withdraw_binding(binding);return','\tif motion.is_empty():invalidate_preview_geometry();withdraw_binding(binding);return'],
  ['\tbinding.point=point\n','\tif binding.get("point")!=point:invalidate_preview_geometry()\n\tbinding.point=point\n']
 ])s=once(s,from,to);
 // Publication/source invalidation changes are separate from the original
 // unrestricted query and its exact polygon/height/tile implementation.
 for(const name of ['query','indexed_clear','static_candidates','tile','clear','_drive_clear_unprofiled']){
  const before=functionBody(original,name),after=functionBody(s,name);if(before!==after)throw Error('Preserved narrow/unrestricted owner changed: '+name);preserved.push({name,sha256:digest(Buffer.from(before))});
 }
 return s;
});
const manifest={version:1,label,stage,project:copy,candidate:copy,mode:'envelope',parent:{file:parentFile,sha256:digest(parentBytes)},changes,changed:[],pins:[...pins].map(([relative,sha256])=>({relative,sha256})),flags:['--drive-collision=indexed'],preservedFunctions:preserved,sourceInclude:{relative:'tools/perf140/loading/drive_preview_envelope.gd.inc',sha256:digest(Buffer.from(inc))},scope:'Temporary per-input XY conservative envelope collection over existing scoped index. Exact original clear/height/tile and unrestricted query preserved. Probe endpoints/scope/lifetime/source/frame changes fall back to original unrestricted callback. No Z prefilter, geometry truncation, height optimization or extra world store.',graphics:0,serverConnections:0,sharedNativeBuilds:0};
const file=path.join(stage,'manifest.json');fs.writeFileSync(file,JSON.stringify(manifest,null,2)+'\n');console.log(JSON.stringify({file,sha256:digest(fs.readFileSync(file)),changes,preservedFunctions:preserved}));
