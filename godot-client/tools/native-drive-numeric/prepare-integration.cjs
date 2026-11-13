'use strict';
// Produces reviewable private source/diff only. Never changes the live owner.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),cp=require('node:child_process');
const project=path.resolve(__dirname,'../..');
const source=path.join(project,'systems/native_render/drive_collision_indexed.gd');
const original=fs.readFileSync(source,'utf8');let result=original.replace(/\r\n/g,'\n');
function replace(old,next){if(result.split(old).length!==2)throw Error('Integration seam changed: '+old.slice(0,90));result=result.replace(old,next);}
replace('const MOTION_PAD:=2.0','const NumericBatch=preload("res://systems/native_render/drive_numeric_batch.gd")\nvar numeric_batch:=NumericBatch.new()\nconst MOTION_PAD:=2.0');
replace('func configure(owner,source,cache_path: String) -> void:\n','func configure(owner,source,cache_path: String) -> void:\n\tnumeric_batch.configure()\n');
replace('spatial_ticket=spatial.begin(scope)','numeric_batch.clear()\n\tspatial_ticket=spatial.begin(scope)');
replace('func retire_index()->void:\n','func retire_index()->void:\n\tnumeric_batch.clear()\n');
replace('func detach_prepared_data() -> Dictionary:\n','func detach_prepared_data() -> Dictionary:\n\tnumeric_batch.clear()\n');
replace('func tile(index: int) -> Array:\n',
'# Call once after adopting immutable prepared geometry, before public input.\nfunc prepare_numeric_payloads()->void:\n\tif not numeric_batch.enabled:return\n\tfor index in tiles:\n\t\tvar triangles: Array=tiles[index]\n\t\tif triangles.size()>=64:numeric_batch.bind("tile:%s"%index,triangles,true)\n\tfor id in objects:\n\t\tvar shape: Dictionary=objects[id]\n\t\tshape._drive_numeric_key="object:%s"%id\n\t\tif shape.triangles.size()>=64:numeric_batch.bind(shape._drive_numeric_key,shape.triangles,false)\nfunc tile(index: int) -> Array:\n');
// All source eviction sites retire the corresponding native source first.
result=result.replace(/objects\.erase\((id|key)\)/g,(_,id)=>`numeric_batch.invalidate("object:%s"%${id});objects.erase(${id})`);
replace('\ttiles[index]=result; return result','\ttiles[index]=result\n\tif numeric_batch.enabled and result.size()>=64:numeric_batch.bind("tile:%s"%index,result,true)\n\treturn result');
replace('\tobjects[id]=result; return result','\tresult._drive_numeric_key="object:%s"%id\n\tif numeric_batch.enabled and result.triangles.size()>=64:numeric_batch.bind(result._drive_numeric_key,result.triangles,false)\n\telse:numeric_batch.invalidate(result._drive_numeric_key)\n\tobjects[id]=result; return result');
replace('\t\t\tvar terms: Variant=arithmetic.tile_terms(tile_index,triangle_inputs) if arithmetic!=null else null',
'\t\t\tif triangle_inputs.size()>=64 and numeric_batch.enabled:\n\t\t\t\tvar batch: Dictionary=numeric_batch.query("tile:%s"%tile_index,a,b,radius,low,high,true)\n\t\t\t\tif not batch.is_empty():\n\t\t\t\t\tDriveProfile.count("count_drive_tile_triangle_inputs",triangle_inputs.size())\n\t\t\t\t\tif batch.blocked:\n\t\t\t\t\t\tDriveProfile.finish("drive_tile_coverage_ms",phase_began);return deny("tile_polygon",from,to)\n\t\t\t\t\tintervals.append_array(batch.intervals)\n\t\t\t\t\tcontinue\n\t\t\tvar terms: Variant=arithmetic.tile_terms(tile_index,triangle_inputs) if arithmetic!=null else null');
replace('\t\tfor tri in shape.triangles:\n',
'\t\tif shape.triangles.size()>=64 and numeric_batch.enabled:\n\t\t\tvar batch: Dictionary=numeric_batch.query(str(shape.get("_drive_numeric_key","")),a,b,radius,low,high,false)\n\t\t\tif not batch.is_empty():\n\t\t\t\tif batch.blocked:\n\t\t\t\t\tDriveProfile.finish("drive_obstacle_triangles_ms",phase_began);return deny("object_polygon",from,to)\n\t\t\t\tcontinue\n\t\tfor tri in shape.triangles:\n');
replace('\tstate.preview_geometry=preview_stats.duplicate()','\tstate.preview_geometry=preview_stats.duplicate()\n\tstate.numeric_batch=numeric_batch.snapshot()');
const label=process.argv[2]||'integration';if(!/^integration(?:-[a-z0-9]+)?$/.test(label))throw Error('Owned integration label required');
const destination=path.join(project,'.cache/native-presentation-parity/root/pause-fixes-v1/movement/numeric-sidecar-v1',label);
if(fs.existsSync(destination))throw Error('Existing integration evidence preserved');fs.mkdirSync(destination,{recursive:true});
const before=path.join(destination,'before.gd'),after=path.join(destination,'drive_collision_indexed.gd');fs.writeFileSync(before,original);fs.writeFileSync(after,result);
const diff=cp.spawnSync('git',['diff','--no-index','--',before,after],{encoding:'utf8',maxBuffer:2**20});if(![0,1].includes(diff.status))throw Error(diff.stderr);fs.writeFileSync(path.join(destination,'integration.patch'),diff.stdout);
const hash=s=>crypto.createHash('sha256').update(s).digest('hex');
const proof={version:1,sourceOnly:true,applied:false,baseline:hash(original),candidate:hash(result),source,destination,engineLaunches:0,builds:0};fs.writeFileSync(path.join(destination,'proof.json'),JSON.stringify(proof,null,2)+'\n');console.log(JSON.stringify(proof));
