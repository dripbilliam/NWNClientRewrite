// Guarded source-only plan while the user plays. Execute only after Root grants
// CPU staging/tests. Never changes the frozen/running parent or main source.
import fs from 'node:fs';import path from 'node:path';import {fileURLToPath} from 'node:url';import {digest} from './processor-graph.mjs';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..'),label=process.argv[2],mode=process.argv[3]??'index';
if(!/^drive-preview-[a-z0-9-]+$/.test(label??'')||!['probe','index','basis'].includes(mode))throw Error('Fresh owned drive-preview label and probe/index/basis mode required');
const stage=path.join(project,'.cache/native-140fps/loading-agent',label);if(fs.existsSync(stage))throw Error('Existing evidence preserved');
const parentFile=path.join(project,'.cache/native-140fps/root/builtin-light-fenced-v2/manifest.json'),parentBytes=fs.readFileSync(parentFile),parent=JSON.parse(parentBytes);
if(digest(parentBytes)!=='672a89f094e3f8b845175b947556e3ca9b8c3bb4bd0e149a8f79058ad2cdc0d9')throw Error('Exact live source parent differs');
const copy=path.join(stage,'project'),pins=new Map(),changes=[];fs.mkdirSync(copy,{recursive:true});
for(const pin of parent.pins){const bytes=fs.readFileSync(path.join(parent.project,pin.relative));if(digest(bytes)!==pin.sha256)throw Error('Frozen parent source differs: '+pin.relative);const target=path.join(copy,pin.relative);fs.mkdirSync(path.dirname(target),{recursive:true});fs.writeFileSync(target,bytes);pins.set(pin.relative,pin.sha256);}
// The already-reviewed owner/index and original comparison are not replaced by
// a new index. Pin the exact version from the retained spatial investigation.
const expected={
 'systems/native_render/drive_collision.gd':'0b49304d86a356439c7adbf465ed5e6c7d93cdd32ab1fd79a689811e7a1b6c56',
 'systems/native_render/drive_collision_indexed.gd':'1fe54eef64f1710bad563766d2dcb2f2dcfbca336968c46acbcf358772f58b40',
 'systems/native_render/drive_spatial_index.gd':'464dbd12dc3094f745c15f3518fa91a36cd4397bb8a50be865bca0c5fbdca754'
};
for(const [relative,sha256]of Object.entries(expected))if(pins.get(relative)!==sha256)throw Error('Live parent spatial owner pin differs: '+relative);
function replace(text,from,to,n=1){if(text.split(from).length!==n+1)throw Error('Guarded source seam differs: '+from.slice(0,100));return text.replaceAll(from,to);}
function patch(relative,fn){const target=path.join(copy,relative),before=pins.get(relative),raw=fs.readFileSync(target,'utf8'),crlf=raw.includes('\r\n');let text=fn(raw.replaceAll('\r\n','\n'));if(crlf)text=text.replaceAll('\n','\r\n');fs.writeFileSync(target,text);const after=digest(Buffer.from(text));pins.set(relative,after);changes.push({relative,before,after});}
patch('systems/native_render/live_world.gd',text=>{
 if(mode==='index')text=replace(text,'var drive_spatial_enabled:=false # Experimental, explicitly selected before open().','var drive_spatial_enabled:=OS.get_cmdline_user_args().has("--drive-collision=indexed") # Opt-in before open; no hot switch.');
 const old='drive_collision=(preload("res://systems/native_render/drive_collision_indexed.gd").new() if drive_spatial_enabled else preload("res://systems/native_render/drive_collision.gd").new());';
 text=replace(text,old,'drive_collision=_new_drive_collision();');
 text=replace(text,'func preview_drive(id: int,flags: int,heading: int) -> Dictionary:',
  'func _new_drive_collision() -> Node:\n\treturn preload("res://systems/native_render/drive_collision_indexed.gd").new() if drive_spatial_enabled else preload("res://systems/native_render/drive_collision.gd").new()\nfunc preview_drive(id: int,flags: int,heading: int) -> Dictionary:');
 text=replace(text,'\tvar clear: Callable=drive_collision.query(id)\n\tif not clear.is_valid():', '\tvar query_began:=FrameProfile.begin()\n\tvar clear: Callable=drive_collision.query(id)\n\tFrameProfile.finish("keyboard_preview_query",query_began)\n\tif not clear.is_valid():');
 text=replace(text,'\tvar path: Dictionary=planner.path(state.position,plan.target,state.render,clear)', '\tvar path_began:=FrameProfile.begin()\n\tvar path: Dictionary=planner.path(state.position,plan.target,state.render,clear)\n\tFrameProfile.finish("keyboard_preview_path",path_began)');
 text=replace(text,'\t\tif drive_collision.has_method("sync_full"):drive_collision.sync_full()\n\t\telse:drive_collision.warm_dirty=true', '\t\tvar drive_publish_began:=FrameProfile.begin()\n\t\tif drive_collision.has_method("sync_full"):drive_collision.sync_full()\n\t\telse:drive_collision.warm_dirty=true\n\t\tFrameProfile.finish("drive_publish_full",drive_publish_began)');
 text=replace(text,'\tif is_instance_valid(drive_collision) and drive_collision.has_method("sync_delta"):drive_collision.sync_delta(objects,remove.keys())', '\tif is_instance_valid(drive_collision) and drive_collision.has_method("sync_delta"):\n\t\tvar drive_publish_began:=FrameProfile.begin()\n\t\tdrive_collision.sync_delta(objects,remove.keys())\n\t\tFrameProfile.finish("drive_publish_delta",drive_publish_began)');
 text=replace(text,'\tif is_instance_valid(drive_collision) and drive_collision.has_method("sync_motion"):drive_collision.sync_motion()', '\tif is_instance_valid(drive_collision) and drive_collision.has_method("sync_motion"):\n\t\tvar drive_publish_began:=FrameProfile.begin()\n\t\tdrive_collision.sync_motion()\n\t\tFrameProfile.finish("drive_publish_motion",drive_publish_began)');
 return text;
});
for(const relative of ['systems/native_render/drive_collision.gd','systems/native_render/drive_collision_indexed.gd'])patch(relative,text=>{
 text=replace(text,'const Assets=preload("res://systems/native_data/asset_service.gd")','const Assets=preload("res://systems/native_data/asset_service.gd")\nconst DriveProfile=preload("res://systems/native_render/frame_profile.gd")');
 const signature='func query(id: int,radius_override: float=-1) -> Callable:';
 const at=text.indexOf(signature),end=text.indexOf('\nfunc ',at+signature.length);if(at<0||end<0)throw Error('Query body unavailable');let body=text.slice(at,end);
 const dims='\tvar dims:=dimensions(id); var radius:=dims.x if radius_override<0 else radius_override';
 body=replace(body,dims,'\tvar drive_query_began:=DriveProfile.begin()\n'+dims);
 if(relative.endsWith('/drive_collision.gd')){
  body=replace(body,'\tfor key in world.desired:','\tDriveProfile.count("count_drive_factory_rows",world.desired.size())\n\tfor key in world.desired:');
  body=replace(body,'\treturn func(from: Vector3,to: Vector3):return clear(', '\tDriveProfile.finish("drive_query_factory",drive_query_began)\n\treturn func(from: Vector3,to: Vector3):return clear(');
 }else body=replace(body,'\treturn func(from: Vector3,to: Vector3):','\tDriveProfile.finish("drive_query_factory",drive_query_began)\n\treturn func(from: Vector3,to: Vector3):');
 text=text.slice(0,at)+body+text.slice(end);
 const built='\tvar result:={"signature":signature,"triangles":[],"min":Vector3(INF,INF,INF),"max":Vector3(-INF,-INF,-INF)}; var vertices: Array=[]';
 text=replace(text,built,'\tvar drive_shape_began:=DriveProfile.begin()\n\tDriveProfile.count("count_drive_shape_builds",1)\n\tDriveProfile.count("count_drive_shape_vertices",states[state].vertices.size())\n\tDriveProfile.count("count_drive_shape_faces",states[state].faces.size())\n'+built);
 text=replace(text,'\tobjects[id]=result; return result','\tobjects[id]=result\n\tDriveProfile.finish("drive_shape_build",drive_shape_began)\n\treturn result');
 text=replace(text,'\tif objects.has(id) and objects[id].signature==signature: return objects[id]','\tif objects.has(id) and objects[id].signature==signature:\n\t\tDriveProfile.count("count_drive_shape_cache_hits",1); return objects[id]');
 text=replace(text,'\tif tiles.has(index): return tiles[index]','\tif tiles.has(index):\n\t\tDriveProfile.count("count_drive_tile_cache_hits",1); return tiles[index]\n\tvar drive_tile_began:=DriveProfile.begin()\n\tDriveProfile.count("count_drive_tile_builds",1)');
 text=replace(text,'\ttiles[index]=result; return result','\ttiles[index]=result\n\tDriveProfile.finish("drive_tile_build",drive_tile_began)\n\treturn result');
 const clear='func clear(from: Vector3,to: Vector3,radius: float,height: float,obstacles: Array,creatures: Array,pending: Array) -> bool:';
 text=replace(text,clear,clear+'\n\tvar drive_clear_began:=DriveProfile.begin()\n\tDriveProfile.count("count_drive_clear_obstacle_inputs",obstacles.size())\n\tDriveProfile.count("count_drive_clear_creature_inputs",creatures.size())\n\tDriveProfile.count("count_drive_clear_pending_inputs",pending.size())\n\tvar accepted:=_drive_clear_unprofiled(from,to,radius,height,obstacles,creatures,pending)\n\tDriveProfile.finish("drive_clear",drive_clear_began)\n\tDriveProfile.count("count_drive_clear_calls",1)\n\treturn accepted\nfunc _drive_clear_unprofiled(from: Vector3,to: Vector3,radius: float,height: float,obstacles: Array,creatures: Array,pending: Array) -> bool:');
 text=replace(text,'\tvar start_z: float=world.surface.height(', '\tvar drive_heights_began:=DriveProfile.begin()\n\tvar start_z: float=world.surface.height(');
 text=replace(text,'\tvar intervals: Array=[]; var definition: Dictionary=world.surface.definition', '\tDriveProfile.finish("drive_clear_heights",drive_heights_began)\n\tvar intervals: Array=[]; var definition: Dictionary=world.surface.definition');
 if(relative.endsWith('/drive_collision_indexed.gd'))text=replace(text,'func static_candidates(from: Vector3,to: Vector3,radius: float,exclude: int)->Dictionary:\n', 'func static_candidates(from: Vector3,to: Vector3,radius: float,exclude: int)->Dictionary:\n\tDriveProfile.count("count_drive_model_group_inputs",static_groups.size())\n');
 if(mode==='basis')text=replace(text,'\tfor source in states[state].vertices:\n\t\tvar p: Vector3=Basis(Vector3.UP,float(pose.rotation))*Vector3(source.x,source.z,-source.y)+pose.position','\tvar rotation:=Basis(Vector3.UP,float(pose.rotation))\n\tfor source in states[state].vertices:\n\t\tvar p: Vector3=rotation*Vector3(source.x,source.z,-source.y)+pose.position');
 return text;
});
const fixtureSource=path.join(parent.project,'systems/native_render/drive_collision.gd'),fixture='tests/native_perf140_loading_drive_legacy.gd',fixtureBytes=fs.readFileSync(fixtureSource);
if(digest(fixtureBytes)!==expected['systems/native_render/drive_collision.gd'])throw Error('Frozen legacy oracle differs');fs.mkdirSync(path.join(copy,'tests'),{recursive:true});fs.writeFileSync(path.join(copy,fixture),fixtureBytes);pins.set(fixture,digest(fixtureBytes));
const manifest={version:1,label,stage,project:copy,candidate:copy,mode,parent:{file:parentFile,sha256:digest(parentBytes)},changes,changed:[],pins:[...pins].map(([relative,sha256])=>({relative,sha256})),flags:mode==='index'?['--drive-collision=indexed']:[],source_oracle:'native-drive-spatial-index-v2 / currentRuntime pins',scope:'Private common prediction/collision/publication diagnostics. Existing scoped index is opt-in only with single CLI before open; actual snapshot route retained. Probe and separate exact Basis-hoist modes do not activate the index. No gameplay/server authority, cached narrow phase, geometry, or query ordering removed.',serverConnections:0,graphics:0,sharedNativeBuilds:0};
const file=path.join(stage,'manifest.json');fs.writeFileSync(file,JSON.stringify(manifest,null,2)+'\n');console.log(JSON.stringify({file,sha256:digest(fs.readFileSync(file)),mode,changes}));
