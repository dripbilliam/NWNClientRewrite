extends SceneTree

const Archives=preload("res://systems/native_data/archive_index.gd")
const Document=preload("res://systems/native_data/gff_document.gd")
const Gff=preload("res://systems/native_data/gff_writer.gd")
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Assets=preload("res://systems/native_data/asset_service.gd")
const Extensions=preload("res://systems/native_data/resource_extensions.gd")
const PropAssets=preload("res://tools/dense-local-world/world/prop_assets.gd")

const MODULE_NAME:="DenseSync"
const HAK:="ds_fixture"
const SOURCE_MODEL:="ttr01_g01_01"
const SPAWN:=[50.0,40.0,0.0]
const TARGET:=[58.0,40.0,0.0]
const AREAS:=["dense_a","dense_b"]
const SKINNED_APPEARANCES:=[16,75] # Curst Swordsman and Elite Ogre.
const ROUTE_CLEARANCE:=3.0
const STRESS_CLEARANCE:=4.0
const TRAVEL_POINT:=Vector2(50,20)
const STRESS_RIGID_APPEARANCES:=[0,1,7,8,9,10,12,43,54,55,56,69,70,72,74,75,76,81,82,83,84,85,91,92,95,96,97,102,104,108,175,178,179]
const BASE_EFFECT_APPEARANCES:=[57,64,65,66]
const STRESS_AMBIENT_APPEARANCES:=[57,64,65,66,58,60,61,122,147,148,150,176]
const STRESS_MECHANICAL_APPEARANCES:=[22,23,26,27]
const STRESS_EVENTS:={"OnEnter":"stress_entry","OnHeartbeat":"stress_heartbeat"}
const ACTIVE_DOORS:=12
const ACTIVE_MECHANISMS:=24
const ATTENDANT_DISTANCE:=1.6

var failure:=""
var synced: Array[Dictionary]=[]

func _initialize()->void:
	run.call_deferred()

func reject(reason: String)->void:
	if failure.is_empty():failure=reason

func run()->void:
	var args:=OS.get_cmdline_user_args()
	if args.size()!=6:
		printerr("Expected installation, source module, fixture root, scale, port, and density")
		quit(2);return
	var root_path:=args[2]
	for folder in ["resources","server/modules","server/hak","server/servervault"]:
		if DirAccess.make_dir_recursive_absolute(root_path.path_join(folder))!=OK:
			reject("Could not create "+folder)
	if failure.is_empty():build(args[0],args[1],root_path,args[3],int(args[4]),int(args[5]))
	if not failure.is_empty():printerr(failure)
	quit(0 if failure.is_empty() else 1)

func read_original_texture_names(bytes: PackedByteArray)->Array:
	var decoder:=Assets.new()
	var model:=decoder.decode(bytes,2002,"mdl-original","")
	decoder.free()
	if not str(model.get("error","")).is_empty():
		reject("Source tile model: "+str(model.error));return []
	var names: Dictionary={}
	for node in model.get("value",{}).get("nodes",[]):
		var mesh: Dictionary=node.get("mesh",{})
		if not bool(mesh.get("render",false)) or mesh.get("indices",[]).size()<3:continue
		for bitmap in mesh.get("textures",[]):
			if str(bitmap).to_lower() not in ["","null"]:names[str(bitmap)]=true
	var result:=names.keys();result.sort()
	if result.is_empty():reject("Source tile has no rendered texture names")
	return result

func texture_bytes(size: int, group: int, kind: int, source: String)->PackedByteArray:
	var bytes:=PackedByteArray()
	bytes.resize(18+size*size*4)
	bytes[2]=2
	bytes.encode_u16(12,size);bytes.encode_u16(14,size)
	bytes[16]=32;bytes[17]=40
	var name:=source.to_lower()
	var foliage:=name.contains("leaf")
	var water:=name.contains("water")
	var ground:=name.contains("grass") or name.contains("leaf")
	for y in size:
		for x in size:
			var pixel: int=18+(y*size+x)*4
			var mixed:=((x*1973+y*9277+group*26699+kind*1297) ^ (x*y*439)) & 0xffff
			var fine: int=mixed%36
			var coarse: int=((x*8/size+y*8/size+group+kind)%2)*18
			var color:=Vector3i(55+group*18,89+kind*3,52+group*5) if ground else Vector3i(84+group*15,63+kind*5,53+group*6)
			if water:color=Vector3i(30+group*5,88+group*10,126+kind*4)
			bytes[pixel]=clampi(color.z+fine+coarse,0,255)
			bytes[pixel+1]=clampi(color.y+fine+coarse,0,255)
			bytes[pixel+2]=clampi(color.x+fine+coarse,0,255)
			var u:=2.0*float(x)/float(size)-1.0
			var v:=2.0*float(y)/float(size)-1.0
			bytes[pixel+3]=255 if not foliage or u*u*1.4+v*v<0.86 and mixed%11>0 else 0
	return bytes

