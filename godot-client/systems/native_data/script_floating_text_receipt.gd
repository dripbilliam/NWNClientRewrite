extends RefCounted
# One detached body snapshot serves native script feedback's independent log
# and its separately scoped widget. No object lookup or presentation admission.
const Markup=preload("res://systems/native_data/script_floating_markup.gd")
const Rich=preload("res://systems/native_data/rich_text.gd")
const Frame=preload("res://systems/native_data/script_floating_frame.gd")
static func capture(type: int,payload: Variant,target: int,show: bool,prefix: String,text) -> Dictionary:
	var receipt:={"type":type,"target":target,"payload":payload.duplicate(true) if payload is Dictionary else payload,"showChat":show,"prefix":prefix,"bodyReady":false,"logged":false,"model":{},"tokenSnapshot":text.custom_tokens.duplicate(true) if type==93 and is_instance_valid(text) else {}}
	snapshot_raw(receipt,text)
	return receipt
static func snapshot_raw(receipt: Dictionary,text) -> void:
	if int(receipt.type)!=93 or receipt.has("rawSnapshot") or not is_instance_valid(text):return
	var fetched: Dictionary=text.fetch_native_reference(int(receipt.payload)&4294967295,0)
	if fetched.get("found",false):receipt.rawSnapshot=str(fetched.get("text",""))
static func prepare(receipt: Dictionary,text) -> Dictionary:
	if receipt.get("bodyReady",false):return {"ready":true}
	var body: String
	if int(receipt.type)==94:body=str(receipt.payload.text) if receipt.payload is Dictionary else str(receipt.payload)
	else:
		if not is_instance_valid(text):return {"ready":false,"pending":true}
		snapshot_raw(receipt,text)
		if not receipt.has("rawSnapshot"):return {"ready":false,"pending":true}
		if Markup.requires_named_tokens(str(receipt.rawSnapshot)) and text.get("named_ready")!=true:return {"ready":false,"pending":true}
		var parsed: Dictionary=text.parse_native(str(receipt.rawSnapshot),{"context":{},"gender":0,"nativeB8":0,"nativeBC":0,"localCustomTokens":receipt.tokenSnapshot,"localCustomTokensComplete":true})
		if not parsed.get("ready",false):return parsed
		body=str(parsed.body)
	var program:=Markup.compile(body)
	if not program.get("ready",false):return program
	receipt.bodyReady=true;receipt.body=body
	receipt.model={"raw":body,"program":program,"font":"ttf fnt_maintext 17","rgb":Color.WHITE,"shadow":false,"depth":Frame.DEPTH}
	return {"ready":true}
static func take_log(receipt: Dictionary) -> Dictionary:
	if not receipt.get("bodyReady",false) or receipt.get("logged",false):return {}
	receipt.logged=true
	if not receipt.showChat or str(receipt.body).is_empty():return {}
	var prefix: String=receipt.prefix if not str(receipt.prefix).is_empty() else "<c"+String.chr(255)+String.chr(255)+String.chr(1)+">"
	var rendered: String=receipt.model.program.rendered
	return {"system":true,"category":"script-feedback","type":receipt.type,"flags":128,"chat_mask":128,"rich":Rich.parse(prefix+rendered+"</c>"),"text":Rich.parse(rendered).text,"raw":prefix+str(receipt.body)+"</c>"}
