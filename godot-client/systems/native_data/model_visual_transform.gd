extends RefCounted
const VisualCurve=preload("res://systems/native_data/visual_curve.gd")
const POSE_CHANNELS := [0, 3, 4, 5, 6, 7, 8]
# A model instance owns each visual scope's ten mutable native curves.
var units: Dictionary={}
var scopes: Array=[]
var root_model: int=0
var scope_models: Dictionary={}
var external_scope_targets: Dictionary={}
var world_timer: Variant=null
var input_ref: Variant=null
var assigned:=false
var failure:=""
func configure(root_index: int,lookup: Dictionary,timer: Variant=null)->void:
	root_model=root_index;scope_models=lookup.duplicate();world_timer=timer
func unit(model_index: int,group: Node3D)->void:
	var channels: Array=[]
	for index in 10:channels.append(VisualCurve.identity(index))
	units[model_index]={"group":group,"base":group.transform,"pose":Transform3D.IDENTITY,"curves":channels,"scale":1.0,"constant_pose":true,"constant_transform":null}
static func _finite_number(value: Variant)->bool:
	return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value))
func assign(model_index: int,leaf: Variant)->void:
	failure=""
	if not units.has(model_index):return
	var channels: Array=[]
	var source: Array=[]
	if leaf!=null and (not leaf is Dictionary or not bool(leaf.get("identity",false))):
		if not leaf is Dictionary or not leaf.get("channels") is Array or leaf.channels.size()!=10:
			failure="Native visual transform channels are unavailable";push_error(failure);return
		source=leaf.channels
		for channel in source:
			if not channel is Dictionary:
				failure="Native visual transform channels are unavailable";push_error(failure);return
			for value in [channel.get("value"),channel.get("target",channel.get("value")),channel.get("parameter",0),channel.get("progress",0)]:
				if not _finite_number(value):
					failure="Native visual transform contains a non-finite channel";push_error(failure);return
	for index in 10:channels.append(VisualCurve.copy_channel(source[index],index,world_timer) if index<source.size() else VisualCurve.identity(index))
	var unit_row: Dictionary=units[model_index]
	unit_row.curves=channels
	unit_row.constant_transform=null
	unit_row.constant_pose=true
	for index in POSE_CHANNELS:
		if int(channels[index].kind)!=0:
			unit_row.constant_pose=false
			break
func assign_scope(scope: int,leaf: Variant)->bool:
	if external_scope_targets.has(scope):
		var target: Dictionary=external_scope_targets[scope]
		target.state.assign(int(target.model_index),leaf)
		if not str(target.state.failure).is_empty():failure=str(target.state.failure)
		return true
	var model: int=int(scope_models.get(scope,-1))
	if model<0:return false
	assign(model,leaf)
	return true
func sync(input: Variant)->void:
	if assigned and is_same(input,input_ref):return
	input_ref=input;assigned=true;failure=""
	var entries: Dictionary={}
	if input is Dictionary:
		if input.get("legacy")!=null:entries[0]=input.legacy
		else:
			for row in input.get("entries",[]):entries[int(row.key)]=row.value
	assign(root_model,entries.get(0,{"identity":true}))
	if not failure.is_empty():return
	var current: Array=[0]
	var keys: Array=entries.keys();keys.sort()
	for key in keys:
		var scope:=int(key)
		if scope==0 or scope>=256:continue
		if assign_scope(scope&255,entries[key]):current.append(scope)
		if not failure.is_empty():return
	for key in scopes:
		if current.has(key):continue
		assign_scope(int(key)&255,{"identity":true})
		if not failure.is_empty():return
	scopes=current
	update()
func speed(model_index: int)->float:
	if not units.has(model_index):return 1.0
	return VisualCurve.sample(units[model_index].curves[9],world_timer)
static func native_quaternion(yaw: float,pitch: float,roll: float)->Quaternion:
	var q: Array[float]=[1.0,0.0,0.0,0.0]
	for value in [[yaw,3],[pitch,1],[roll,2]]:
		if float(value[0])==0.0:continue
		var a:=VisualCurve.f(VisualCurve.f(VisualCurve.f(float(value[0]))*VisualCurve.f(0.017453292))*0.5)
		var r: Array[float]=[VisualCurve.f(cos(a)),0.0,0.0,0.0]
		r[int(value[1])]=VisualCurve.f(sin(a))
		var w:=q[0];var x:=q[1];var y:=q[2];var z:=q[3]
		q=[VisualCurve.f(VisualCurve.f(VisualCurve.f(VisualCurve.f(w*r[0])-VisualCurve.f(x*r[1]))-VisualCurve.f(y*r[2]))-VisualCurve.f(z*r[3])),
			VisualCurve.f(VisualCurve.f(VisualCurve.f(VisualCurve.f(x*r[0])+VisualCurve.f(w*r[1]))+VisualCurve.f(y*r[3]))-VisualCurve.f(z*r[2])),
			VisualCurve.f(VisualCurve.f(VisualCurve.f(VisualCurve.f(w*r[2])-VisualCurve.f(x*r[3]))+VisualCurve.f(y*r[0]))+VisualCurve.f(z*r[1])),
			VisualCurve.f(VisualCurve.f(VisualCurve.f(VisualCurve.f(x*r[2])+VisualCurve.f(w*r[3]))-VisualCurve.f(y*r[1]))+VisualCurve.f(z*r[0]))]
	return Quaternion(q[1],q[3],-q[2],q[0])
func update()->bool:
	var evaluated:=false
	for unit_row in units.values():
		var group: Variant=unit_row.group
		var constant_transform: Variant=unit_row.constant_transform
		if constant_transform!=null:
			# Attachment or rig updates can also write to this owner.
			if is_instance_valid(group) and group.transform!=constant_transform:
				group.transform=constant_transform
			continue
		var curves: Array=unit_row.curves
		var z: float=VisualCurve.sample(curves[8],world_timer)
		var y: float=VisualCurve.sample(curves[7],world_timer)
		var x: float=VisualCurve.sample(curves[6],world_timer)
		var rz: float=VisualCurve.sample(curves[5],world_timer)
		var ry: float=VisualCurve.sample(curves[4],world_timer)
		var rx: float=VisualCurve.sample(curves[3],world_timer)
		var scale_value: float=VisualCurve.sample(curves[0],world_timer)
		if not is_instance_valid(group):continue
		var pose:=Transform3D(Basis(native_quaternion(rx,ry,rz)).scaled(Vector3.ONE*scale_value),Vector3(x,z,-y))
		var transform: Transform3D=unit_row.base*pose
		group.transform=transform
		unit_row.pose=pose
		unit_row.scale=scale_value
		evaluated=true
		if unit_row.constant_pose:
			unit_row.constant_transform=transform
	return evaluated
func dispose()->void:
	units.clear();scopes.clear();scope_models.clear();external_scope_targets.clear();world_timer=null;input_ref=null;assigned=false;failure=""