func append_asset(resources: Dictionary,resref: String,ext: String,bytes: PackedByteArray,role: String,root_path: String)->void:
	if bytes.is_empty():
		reject("Generated asset is empty: "+resref+"."+ext);return
	var key:=resref+":"+str(Extensions.from_extension(ext))
	if resources.has(key):
		reject("Duplicate generated asset: "+key);return
	if not write_file(root_path.path_join("resources").path_join(resref+"."+ext),bytes):return
	resources[key]=bytes
	var hashing:=HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256);hashing.update(bytes)
	synced.append({"resref":resref,"type":Extensions.from_extension(ext),"sha256":hashing.finish().hex_encode(),"role":role,"bytes":bytes.size()})

func build_textures(root_path: String,install: String,smoke: bool,stress: bool)->Dictionary:
	var catalog:=Catalog.new()
	if not catalog.mount_install(install):reject("Source installation: "+catalog.failure);return {}
	catalog.build_resource_index()
	var original_model:=catalog.get_resource(SOURCE_MODEL,2002)
	if original_model.is_empty():
		reject("Source tile model is missing");return {}
	var textures:=read_original_texture_names(original_model)
	if not failure.is_empty():return {}
	var target_textures:=["ttr01_grass02","ttr01_leaf01"]
	if smoke:textures=textures.filter(func(name):return str(name).to_lower() in target_textures)
	var output: Dictionary={}
	for index in textures.size():
		var resref:=str(textures[index]).to_lower()
		var raster_size:=64 if smoke else 512
		append_asset(output,resref,"tga",texture_bytes(raster_size,2,index,resref),"terrain-texture",root_path)
	if stress:
		var props:=PropAssets.build(catalog)
		if not props.error.is_empty():
			reject(props.error);return {}
		for asset in props.assets:
			append_asset(output,asset.resref,asset.ext,asset.bytes,asset.role,root_path)
	return output

func read_gff(bytes: PackedByteArray,type: String)->Dictionary:
	var document:=Document.new()
	var parsed:=document.parse(bytes,type)
	if parsed.is_empty():reject(type+" source: "+document.failure);return {}
	var writer:=Gff.new()
	var root_record:=writer.typed(parsed,parsed.root)
	if root_record.is_empty() or not writer.failure.is_empty():
		reject(type+" fields: "+writer.failure);return {}
	return root_record.fields

func serialize_gff(type: String,fields: Dictionary)->PackedByteArray:
	var writer:=Gff.new()
	var bytes:=writer.write(type,Gff.record(fields))
	if bytes.is_empty():reject(type+" serialization: "+writer.failure)
	return bytes

func get_prelude_doors(install: String)->Array[Dictionary]:
	var reader:=Archives.new()
	var source:=reader.erf(install.path_join("data/nwm/Prelude.nwm"))
	var keys: Array=source.get("entries",{}).keys()
	keys.sort()
	var samples: Array[Dictionary]=[]
	var found: Dictionary={}
	for key in keys:
		if not str(key).ends_with(":2023"):continue
		var row:=read_gff(reader.payload(source,source.entries[key]),"GIT ")
		if not failure.is_empty():return []
		for doorway in row.get("Door List",{}).get("value",[]):
			var fields: Dictionary=doorway.fields
			var appearance:=int(fields.get("Appearance",{}).get("value",-1))
			var generic:=int(fields.get("GenericType_New",{}).get("value",0))
			var identifier: Array=[appearance,generic if appearance==0 else 0]
			if appearance<0 or found.has(identifier):continue
			if not fields.has("AnimationState") or not fields.has("X") or not fields.has("Y"):continue
			found[identifier]=true
			samples.append(doorway)
			if samples.size()==6:return samples
	if samples.size()<2:reject("Two installed door instances are required for the fixture")
	return samples

