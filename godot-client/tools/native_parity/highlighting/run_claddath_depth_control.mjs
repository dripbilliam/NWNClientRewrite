// Fixture-only controlled floor addition to the already-passed actual c_goldem
// case. Original Actor, pose, pulse, textures, channels, depth-test and bounds
// production bytes stay identical. No room reconstruction or renderer fix.
import fs from 'node:fs/promises';import path from 'node:path';import crypto from 'node:crypto';import {spawn} from 'node:child_process';import {fileURLToPath} from 'node:url';
const source=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..'),[label,phase]=process.argv.slice(2),hash=raw=>crypto.createHash('sha256').update(raw).digest('hex');
if(!/^claddath-depth-control-[a-z0-9-]+$/.test(label??'')||!['stage','parse','run'].includes(phase))throw Error('Fresh owned floor-control label and phase required');
const parentFile=path.join(source,'.cache/native-presentation-parity/loading-agent/claddath-ghost-v5-assets-v2/stage.json'),parentRaw=await fs.readFile(parentFile),parent=JSON.parse(parentRaw),folder=path.join(source,'.cache/native-presentation-parity/loading-agent',label),project=path.join(folder,'project'),stageFile=path.join(folder,'stage.json');
const entry='tests/native_claddath_ghost_highlight_test.gd';
const helpers=String.raw`
var depth_control: Dictionary={}
func raster_below_triangle(a: Vector2,b: Vector2,c: Vector2,mask: PackedByteArray,width: int,height: int) -> void:
	var area: float=(b-a).cross(c-a)
	if area==0.:return
	var lo:=Vector2(minf(a.x,minf(b.x,c.x)),minf(a.y,minf(b.y,c.y)))
	var hi:=Vector2(maxf(a.x,maxf(b.x,c.x)),maxf(a.y,maxf(b.y,c.y)))
	for y in range(maxi(0,int(floor(lo.y))),mini(height,int(ceil(hi.y))+1)):
		for x in range(maxi(0,int(floor(lo.x))),mini(width,int(ceil(hi.x))+1)):
			var point:=Vector2(x+.5,y+.5)
			if (b-point).cross(c-point)/area>=0. and (c-point).cross(a-point)/area>=0. and (a-point).cross(b-point)/area>=0.:mask[y*width+x]=255
func below_floor_mask(camera: Camera3D,bounds) -> PackedByteArray:
	var defaults: Dictionary=bounds.AREA_PULSE_DEFAULTS
	var pulse: Dictionary=bounds.pulse_step(0.,0.,defaults.amplitude,defaults.frequency,defaults.size)
	var batch: Dictionary=ClassDB.class_call_static("NwnHighlightGeometry","build",bounds.kernel_shapes,bounds.kernel_poses,bounds.kernel_colors,bounds.kernel_alphas,bounds.kernel_enabled,camera.global_position,pulse.size,defaults.intensity)
	var vertices: PackedFloat32Array=batch.positions.to_float32_array();var mask:=PackedByteArray();mask.resize(root.size.x*root.size.y);mask.fill(0)
	for at in range(0,vertices.size(),9):
		var triangle: Array=[]
		for corner in 3:triangle.append(Vector3(vertices[at+corner*3],vertices[at+corner*3+1],vertices[at+corner*3+2]))
		var clipped: Array=[];var previous: Vector3=triangle.back();var prior_inside:=previous.y<0.
		for current: Vector3 in triangle:
			var inside:=current.y<0.
			if inside!=prior_inside:clipped.append(previous+(current-previous)*(previous.y/(previous.y-current.y)))
			if inside:clipped.append(current)
			previous=current;prior_inside=inside
		for index in range(1,clipped.size()-1):raster_below_triangle(camera.unproject_position(clipped[0]),camera.unproject_position(clipped[index]),camera.unproject_position(clipped[index+1]),mask,root.size.x,root.size.y)
	return mask
func green_delta(marked: Image,baseline: Image,mask: PackedByteArray) -> Dictionary:
	var total:=0;var below:=0;var energy:=0.;var below_energy:=0.
	for y in marked.get_height():
		for x in marked.get_width():
			var delta:=marked.get_pixel(x,y).g-baseline.get_pixel(x,y).g
			if delta>0.:
				total+=1;energy+=delta
				if mask[y*marked.get_width()+x]!=0:below+=1;below_energy+=delta
	return {"pixels":total,"green_sum":energy,"below_floor_projection_pixels":below,"below_floor_projection_green_sum":below_energy}
`;
const floor=String.raw`
	# Explicit authored opaque plane is a DEPTH control, not a native room asset.
	var below_mask:=below_floor_mask(camera,registry.native_highlight.bounds)
	Image.create_from_data(root.size.x,root.size.y,false,Image.FORMAT_L8,below_mask).save_png(output.trim_suffix(".json")+"-below-floor-mask.png")
	var without_floor:=green_delta(held,baseline,below_mask)
	var floor_mesh:=MeshInstance3D.new();var plane:=PlaneMesh.new();plane.size=Vector2(40,40);floor_mesh.mesh=plane;floor_mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var floor_material:=ShaderMaterial.new();var floor_shader:=Shader.new();floor_shader.code="shader_type spatial; render_mode unshaded,cull_disabled,depth_draw_opaque; void fragment(){ALBEDO=vec3(0.06);}";floor_material.shader=floor_shader;floor_mesh.material_override=floor_material;world.add_child(floor_mesh)
	check(not floor_shader.code.contains("ALPHA") and floor_shader.code.contains("depth_draw_opaque"),"Control floor is genuinely opaque and depth-writing; actual highlight depth state unchanged")
	registry.mark([],-1,false);registry.native_highlight._process(0.);await wait_draw();var floor_baseline:=save_phase("floor-baseline")
	registry.mark(ids,-1,true);registry.native_highlight._process(0.);await wait_draw();var floor_held:=save_phase("floor-held-tab")
	var with_floor:=green_delta(floor_held,floor_baseline,below_mask)
	check(without_floor.below_floor_projection_pixels>0 and with_floor.below_floor_projection_pixels<without_floor.below_floor_projection_pixels and with_floor.below_floor_projection_green_sum<without_floor.below_floor_projection_green_sum,"Opaque floor occludes actual below-floor Part-bounds highlight contributions")
	check(endpoints()==material_endpoints and alpha_matches(),"Floor control leaves all original actor material/shader/texture endpoints and translucent alpha unchanged")
	floor_mesh.visible=false;await wait_draw();var floor_removed:=save_phase("floor-removed-held-tab")
	check(floor_removed.get_data()==held.get_data(),"Removing only the control floor restores exact no-floor held-Tab pixels")
	depth_control={"floor":"explicit authored40x40 opaque plane atworldY0; no native-room claim","without_floor":without_floor,"with_floor":with_floor,"original_materials_unchanged":endpoints()==material_endpoints,"no_floor_restored_exact":floor_removed.get_data()==held.get_data(),"mask":"CPU projection of actual emitted triangle portions belowworldY0; pixel/energy measurements only, never a rendering cap"}
`;
function once(text,from,to){if(text.split(from).length!==2)throw Error('Exact fixture seam differs: '+from);return text.replace(from,to);}
if(phase==='stage'){
 await fs.mkdir(folder);await fs.mkdir(project);const pins=[];
 for(const pin of parent.pins){const from=path.join(parent.project,pin.relative),raw=await fs.readFile(from);if(hash(raw)!==pin.sha256)throw Error('Passed original fixture changed');let bytes=raw;if(pin.relative===entry){if(hash(raw)!=='a83df5cf7bfefc1c85abee76bd70e0f97a109ce1e5983169a9c389a7dfaa363e')throw Error('Original actual-model fixture differs');let text=raw.toString('utf8');text=once(text,'func run() -> void:',helpers+'\nfunc run() -> void:');text=once(text,'\tregistry.mark(ids,ids[0],true);registry.native_highlight._process(0.);await wait_draw();save_phase("hover-tab")',floor+'\n\tregistry.mark(ids,ids[0],true);registry.native_highlight._process(0.);await wait_draw();save_phase("hover-tab")');text=once(text,'"held_pixel_stable":stable,"highlight":final_stats','"held_pixel_stable":stable,"depth_control":depth_control,"highlight":final_stats');bytes=Buffer.from(text);}const target=path.join(project,pin.relative);await fs.mkdir(path.dirname(target),{recursive:true});await fs.writeFile(target,bytes,{flag:'wx'});pins.push({relative:pin.relative,source:from,sourceSha256:pin.sha256,sha256:hash(bytes),fixtureVariant:pin.relative===entry});}
 const stage={...parent,project,pins,parent:{file:parentFile,sha256:hash(parentRaw)},entry,expectedChecks:{run:31},fixtureScope:'Original passed Claddath27 plus4 explicit opaque-floor depth-control assertions. No production source change, room/native screenshot match, cap, brightness adjustment or FPS claim.'};await fs.writeFile(stageFile,JSON.stringify(stage,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({staged:true,pins:pins.length,folder,screen:stage.display.screen}));process.exit(0);
}
const stageRaw=await fs.readFile(stageFile),stage=JSON.parse(stageRaw),output=path.join(folder,phase+'.json');try{await fs.access(output);throw Error('Existing receipt preserved');}catch(error){if(error.code!=='ENOENT')throw error;}
if(phase==='run'&&!process.argv.includes('--graphics-authorized'))throw Error('Explicit Root/Door GPU release required');
const changes=async()=>{const rows=[];for(const pin of stage.pins)if(hash(await fs.readFile(path.join(project,pin.relative)))!==pin.sha256||hash(await fs.readFile(pin.source))!==pin.sourceSha256)rows.push(pin.relative);return rows;};if((await changes()).length||hash(await fs.readFile(stage.engine.path))!==stage.engine.sha256)throw Error('Source/engine differs');
const home=path.join(folder,phase+'-userdata');await fs.mkdir(home);const report=path.join(folder,phase+'-result.json'),args=[...(phase==='parse'?['--headless','--check-only']:['--render-thread','separate','--rendering-method','forward_plus','--screen',String(stage.display.screen)]),'--log-file',path.join(folder,phase+'.engine.log'),'--path',project,'--script','res://'+entry,'--','--report='+report,'--install='+stage.install,'--expected-screen='+stage.display.screen,'--highlight-kernel=compiled','--particle-kernel=compiled','--model-storage=native'];
const child=spawn(stage.engine.path,args,{cwd:project,windowsHide:true,env:{...process.env,APPDATA:home,LOCALAPPDATA:home,NWN_PARTICLE_KERNEL:'compiled'}});console.log(JSON.stringify({started:true,pid:child.pid,phase,folder}));let stdout='',stderr='',timedOut=false;child.stdout.on('data',x=>stdout+=x);child.stderr.on('data',x=>stderr+=x);const timer=setTimeout(()=>{timedOut=true;child.kill();},120000),closed=await new Promise((resolve,reject)=>{child.once('error',reject);child.once('close',(code,signal)=>resolve({code,signal}));});clearTimeout(timer);await fs.writeFile(path.join(folder,phase+'.stdout.log'),stdout,{flag:'wx'});await fs.writeFile(path.join(folder,phase+'.stderr.log'),stderr,{flag:'wx'});let result=null;try{result=JSON.parse(await fs.readFile(report));}catch{}
const errors=(stdout+'\n'+stderr).split(/\r?\n/).filter(x=>/^ERROR:|SCRIPT ERROR|Parse Error|ObjectDB.*leak|resources still in use/.test(x)),sourceChanged=await changes(),success=closed.code===0&&!timedOut&&!errors.length&&!sourceChanged.length&&(phase==='parse'||result?.success===true&&result?.checks===31);
await fs.writeFile(output,JSON.stringify({success,...closed,timedOut,stage:{file:stageFile,sha256:hash(stageRaw)},capsule:stage.capsule,errors,sourceChanged,result,serverConnections:0,nativeBuilds:0,performanceClaim:false},null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({success,checks:result?.checks,failures:result?.failures,depthControl:result?.depth_control,errors,sourceChanged,output}));process.exitCode=success?0:1;
