"""Prepare immutable accepted24 code with fixed teardown timings/two warm cycles."""
from pathlib import Path
import datetime, difflib, hashlib, json

ROOT=Path(__file__).resolve().parents[1];PROJECT=ROOT/'godot-client'
SOURCE=PROJECT/'.cache/pregame-navigation-tests/20261103-071737-263b2ac4'
r=json.loads((SOURCE/'runner.json').read_text(encoding='utf-8-sig'))
assert r['success'] and r['checks']==24 and len(r['staticClosure'])==571
destination=PROJECT/'.cache/pregame-navigation-diagnostics'/(datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%d-%H%M%S')+'-teardown')
copy=destination/'project';copy.mkdir(parents=True,exist_ok=False)
sha=lambda b:hashlib.sha256(b).hexdigest()
for row in r['inputs']:
    source=SOURCE/'project'/row['path'];data=source.read_bytes();assert sha(data)==row['sha256'],row['path']
    target=copy/row['path'];target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(data)
originals={}
def change(relative,convert):
    path=copy/relative;before=path.read_text();after=convert(before)
    assert before!=after,relative
    originals[relative]=before;path.write_text(after,encoding='utf-8')
def reset_timing(text):
    begin=text.index('func reset_session() -> void:');end=text.index('func application_exit_policy()',begin)
    body=text[begin:end]
    injected=['\tvar diag_begin: int=Time.get_ticks_usec();var diag_mark: int=diag_begin;var diag_phases: Array=[];var diag_ui=gameplay_ui;var diag_had_world: bool=is_instance_valid(world)\n']
    body=body.replace('func reset_session() -> void:\n','func reset_session() -> void:\n'+injected[0],1)
    anchors=[('identity_and_diagnostics','\tsave_last_seen_appearance()\n'),
             ('chooser','\tif is_instance_valid(character_lobby): character_lobby.close_native()\n'),
             ('cache_and_pending','\tloading_announced=false\n'),
             ('windows','\tif is_instance_valid(render_menu): render_menu.dismiss(); render_menu.detach_native()\n'),
             ('catalog_loader','\tif is_instance_valid(keyboard): keyboard.stop(false)\n'),
             ('input','\tif is_instance_valid(world_input): world_input.process_mode=Node.PROCESS_MODE_DISABLED\n'),
             ('gameplay_ui','\tif is_instance_valid(gameplay_ui): gameplay_ui.close()\n')]
    for phase,anchor in anchors:
        assert body.count(anchor)==1,(phase,anchor)
        marker=f'\tdiag_phases.append({{"phase":"{phase}","usec":Time.get_ticks_usec()-diag_mark}});diag_mark=Time.get_ticks_usec()\n'
        # Catalog loader ends before keyboard retirement, so time its prefix.
        body=body.replace(anchor,marker+anchor if phase=='catalog_loader' else anchor+marker,1);injected.append(marker)
    final='\tdiag_phases.append({"phase":"world_and_references","usec":Time.get_ticks_usec()-diag_mark})\n\tif not report.has("pregame_reset_timings"):report.pregame_reset_timings=[]\n\tif report.pregame_reset_timings.size()<32:report.pregame_reset_timings.append({"connection":session_connection,"at_usec":diag_begin,"total_usec":Time.get_ticks_usec()-diag_begin,"had_ui":is_instance_valid(diag_ui),"had_world":diag_had_world,"phases":diag_phases,"ui_close":diag_ui.diagnostic_close_trace.duplicate(true) if is_instance_valid(diag_ui) else []})\n'
    body=body+final;injected.append(final)
    stripped=body
    for marker in injected:stripped=stripped.replace(marker,'',1)
    assert stripped==text[begin:end],'Instrumentation reordered reset behavior'
    return text[:begin]+body+text[end:]
def close_timing(text):
    declaration='var diagnostic_close_trace: Array=[]\n';text=text.replace('extends CanvasLayer\n','extends CanvasLayer\n'+declaration,1) if text.startswith('extends CanvasLayer\n') else text.replace('extends Node\n','extends Node\n'+declaration,1)
    assert declaration in text
    begin=text.index('func close() -> void:');end=text.index('func _exit_tree()',begin)
    original=text[begin:end];body=original;injected=[]
    marker='\tvar diag_mark: int=Time.get_ticks_usec();diagnostic_close_trace.clear()\n'
    body=body.replace('\tif closed: return\n','\tif closed: return\n'+marker,1);injected.append(marker)
    for line in original.splitlines(True):
        if line.startswith('\tif is_instance_valid(') and ('.close()' in line or '.close_modal_owner()' in line):
            owner=line.split('(',1)[1].split(')',1)[0]
            before='\tdiag_mark=Time.get_ticks_usec()\n';after=f'\tdiagnostic_close_trace.append({{"owner":"{owner}","usec":Time.get_ticks_usec()-diag_mark}})\n'
            body=body.replace(line,before+line+after,1);injected.extend([before,after])
    first='\tclosed=true; world_camera_yaw=Callable(); clear_floating()\n'
    assert body.count(first)==1
    before='\tdiag_mark=Time.get_ticks_usec()\n';after='\tdiagnostic_close_trace.append({"owner":"retire_floating","usec":Time.get_ticks_usec()-diag_mark})\n'
    body=body.replace(first,before+first+after,1);injected.extend([before,after])
    tail=['text.close()','table_jobs.clear()','portrait_jobs.clear()','examine_jobs.clear()','examine_pending.clear()','examine_message.clear()','queue.clear()','pool.clear()','catalog=null']
    for statement in tail:
        assert body.count(statement)==1,statement
        before='diag_mark=Time.get_ticks_usec();';after=f';diagnostic_close_trace.append({{"owner":"{statement}","usec":Time.get_ticks_usec()-diag_mark}})'
        body=body.replace(statement,before+statement+after,1);injected.extend([before,after])
    stripped=body
    for marker in injected:stripped=stripped.replace(marker,'',1)
    assert stripped==original,'Instrumentation reordered close behavior'
    return text[:begin]+body+text[end:]
change('native_session_world.gd',reset_timing)
change('systems/native_gameplay_ui.gd',close_timing)
def warm_fixture(text):
    helper='''func warm_disconnect_cycle(quiescent: bool) -> bool:
	receive({"kind":"browser-closed","connection":session_connection});var joined: Dictionary=selection_view();joined.connection=session_connection+1;receive(joined)
	if not check(await await_flow(func():return is_instance_valid(character_lobby.native_chooser) and character_lobby.native_chooser.art_ready()),"Warm cycle actual source chooser prepares"):return false
	actual_gameplay_owner();await click(character_lobby.native_chooser.buttons.newcharbutton)
	if not check(await await_flow(func():return gameplay_ui.creator.phase=="editing" and is_instance_valid(gameplay_ui.creator.source_frontend) and gameplay_ui.creator.source_frontend.wanted and gameplay_ui.creator.source_frontend.main.visible),"Warm cycle actual original creation entry"):return false
	if quiescent:
		var services: Array=[]
		for node in gameplay_ui.find_children("*","Node",true,false):
			if node.get_script()==preload("res://systems/native_data/asset_service.gd") and node.can_process():services.append(node)
		if not check(await await_flow(func():return services.all(func(owner):return owner.pending.is_empty() and owner.running.is_empty()) and gameplay_ui.creator.jobs.is_empty() and gameplay_ui.creator.resource_queue.is_empty(),10000),"Diagnostic-only warm processing asset quiescence completes"):return false
	var creator=gameplay_ui.creator;await click(creator.source_frontend.main.buttons.cancelbutton);receive(selection_view());await ui_frames()
	if not check(creator.phase=="closed" and character_lobby.panel.visible,"Warm cycle actual parent cancellation returns to picker"):return false
	var own_connection: int=session_connection;await click(character_lobby.native_chooser.buttons.cancelbutton)
	if not check(cancelled_connection==own_connection and not character_lobby.panel.visible,"Warm physical picker Cancel retires exact owner"):return false
	var next_connection: int=own_connection+1
	receive({"kind":"lobby","connection":next_connection,"state":{"phase":"disconnecting","connected":true,"busy":true,"choices":[]}});receive({"kind":"lobby","connection":next_connection,"state":{"phase":"menu","connected":false,"busy":false,"canJoin":true,"choices":[]}});receive(list_view(next_connection,100+next_connection,"Internet"));await ui_frames()
	return check(server_browser.native_browser.visible and not character_lobby.panel.visible,"Warm accepted disconnect returns to original browser")
'''
    text=text.replace('func finish_case() -> void:',helper+'func finish_case() -> void:',1)
    anchor='\t\tawait click(server_browser.native_browser.pages.Internet.buttons.cancelbutton);receive(list_view(2,6,"Direct"));'
    assert text.count(anchor)==1
    replacement='\t\tif not await warm_disconnect_cycle(false):await finish_case();return\n\t\tif not await warm_disconnect_cycle(true):await finish_case();return\n\t\tawait click(server_browser.native_browser.pages.Internet.buttons.cancelbutton);receive(list_view(session_connection,900+session_connection,"Direct"));'
    text=text.replace(anchor,replacement,1)
    text=text.replace('var result:={"success":','var result:={"diagnosticOnly":true,"reset_timings":report.get("pregame_reset_timings",[]),"success":',1)
    return text
change('tests/native_pregame_flow_test.gd',warm_fixture)
patch=''.join(''.join(difflib.unified_diff(originals[name].splitlines(True),(copy/name).read_text().splitlines(True),fromfile='accepted24/'+name,tofile='diagnostic/'+name)) for name in originals)
(destination/'instrumentation.patch').write_text(patch,encoding='utf-8')
inputs=[{'path':row['path'],'sha256':sha((copy/row['path']).read_bytes())} for row in r['inputs']]
metadata={'kind':'immutable-pregame-teardown-diagnostic','sourceRun':str(SOURCE),'directory':str(destination),'copy':str(copy),'featureAccepted':False,'originalChecks':24,'extraWarmCycles':2,'secondWarmProcessingServiceQuiescent':True,'inactiveHudServicesStillClosed':True,'staticClosure':r['staticClosure'],'inputs':inputs,'mutatedFiles':list(originals),'baseDriverSha256':sha((SOURCE/'project/tools/test-native-pregame-flow.ps1').read_bytes())}
(destination/'preparation.json').write_text(json.dumps(metadata,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'success':True,'directory':str(destination),'mutatedFiles':list(originals),'featureAccepted':False},indent=2))