func place_at(record: Dictionary,point: Vector2,tag: String,x_key: String,y_key: String)->Dictionary:
	var result:=record.duplicate(true)
	var fields: Dictionary=result.fields
	fields[x_key].value=point.x
	fields[y_key].value=point.y
	fields.Tag.value=tag
	# Move the placed geometry, not its original area scripts or transition.
	for key in fields:
		if str(key).begins_with("On") and int(fields[key].type)==11:fields[key].value=""
	if fields.has("LinkedTo"):fields.LinkedTo.value=""
	if fields.has("LinkedToFlags"):fields.LinkedToFlags.value=0
	return result

func in_stress_corridor(point: Vector2)->bool:
	var start:=Vector2(SPAWN[0],SPAWN[1])
	var target:=Vector2(TARGET[0],TARGET[1])
	var move_distance:=point.distance_squared_to(Geometry2D.get_closest_point_to_segment(point,start,target))
	var travel_distance:=point.distance_squared_to(Geometry2D.get_closest_point_to_segment(point,start,TRAVEL_POINT))
	return minf(move_distance,travel_distance)<STRESS_CLEARANCE*STRESS_CLEARANCE

func available_positions(git: Dictionary,density: int)->Array[Vector2]:
	var occupied: Array[Vector2]=[]
	for record in git["Creature List"].value:
		occupied.append(Vector2(record.fields.XPosition.value,record.fields.YPosition.value))
	for record in git["Placeable List"].value:
		occupied.append(Vector2(record.fields.X.value,record.fields.Y.value))
	var locations: Array[Vector2]=[]
	var steps: int=[24,34,49,54][density-1]
	var spawn_point:=Vector2(SPAWN[0],SPAWN[1])
	for row in steps:
		for column in steps:
			var point:=Vector2(13.0+74.0*float(column)/float(steps-1),13.0+74.0*float(row)/float(steps-1))
			var close_to_lane:=point.x>46.0 and point.x<62.0 and absf(point.y-SPAWN[1])<ROUTE_CLEARANCE
			var close_to_transition:=point.distance_squared_to(TRAVEL_POINT)<20.0
			if close_to_lane or close_to_transition:continue
			if density>=3 and in_stress_corridor(point):continue
			if occupied.any(func(other: Vector2):return point.distance_squared_to(other)<1.45):continue
			locations.append(point)
	locations.sort_custom(func(a: Vector2,b: Vector2):return a.distance_squared_to(spawn_point)<b.distance_squared_to(spawn_point))
	return locations

func pin_creature(actor: Dictionary)->void:
	actor.fields.ScriptSpawn.value=""
	actor.fields.ScriptHeartbeat.value=""

func pair_attendant(locations: Array[Vector2],actor_slot: int,door_slot: int)->bool:
	for candidate in range(actor_slot,locations.size()):
		for adjacent in range(door_slot,locations.size()):
			if candidate==adjacent or locations[candidate].distance_squared_to(locations[adjacent])>ATTENDANT_DISTANCE*ATTENDANT_DISTANCE:continue
			var actor:=locations[actor_slot]
			locations[actor_slot]=locations[candidate]
			locations[candidate]=actor
			var door:=locations[door_slot]
			locations[door_slot]=locations[adjacent]
			locations[adjacent]=door
			return true
	return false

func clear_entry_lane(rows: Array,locations: Array[Vector2],x_key: String,y_key: String,stress: bool)->int:
	var start:=Vector2(SPAWN[0],SPAWN[1])
	var finish:=Vector2(TARGET[0],TARGET[1])
	var moved:=0
	for row in rows:
		var fields: Dictionary=row.fields
		var point:=Vector2(fields[x_key].value,fields[y_key].value)
		var route_point:=Geometry2D.get_closest_point_to_segment(point,start,finish)
		if stress:
			if not in_stress_corridor(point):continue
		elif point.distance_squared_to(route_point)>=ROUTE_CLEARANCE*ROUTE_CLEARANCE:
			continue
		if locations.is_empty():
			reject("No free position for an object in the benchmark corridor")
			return moved
		var nearest:=0
		for index in range(1,locations.size()):
			if point.distance_squared_to(locations[index])<point.distance_squared_to(locations[nearest]):nearest=index
		var destination: Vector2=locations.pop_at(nearest)
		fields[x_key].value=destination.x
		fields[y_key].value=destination.y
		moved+=1
	return moved

