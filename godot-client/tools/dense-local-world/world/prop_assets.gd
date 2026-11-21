extends RefCounted

const ActorModel=preload("res://systems/native_data/actor_model.gd")
const Table=preload("res://systems/native_data/two_da.gd")
const MODELS={57:"plc_i05",64:"plc_j02",65:"plc_j03",66:"plc_j04"}
const SURFACES={
	"plc_rugdmtlbrk":{"appearance":57,"color":Color8(117,55,43)},
	"plc_creats":{"appearance":65,"color":Color8(59,103,98)},
	"plc_crpsbksrp":{"appearance":66,"color":Color8(155,115,61)},
	"plc_trans":{"appearance":57,"color":Color8(123,161,187)},
}
const PARTICLES={
	"fxpa_flame00":{"appearance":57,"grid":Vector2i(4,4),"color":Color8(252,143,38),"shape":"flame"},
	"fxpa_ripple":{"appearance":64,"grid":Vector2i(2,2),"color":Color8(66,161,238),"shape":"ripple"},
	"fxpa_splash":{"appearance":64,"grid":Vector2i(1,1),"color":Color8(111,198,241),"shape":"splash"},
	"plc_test":{"appearance":64,"grid":Vector2i(1,1),"color":Color8(88,169,202),"shape":"jet"},
}
const SIZE:=128

static func build(catalog: RefCounted)->Dictionary:
	var parser:=Table.new()
	var table:=parser.parse(catalog.get_resource("placeables",2017).get_string_from_utf8())
	if table.is_empty():return failed("Could not read installed placeable model table: "+parser.failure)
	var models: Dictionary={}
	for appearance in MODELS:
		var source: Dictionary=table.rows.get(appearance,{})
		var model_name:=str(source.get("ModelName","")).to_lower()
		if model_name!=MODELS[appearance]:return failed("Unexpected installed model for fixture placeable %d" % appearance)
		var model_parser:=ActorModel.new()
		var model:=model_parser.parse(catalog.get_resource(model_name,2002))
		if model.is_empty():return failed("Could not read fixture placeable model "+model_name+": "+model_parser.failure)
		models[appearance]=model.nodes
	var assets: Array[Dictionary]=[]
	for resref in SURFACES:
		var spec: Dictionary=SURFACES[resref]
		if not has_bitmap(models[spec.appearance],resref):return failed("Fixture prop has no rendered surface bitmap "+resref)
		assets.append({"resref":resref,"ext":"tga","role":"prop-texture","bytes":surface(spec.color,resref=="plc_trans")})
	for resref in PARTICLES:
		var spec: Dictionary=PARTICLES[resref]
		if not has_emitter_bitmap(models[spec.appearance],resref,spec.grid):return failed("Fixture prop has no emitter atlas "+resref)
		assets.append({"resref":resref,"ext":"tga","role":"prop-particle-texture","bytes":particle(spec.color,spec.grid,spec.shape)})
	return {"assets":assets,"error":""}

static func failed(reason: String)->Dictionary:
	return {"assets":[],"error":reason}

static func has_bitmap(nodes: Array,resref: String)->bool:
	for node in nodes:
		var mesh: Dictionary=node.get("mesh",{})
		if not bool(mesh.get("render",false)) or mesh.get("indices",[]).size()<3:continue
		for name in mesh.get("textures",[]):
			if str(name).to_lower()==resref:return true
	return false

static func has_emitter_bitmap(nodes: Array,resref: String,grid: Vector2i)->bool:
	for node in nodes:
		var emitter: Dictionary=node.get("emitter",{})
		if str(emitter.get("texture","")).to_lower()!=resref:continue
		if Vector2i(int(emitter.get("xgrid",0)),int(emitter.get("ygrid",0)))==grid:return true
	return false

static func tga_buffer()->PackedByteArray:
	var bytes:=PackedByteArray()
	bytes.resize(18+SIZE*SIZE*4)
	bytes[2]=2
	bytes.encode_u16(12,SIZE)
	bytes.encode_u16(14,SIZE)
	bytes[16]=32
	bytes[17]=40
	return bytes

static func surface(color: Color,transparent: bool)->PackedByteArray:
	var bytes:=tga_buffer()
	for y in SIZE:
		for x in SIZE:
			var pixel:=18+(y*SIZE+x)*4
			var noise:=((x*821+y*199) ^ (x*y*61)) % 31
			var checker:=((x>>4)+(y>>4))%2
			var seam:=x%16<2 or y%16<2
			var shade:=noise+checker*33-29 if not seam else -45
			bytes[pixel]=clampi(color.b8+shade,0,255)
			bytes[pixel+1]=clampi(color.g8+shade,0,255)
			bytes[pixel+2]=clampi(color.r8+shade,0,255)
			var alpha:=255
			if transparent:
				if seam:alpha=135
				elif checker==1:alpha=48+noise*2
				else:alpha=0
			bytes[pixel+3]=alpha
	return bytes

static func particle(color: Color,grid: Vector2i,shape: String)->PackedByteArray:
	var bytes:=tga_buffer()
	var cell_size:=Vector2i(SIZE/grid.x,SIZE/grid.y)
	var frame_count:=grid.x*grid.y
	for y in SIZE:
		for x in SIZE:
			var pixel:=18+(y*SIZE+x)*4
			var frame:=floori(float(y)/cell_size.y)*grid.x+floori(float(x)/cell_size.x)
			var phase:=float(frame)/float(frame_count)
			var point:=Vector2((float(x%cell_size.x)+0.5)/cell_size.x,(float(y%cell_size.y)+0.5)/cell_size.y)*2.0-Vector2.ONE
			var alpha:=coverage(point,phase,shape)
			bytes[pixel]=roundi(float(color.b8)*alpha)
			bytes[pixel+1]=roundi(float(color.g8)*alpha)
			bytes[pixel+2]=roundi(float(color.r8)*alpha)
			bytes[pixel+3]=roundi(255.0*alpha)
	return bytes

static func coverage(point: Vector2,phase: float,shape: String)->float:
	var taper:=smoothstep(0.0,0.18,1.0-maxf(absf(point.x),absf(point.y)))
	var pattern:=0.0
	match shape:
		"flame":
			var width:=lerpf(0.27,0.69,(point.y+1.0)*0.5)
			var drift:=sin(phase*TAU+point.y*3.0)*0.14
			pattern=1.0-absf(point.x-drift)/width-absf(point.y)*0.46
		"ripple":
			pattern=1.0-absf(point.length()-lerpf(0.38,0.8,phase))*10.0
		"splash":
			pattern=1.0-Vector2(point.x*1.8,point.y+absf(point.x)*0.53).length()
		"jet":
			pattern=1.0-Vector2(point.x*3.4,point.y*1.1).length()
	return smoothstep(0.0,0.75,pattern)*taper
