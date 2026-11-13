'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');const root=path.resolve(__dirname,'../..'),arg=n=>process.argv.find(x=>x.startsWith('--'+n+'='))?.slice(n.length+3),label=arg('label'),sha=b=>crypto.createHash('sha256').update(b).digest('hex');if(!label||!/^[a-z0-9-]+$/.test(label))throw Error('Fresh label required');const output=path.join(root,'.cache/nwn71/presentation-source-'+label);if(fs.existsSync(output))throw Error('Preserve existing candidate');const original='systems/native_loading_screen.gd',bytes=fs.readFileSync(path.join(root,original));let text=bytes.toString().replace(/\r\n/g,'\n');function one(before,after){assert.equal(text.split(before).length,2,'Unique overlay seam differs');text=text.replace(before,after);}
one('extends CanvasLayer','extends CanvasLayer\nconst PresentationFence=preload("res://tests/nwn71_presentation_fence.gd")\nvar presentation_fence:=PresentationFence.new()\nvar presentation_source: WeakRef\nvar presentation_pending:=false\nvar presentation_values: Dictionary={}\nvar presentation_stats:={"requested":0,"completed":0,"aborted":0,"unconfigured":0,"elapsed_ms":0.0}\nvar presentation_started_us:=0\nvar presentation_test_dispatch: Callable\nvar presentation_test_signal: Signal\nvar presentation_mouse_modes: Array=[]');
one('func begin(generation: int,area: String,entry: Dictionary={}) -> void:\n','func begin(generation: int,area: String,entry: Dictionary={}) -> void:\n\tpresentation_fence.cancel();presentation_pending=false;presentation_values={};presentation_restore_mouse()\n');
one('func advance(generation: int,values: Dictionary) -> void:\n','func advance(generation: int,values: Dictionary) -> void:\n\tif generation==epoch and presentation_pending:presentation_values=values.duplicate(true)\n');
one('modal_lease.retire();active=false; veil.hide()','modal_lease.retire();active=false; finish_presentation()');
one('if active and not dismissed: modal_lease.retire();dismissed=true;','if active and not dismissed: presentation_fence.cancel();presentation_pending=false;modal_lease.retire();dismissed=true;');
one('func reset() -> void:\n','func reset() -> void:\n\tpresentation_fence.cancel();presentation_pending=false;presentation_values={};presentation_restore_mouse()\n');
one('func _exit_tree() -> void:modal_lease.close()','func _exit_tree() -> void:presentation_fence.close();modal_lease.close()');
one('func snapshot() -> Dictionary:\n\tvar result:=stats.duplicate(true);','func snapshot() -> Dictionary:\n\tvar result:=stats.duplicate(true); result["nwn71_presentation"]=presentation_snapshot();');
text+=`
# PRIVATE presentation-only candidate: canonical active/blocks_input completion
# and ACK/world control readiness stay at their original point. Only veil hide
# waits for a normal completed render; no force_draw/force_sync in this path.
func set_presentation_source(owner: Object) -> void:
	presentation_source=weakref(owner)
func finish_presentation() -> void:
	if dismissed:veil.hide();return
	var source=presentation_source.get_ref() if presentation_source!=null else null
	var target=source.get("world") if is_instance_valid(source) else null
	if not is_instance_valid(target):presentation_stats.unconfigured+=1;veil.hide();return
	presentation_values=milestones.duplicate(true);presentation_pending=true;presentation_started_us=Time.get_ticks_usec();presentation_ignore_mouse(veil)
	if presentation_fence.request(self,target,epoch,Callable(self,"presentation_ready"),Callable(self,"presentation_completed"),Callable(self,"presentation_aborted"),presentation_test_dispatch,presentation_test_signal):presentation_stats.requested+=1
	else:presentation_pending=false;veil.hide();presentation_restore_mouse()
func presentation_ready(target: Object,generation: int) -> bool:
	var source=presentation_source.get_ref() if presentation_source!=null else null
	if not presentation_pending or generation!=epoch or active or dismissed or not error.is_empty() or not is_instance_valid(source) or not is_instance_valid(target):return false
	if source is Node and source.is_queued_for_deletion():return false
	if bool(source.get("closing")) or int(source.get("epoch"))!=epoch or source.get("world")!=target or source.get("loading_screen")!=self:return false
	if bool(target.get("closed")) or bool(target.get("retiring")) or int(target.get("generation"))!=epoch or not target.ready_for_control():return false
	if target is Node3D and not target.is_visible_in_tree():return false
	return bool(presentation_values.get("terrain",false)) and bool(presentation_values.get("player",false)) and bool(presentation_values.get("camera",false)) and presentation_values.get("errors",[]).is_empty()
func presentation_completed(target: Object,generation: int) -> void:
	if not presentation_ready(target,generation):return
	presentation_pending=false;presentation_stats.completed+=1;presentation_stats.elapsed_ms=(Time.get_ticks_usec()-presentation_started_us)/1000.0;veil.hide();presentation_restore_mouse()
func presentation_aborted(_target: Object,generation: int,_reason: String) -> void:
	if generation!=epoch or not presentation_pending:return
	presentation_pending=false;presentation_stats.aborted+=1
	# Canonical readiness already completed at the legacy point. An invalid
	# presentation candidate must not strand its old cover or reopen gameplay.
	if not active:veil.hide()
	presentation_restore_mouse()
func presentation_ignore_mouse(node: Node) -> void:
	if node is Control:
		presentation_mouse_modes.append([weakref(node),node.mouse_filter]);node.mouse_filter=Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():presentation_ignore_mouse(child)
func presentation_restore_mouse() -> void:
	for pair in presentation_mouse_modes:
		var control=pair[0].get_ref()
		if is_instance_valid(control):control.mouse_filter=int(pair[1])
	presentation_mouse_modes.clear()
func presentation_snapshot() -> Dictionary:
	return {"pending":presentation_pending,"stats":presentation_stats.duplicate(),"fence":presentation_fence.snapshot()}
`;
for(const [file,data] of [['before/systems/native_loading_screen.gd',bytes],['after/tests/nwn71_loading_screen_candidate.gd',Buffer.from(text)]]){const target=path.join(output,file);fs.mkdirSync(path.dirname(target),{recursive:true});fs.writeFileSync(target,data,{flag:'wx'});}const helper='tests/nwn71_presentation_fence.gd';const receipt={schema:'nwn71-private-presentation-source-v1',baseline:{file:original,sha256:sha(bytes)},candidate:{file:path.relative(root,path.join(output,'after/tests/nwn71_loading_screen_candidate.gd')).replaceAll('\\','/'),sha256:sha(Buffer.from(text))},helper:{file:helper,sha256:sha(fs.readFileSync(path.join(root,helper)))},sharedEdits:0,scope:'Private overlay copy only; only veil visibility is fenced, canonical active/blocks_input/stats/history andprotocol gates unchanged. Normal frame fence, noforcedraw/sync.'};fs.writeFileSync(path.join(output,'source-receipt.json'),JSON.stringify(receipt,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify(receipt));