func populate_dense(git: Dictionary,doors: Array[Dictionary],area: String,density: int)->Dictionary:
	var creatures: Array=git["Creature List"].value
	var placeables: Array=git["Placeable List"].value
	var existing_doorway_rows: Array=git["Door List"].value
	var creature_samples:=creatures.duplicate()
	var prop_samples: Array[Dictionary]=[]
	var animated_base: Dictionary={}
	for prop in placeables:
		var appearance:=int(prop.fields.Appearance.value)
		if appearance==57 and animated_base.is_empty():animated_base=prop
		elif appearance in [7,8,9,10] and not prop_samples.any(func(other: Dictionary):return int(other.fields.Appearance.value)==appearance):prop_samples.append(prop)
	if creature_samples.is_empty() or prop_samples.is_empty() or animated_base.is_empty() or doors.is_empty():
		reject("Dense authored instances are missing");return {}
	var new_creatures:=48*density
	var skinned_creatures:=24*density
	var rigid_props:=192*density
	var animated_props:=48*density
	var real_doors:=48*density
	var stress:=density>=3
	var locations:=available_positions(git,density)
	var total:=new_creatures+rigid_props+animated_props+real_doors
	var moved_creatures:=0
	var moved_placeables:=0
	var roaming_creatures:=creature_samples.size()
	if area==AREAS[0]:
		# Keep the timed path independent of the server's random-walk choices.
		# The travel area retains the authored moving-NPC workload.
		for creature in creature_samples:pin_creature(creature)
		roaming_creatures=0
	if area==AREAS[0] or stress:
		moved_creatures=clear_entry_lane(creatures,locations,"XPosition","YPosition",stress)
		moved_placeables=clear_entry_lane(placeables,locations,"X","Y",stress)
	if locations.size()<total:
		reject("Insufficient free positions for the requested dense fixture scale");return {}
	var spawned:=0
	var open_doors:=0
	var mechanical_props:=0
	var prop_appearances: Dictionary={}
	var effect_appearances: Dictionary={}
	# Rotate families through positions so the route sees each kind of work.
	for index in rigid_props:
		var prop:=place_at(prop_samples[index%prop_samples.size()],locations[spawned],area+"_rigid_"+str(index),"X","Y")
		prop.fields.Useable.value=0
		prop.fields.Static.value=1 if index%2==0 else 0
		if stress:
			prop.fields.Appearance.value=STRESS_RIGID_APPEARANCES[index%STRESS_RIGID_APPEARANCES.size()]
			prop.fields.Bearing.value=float(index%8)*PI/4.0
			prop.fields.HasInventory.value=0
			prop.fields.erase("ItemList")
			prop_appearances[prop.fields.Appearance.value]=true
		placeables.append(prop);spawned+=1
		if index>=new_creatures:continue
		var attendant:=stress and index<ACTIVE_DOORS
		if attendant and not pair_attendant(locations,spawned,spawned+2):
			reject("No adjacent placements for a scripted door and its attendant");return {}
		var actor_tag:=area+("_door_actor_" if attendant else "_npc_")+str(index)
		var actor:=place_at(creature_samples[index%creature_samples.size()],locations[spawned],actor_tag,"XPosition","YPosition")
		# Keep added actors at reproducible positions, with their idle animations
		# active. The original authored cohort still uses its roaming scripts.
		pin_creature(actor)
		if index<skinned_creatures:
			actor.fields.Appearance_Type.value=SKINNED_APPEARANCES[index%SKINNED_APPEARANCES.size()]
		creatures.append(actor);spawned+=1
		var mechanical:=stress and index%3==0
		var effect_tag:=area+"_mech_"+str(mechanical_props) if mechanical else area+"_fx_"+str(index)
		var effect:=place_at(animated_base,locations[spawned],effect_tag,"X","Y")
		effect.fields.Appearance.value=BASE_EFFECT_APPEARANCES[index%BASE_EFFECT_APPEARANCES.size()]
		if stress:
			if mechanical:
				effect.fields.Appearance.value=STRESS_MECHANICAL_APPEARANCES[mechanical_props%STRESS_MECHANICAL_APPEARANCES.size()]
				# The original GIT states 4 and 5 select the on/off clip at admission.
				effect.fields.AnimationState.value=4 if mechanical_props%2==0 else 5
				mechanical_props+=1
			else:
				var ambient_index:=index-mechanical_props
				effect.fields.Appearance.value=STRESS_AMBIENT_APPEARANCES[ambient_index%STRESS_AMBIENT_APPEARANCES.size()]
			effect.fields.Bearing.value=float(index%8)*PI/4.0
			effect_appearances[effect.fields.Appearance.value]=true
		effect.fields.Useable.value=0
		effect.fields.Static.value=0
		placeables.append(effect);spawned+=1
		var door:=place_at(doors[index%doors.size()],locations[spawned],area+"_door_"+str(index),"X","Y")
		door.fields.Z.value=0.0
		door.fields.Bearing.value=float(index%4)*PI/2.0
		if attendant:
			var direction:=locations[spawned-2]-locations[spawned]
			door.fields.Bearing.value=direction.angle()+PI/2.0
		var open_state:=index%2
		if stress and index>=ACTIVE_DOORS and index%(2*doors.size())>=doors.size():
			open_state=1-open_state
		door.fields.AnimationState.value=open_state
		door.fields.Locked.value=0
		door.fields.TrapFlag.value=0
		open_doors+=int(door.fields.AnimationState.value)
		existing_doorway_rows.append(door);spawned+=1
	var census:={
		"addedCreatures":new_creatures,"addedSkinnedCreatures":skinned_creatures,"skinnedAppearances":SKINNED_APPEARANCES,
		"authoredRoamingCreatures":roaming_creatures,"laneRelocatedCreatures":moved_creatures,"laneRelocatedPlaceables":moved_placeables,
		"addedRigidNonInteractable":rigid_props,"addedBaseStatic":rigid_props/2,"addedAnimatedNonInteractable":animated_props,
		"addedOpenDoors":open_doors,"addedClosedDoors":real_doors-open_doors,
	}
	if stress:
		census["rigidAppearances"]=prop_appearances.size()
		census["effectAppearances"]=effect_appearances.size()
		census["addedMechanicalProps"]=mechanical_props
		census["addedAmbientProps"]=animated_props-mechanical_props
		census["scriptedDoors"]=ACTIVE_DOORS
		census["scriptedMechanicalProps"]=ACTIVE_MECHANISMS
	return census

