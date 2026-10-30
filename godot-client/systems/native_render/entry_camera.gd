extends RefCounted
# Presentation-only bootstrap from the server entry/controlled position. It
# creates no actor, movement, authority or fabricated gameplay readiness.
var anchored:=false
func anchor(camera: Camera3D,controller,position: Vector3,memory: Dictionary={}) -> bool:
	if anchored or not position.is_finite(): return false
	camera.position=position+Vector3(10,14,10); camera.look_at(position)
	controller.configure(camera,position); controller.enable_follow(1,position,1.0,memory)
	anchored=true; return true
