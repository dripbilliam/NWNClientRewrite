extends "res://tests/native_nameplate_source_test.gd"
const ModelPlan=preload("res://systems/native_data/nameplate_model.gd")
const ActorModel=preload("res://systems/native_data/actor_model.gd")
const Bubble=preload("res://systems/native_data/radial_text.gd")
func source_checks(plate,catalog) -> void:
	var source=plate.source; var portrait: Dictionary=source.plans.but_popup_prtrt
	var photo: Dictionary=portrait.parts.filter(func(row):return row.resource=="gui_replace01")[0]
	var frame: Dictionary=portrait.parts.filter(func(row):return row.resource=="gui_boxes")[0]
	check(photo.bounds.position.distance_to(Vector2(1,4))<0.001 and photo.bounds.size.distance_to(Vector2(16,25))<0.001 and frame.bounds.position.distance_to(Vector2(0,3))<0.001 and frame.bounds.size.distance_to(Vector2(18,27))<0.001,"Original popup portrait and frame dimensions/offsets remain unscaled")
	check(portrait.parts[0].resource=="gui_boxes" and portrait.parts[1].resource=="gui_replace01" and photo.depth>frame.depth,"Original portrait depth paints the frame behind the photograph")
	check(portrait.hooks.textindent.distance_to(Vector2(23,0))<0.001 and plate.caption.position.x==portrait.hooks.textindent.x and plate.caption.size.x==plate.size.x-24,"Actual plate uses the original textindent hook and24px width reservation")
	check(plate.portrait.texture==null and plate.portrait.size.distance_to(Vector2(16,25))<0.001 and plate.portrait.faces.size()==2,"Native control owns the two original portrait triangles pending raw raster delivery")
	check(plate.placeholder.visible and not plate.backdrop.raster_ready() and plate.backdrop.parts.size()==1 and plate.backdrop.parts.values()[0].faces.size()>=6,"Original backdrop geometry does not remove its readable placeholder before the bitmap arrives")
	var background:=ImageTexture.create_from_image(Image.create(32,32,false,Image.FORMAT_RGBA8))
	plate.art.deliver("gui_textbubble",background)
	check(not plate.placeholder.visible and plate.backdrop.raster_ready(),"Actual raw bitmap publication replaces the temporary rectangle without another model preparation")
	var before: int=source.assets.serial; var binding: int=plate.art.binding_serial
	for index in 100: plate.refresh_source()
	check(source.assets.serial==before and plate.art.binding_serial==binding,"Repeated source refresh shares prepared meshes and does not enqueue raster/model work")
	var image_jobs: int=plate.art.assets.serial; var listeners: int=source.loaded.get_connections().size()
	var other=preload("res://systems/native_nameplate.gd").new(); plate.get_parent().add_child(other); other.configure(plate.art,plate.fonts,source); other.set_content(plate.data.duplicate(true))
	check(other.source==source and other.backdrop.plan==plate.backdrop.plan and source.assets.serial==before and plate.art.assets.serial==image_jobs,"A second visible plate shares model preparation and pending native rasters without another worker/request owner")
	check(not other.placeholder.visible and other.backdrop.raster_ready(),"A second plate binds the cached original background immediately")
	check(source.loaded.get_connections().size()==listeners+1 and other.portrait_frame.parts.size()==2,"Each plate owns passive drawing controls while sharing the prepared source")
	var photo_control=other.portrait; var hidden: Dictionary=other.data.duplicate(true); hidden.portrait=""; other.set_content(hidden)
	check(not other.portrait_frame.visible and photo_control.texture==null,"Removing portrait disclosure releases the hidden plane's pending raster binding immediately")
	var late:=ImageTexture.create_from_image(Image.create(32,64,false,Image.FORMAT_RGBA8)); plate.art.deliver(plate.portrait_key,late)
	check(photo_control.texture==null and plate.portrait.texture==late,"A late shared raster populates the still-disclosed plate and cannot refill the hidden photograph")
	other.close(); other.queue_free()
	check(source.loaded.get_connections().size()==listeners and not source.closed and plate.portrait!=null and other.portrait==null,"Retiring one plate disconnects its source listener without retiring other plates or the shared preparation owner")
	for row in Bubble.BUBBLES:
		var parser:=ActorModel.new(); var model:=parser.parse(catalog.get_resource(str(row[2]),2002)); var plan:=ModelPlan.parse(model)
		check(parser.failure.is_empty() and plan.error.is_empty() and plan.parts.size()==1 and plan.parts[0].resource=="gui_textbubble","Actual original bubble variant compiles "+str(row[2]))
		if not plan.error.is_empty(): continue
		check(plan.bounds.position.distance_to(Vector2(-15,-5))<0.001 and plan.bounds.size.distance_to(Vector2(float(row[0])+30,float(row[1])+10))<0.001,"Original bubble endcap/edge extents stay outside its logical text bounds "+str(row[2]))
	var font: Font=plate.caption.get_theme_font("normal_font"); var font_size: int=plate.caption.get_theme_font_size("normal_font_size")
	var ordinary:=Bubble.choose(font,font_size,"Short")
	var member:=Bubble.choose(font,font_size,"Short",2,24)
	check(float(member[1])>=font.get_height(font_size)*2 and float(member[0])-24>0 and ordinary==Bubble.choose(font,font_size,"Short",1,0),"Nameplate minimum-line/portrait policy leaves ordinary radial choice unchanged")
	var empty_model: Dictionary=ModelPlan.parse({"nodes":[{"name":"root","parent":-1,"position":[0,0,0],"orientation":[0,0,0,1],"scale":1}]})
	check(empty_model.error.is_empty() and empty_model.parts.is_empty(),"Empty source geometry cannot fabricate a visible replacement mesh")