func add_stress_scripts(resources: Dictionary)->void:
	for name in STRESS_EVENTS.values():
		var path: String="res://tools/dense-local-world/world/fixtures/"+name+".ncs"
		var compiled:=FileAccess.get_file_as_bytes(path)
		if compiled.size()<14 or compiled.slice(0,8).get_string_from_ascii()!="NCS V1.0" or compiled[8]!=0x42:
			reject("Invalid fixture script "+path);return
		resources[name+":2010"]=compiled

func attach_stress_events(are: Dictionary)->void:
	for event in STRESS_EVENTS:
		if not are.has(event) or int(are[event].type)!=11 or not str(are[event].value).is_empty():
			reject("Expected unused area event "+event);return
		are[event].value=STRESS_EVENTS[event]

func build(install: String,source_path: String,root_path: String,scale: String,port: int,density: int)->void:
	if scale not in ["smoke","dense"] or port<1024 or port>65535 or density<1 or density>4:reject("Invalid scale, UDP port, or density");return
	var archive:=Archives.new()
	var seed:=archive.erf(source_path)
	if seed.is_empty():reject("Dense source module: "+archive.failure);return
	var resources: Dictionary={}
	for key in seed.entries:
		var raw:=archive.payload(seed,seed.entries[key])
		if raw.is_empty():reject("Dense source resource "+key+": "+archive.failure);return
		resources[key]=raw
	var stress:=scale=="dense" and density>=3
	if stress:add_stress_scripts(resources)
	if not failure.is_empty():return
	var textures:=build_textures(root_path,install,scale=="smoke",stress)
	if not failure.is_empty() or textures.is_empty():return
	var module:=read_gff(resources.get("module:2014",PackedByteArray()),"IFO ")
	if not failure.is_empty():return
	module.Mod_Name=Gff.field(12,"Dense NWSync Benchmark")
	module.Mod_HakList=Gff.field(15,[Gff.record({"Mod_Hak":Gff.field(10,HAK)},0)])
	resources["module:2014"]=serialize_gff("IFO ",module)
	var doors: Array[Dictionary]=[]
	if scale=="dense":doors=get_prelude_doors(install)
	if not failure.is_empty():return
	var census: Dictionary={}
	for area in AREAS:
		var are:=read_gff(resources.get(area+":2012",PackedByteArray()),"ARE ")
		var git:=read_gff(resources.get(area+":2023",PackedByteArray()),"GIT ")
		if not failure.is_empty():return
		if stress:
			attach_stress_events(are)
			if not failure.is_empty():return
			resources[area+":2012"]=serialize_gff("ARE ",are)
		var added: Dictionary={}
		if scale=="smoke":
			git["Creature List"].value=git["Creature List"].value.slice(0,6)
			git["Placeable List"].value=git["Placeable List"].value.slice(0,12)
		else:
			added=populate_dense(git,doors,area,density)
			if not failure.is_empty():return
		var creatures: Array=git["Creature List"].value
		var placeables: Array=git["Placeable List"].value
		census[area]={"tiles":are.Tile_List.value.size(),"tileVariants":1,"creatures":creatures.size(),"placeables":placeables.size(),"doors":git["Door List"].value.size(),"triggers":git.TriggerList.value.size()}
		census[area].merge(added)
		resources[area+":2023"]=serialize_gff("GIT ",git)
	if not failure.is_empty():return
	var module_path:=root_path.path_join("server/modules/"+MODULE_NAME+".mod")
	var archive_path:=root_path.path_join("server/hak/"+HAK+".hak")
	if not write_archive(module_path,"MOD ",resources) or not write_archive(archive_path,"HAK ",textures):return
	var definition:={"format":"nwn-dense-local-world-v1","module":MODULE_NAME,"area":AREAS[0],"port":port,"spawn":SPAWN,"movementTarget":TARGET,"scale":scale,"densityMultiplier":density,"size":[10,10],"assets":synced,"tileModels":[SOURCE_MODEL],"density":census,"serverProfile":"server","moduleFile":"server/modules/"+MODULE_NAME+".mod","hakFile":"server/hak/"+HAK+".hak","moduleSha256":FileAccess.get_sha256(module_path),"hakSha256":FileAccess.get_sha256(archive_path),"serverVault":false,"sourceModuleSha256":FileAccess.get_sha256(source_path)}
	if scale=="dense":definition.routeClearance=STRESS_CLEARANCE if density>=3 else ROUTE_CLEARANCE
	if write_file(root_path.path_join("world.json"),(JSON.stringify(definition,"\t")+"\n").to_utf8_buffer()):
		print("DenseSync fixture generated "+str(synced.size())+" synced resources, "+str(census[AREAS[0]]))

