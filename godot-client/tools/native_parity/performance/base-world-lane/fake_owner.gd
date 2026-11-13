extends RefCounted
var objects: Dictionary={}
var forgotten: Array=[]
func forget(id: int,_all: bool=false) -> void:forgotten.append(id)
func observe(id: int,state: Dictionary,_created: bool,_initial: Dictionary) -> void:objects[id]=state
