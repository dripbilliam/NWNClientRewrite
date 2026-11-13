extends RefCounted
# Authored canonical rows and camera pose seam only. Production Controls,
# original font/mesh/raster owners and popup arbitration stay unmodified.
class Desktop extends Node:
	var art
	var state:={"players":[]}
	func close()->void:pass
class VisualRows extends RefCounted:
	var entities: Dictionary={}
static func row(id: int,name: String,native_life: int,known_life: int)->Dictionary:
	return {"id":id,"objectType":5,"areaId":91,"nativeLifetime":native_life,"clientKnownLifetime":known_life,"replicated":{"name":{"text":name},"portraitRef":"po_hu_m_01","damageLevel":0,"reaction":1}}
static func message(row_value: Dictionary,serial: int,body: String,connection: int=3,generation: int=7)->Dictionary:
	var source:={"id":row_value.id,"objectType":5,"areaId":row_value.areaId,"nativeLifetime":row_value.nativeLifetime,"knownLifetime":row_value.clientKnownLifetime}
	return {"type":"server-speech","channel":1,"objectId":row_value.id,"text":{"text":body},"nativeTextEvent":{"version":1,"serial":serial,"connection":connection,"generation":generation,"areaId":row_value.areaId,"source":source}}
static func readings(fonts,resources,art,hud,speech_owner)->Dictionary:
	var layouts: Dictionary={}
	for id in hud.nameplates:layouts["hover"+str(id)]=hud.nameplates[id].layouts
	for id in speech_owner.views:layouts["speech"+str(id)]=speech_owner.views[id].layouts
	return {"fonts":fonts.snapshot(),"fontJobs":fonts.assets.serial,"modelJobs":resources.assets.serial,"imageJobs":art.assets.serial,"imageBindings":art.binding_serial,"layouts":layouts}
static func raster_ready(view)->bool:
	# Replacement keeps the previous prepared plan while the newly selected
	# bubble is loading. Its old raster is not readiness for the new model.
	return is_instance_valid(view) and view.layout_ready and view.backdrop.resource==view.bubble_resource and view.backdrop.visible and view.backdrop.raster_ready() and (not view.portrait_frame.visible or view.portrait_frame.raster_ready())
static func backdrop_state(view)->Dictionary:
	var parts: Array=[]
	for key in view.backdrop.parts:
		var part=view.backdrop.parts[key]
		parts.append({"id":str(key),"textureReady":part.texture!=null,"alpha":part.alpha,"faces":part.faces.size()})
	return {"wanted":view.bubble_resource,"installed":view.backdrop.resource,"visible":view.backdrop.visible,"rasterReady":view.backdrop.raster_ready(),"parts":parts}