func write_file(path: String,bytes: PackedByteArray)->bool:
	var file:=FileAccess.open(path,FileAccess.WRITE)
	if file==null:reject("Cannot write "+path);return false
	file.store_buffer(bytes);file.close()
	return true

func write_archive(path: String,kind: String,resources: Dictionary)->bool:
	var keys:=resources.keys();keys.sort()
	var result:=PackedByteArray()
	var keys_at:=160
	var locations_at:=keys_at+24*keys.size()
	var payload_at:=locations_at+8*keys.size()
	result.resize(payload_at)
	var tag: PackedByteArray=(kind+"V1.0").to_ascii_buffer()
	for index in tag.size():result[index]=tag[index]
	result.encode_u32(16,keys.size())
	result.encode_u32(20,keys_at)
	result.encode_u32(24,keys_at)
	result.encode_u32(28,locations_at)
	result.encode_u32(40,0xffffffff)
	for index in keys.size():
		var key: String=keys[index]
		var parts:=key.rsplit(":",true,1)
		var name:=parts[0].to_ascii_buffer()
		var bytes: PackedByteArray=resources[key]
		if name.is_empty() or name.size()>16 or bytes.is_empty():
			reject("Invalid archive row "+key);return false
		var entry:=keys_at+index*24
		for character in name.size():result[entry+character]=name[character]
		result.encode_u32(entry+16,index)
		result.encode_u16(entry+20,int(parts[1]))
		result.encode_u32(locations_at+index*8,payload_at)
		result.encode_u32(locations_at+index*8+4,bytes.size())
		result.append_array(bytes)
		payload_at+=bytes.size()
	if not write_file(path,result):return false
	var reader:=Archives.new()
	var reopened:=reader.erf(path)
	if reopened.get("entries",{}).size()!=keys.size():
		reject("Generated archive index: "+reader.failure);return false
	for key in keys:
		if not reopened.entries.has(key) or reader.payload(reopened,reopened.entries[key])!=resources[key]:
			reject("Generated archive payload differs for "+key);return false
	return true
