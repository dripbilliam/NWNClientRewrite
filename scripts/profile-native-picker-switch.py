"""Owned copied-source CPU probe. Never launches or attaches to the user's UI."""
from __future__ import annotations
import argparse
import hashlib
import json
import re
import shutil
import subprocess
import time
from datetime import datetime, timezone
from pathlib import Path

workspace=Path(__file__).resolve().parents[1]
project=workspace/'godot-client'
arguments=argparse.ArgumentParser()
arguments.add_argument('--mode',choices=['baseline','clone','policy','staged','work-staged'],default='baseline')
options=arguments.parse_args()
runtime=project/'.tools/Godot_v4.7.2-stable_win64.exe'
digest=lambda data:hashlib.sha256(data).hexdigest()
assert digest(runtime.read_bytes())=='ab1824f85bfd8e0e4128182c000c4003a3e042245b2967848d089b2a04b22424'
directory=project/'.cache/picker-switch-responsiveness'/datetime.now(timezone.utc).strftime('%Y%m%d-%H%M%S-%f')
copy=directory/'project'
copy.mkdir(parents=True)
runner_bytes=Path(__file__).read_bytes()
(directory/'script-as-run.py').write_bytes(runner_bytes)
script='tests/native_picker_snapshot_clone_test.gd' if options.mode in ['clone','policy'] else 'tests/native_picker_work_test.gd' if options.mode=='work-staged' else 'tests/native_picker_switch_responsiveness_test.gd'
pending=[script]
if options.mode in ['staged','work-staged']:pending.append('systems/native_data/picker_table_snapshot.gd')
originals={}
while pending:
    relative=pending.pop()
    if relative in originals:continue
    data=(project/relative).read_bytes()
    originals[relative]=data
    if relative.endswith('.gd'):
        pending+=re.findall(r'res://([^"\r\n]+\.(?:gdshader|json|gd))"',data.decode('utf-8-sig'))
for relative in ['native/particle_kernel.gdextension','.cache/native-kernel/nwn-particle-kernel.dll','.cache/native-kernel/build-manifest.json']:
    originals[relative]=(project/relative).read_bytes()
for relative,data in originals.items():
    destination=copy/relative
    destination.parent.mkdir(parents=True,exist_ok=True)
    destination.write_bytes(data)

def wrap(relative,methods):
    target=copy/relative
    original=target.read_text(encoding='utf-8-sig').replace('\r\n','\n')
    text=original
    wrappers=[]
    for name,parameters,values in methods:
        signature=f'func {name}({parameters}) -> void:'
        replacement=f'func picker_original_{name}({parameters}) -> void:'
        assert text.count(signature)==1,(relative,name)
        text=text.replace(signature,replacement,1)
        wrappers.append(f'func {name}({parameters}) -> void:\n\tvar began:=Time.get_ticks_usec()\n\tpicker_original_{name}({values})\n\tif picker_diagnostic_spans.size()<1024:picker_diagnostic_spans.append({{"method":"{name}","us":Time.get_ticks_usec()-began}})\n')
    insertion='var picker_diagnostic_spans: Array=[]\n'
    first=text.index('\n')+1
    text=text[:first]+insertion+text[first:]
    text+='\n'+'\n'.join(wrappers)
    target.write_text(text,encoding='utf-8')
    # The diagnostic changes only wrappers, not original statements/order.
    recovered=text[:text.index('\nfunc '+methods[0][0]+'(')].replace(insertion,'',1).rstrip()+'\n'
    for name,parameters,_ in methods:
        recovered=recovered.replace(f'func picker_original_{name}({parameters}) -> void:',f'func {name}({parameters}) -> void:',1)
    assert recovered==original.rstrip()+'\n',relative

if options.mode not in ['clone','policy','work-staged']:
    wrap('systems/character_lobby.gd',[('sync_native','','')])
    wrap('systems/native_character_lobby.gd',[('sync','',''),('prepare_record','value: Variant','value'),('render_record','value: Variant','value'),('rebuild_rows','choices: Array','choices')])
    work=copy/'systems/native_data/character_picker_work.gd'
    text=work.read_text(encoding='utf-8').replace('\r\n','\n')
    needle='\t\t\ttable_copies[name]={"orderedRows":tables[name].get("orderedRows",[]).duplicate(true)}; stats.table_copies+=1'
    assert text.count(needle)==1
    text=text.replace('var closed:=false','var diagnostic_table_captures: Array=[]\nvar closed:=false',1)
    text=text.replace(needle,'\t\t\tvar table_began:=Time.get_ticks_usec()\n'+needle+'\n\t\t\tif diagnostic_table_captures.size()<128:diagnostic_table_captures.append({"name":name,"us":Time.get_ticks_usec()-table_began,"rows":tables[name].get("orderedRows",[]).size()})',1)
    work.write_text(text,encoding='utf-8')
if options.mode in ['staged','work-staged']:
    work=copy/'systems/native_data/character_picker_work.gd'
    text=work.read_text(encoding='utf-8').replace('\r\n','\n')
    old='table_copies[name]={"orderedRows":tables[name].get("orderedRows",[]).duplicate(true)}; stats.table_copies+=1'
    new='table_copies[name]=PickerSnapshot.capture_spells(tables[name],table_copies.get("classes",{})) if name=="spells" else {"orderedRows":tables[name].get("orderedRows",[]).duplicate(true)}; stats.table_copies+=1'
    assert text.count(old)==1
    text=text.replace('extends Node\n','extends Node\nconst PickerSnapshot=preload("res://systems/native_data/picker_table_snapshot.gd")\n',1).replace(old,new,1)
    work.write_text(text,encoding='utf-8')
copied={name:digest((copy/name).read_bytes()) for name in originals}
(copy/'project.godot').write_text('config_version=5\n[application]\nconfig/name="Owned Picker Switch CPU Probe"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n',encoding='utf-8')
fixture=project/'reports/native-picker-pregame-before-v1'
data_inputs={str(file.relative_to(fixture)):digest(file.read_bytes()) for folder in ['bic','resources'] for file in (fixture/folder).iterdir() if file.is_file()}
output=directory/'result.json'
engine=directory/'engine.log'
start=time.monotonic()
timed_out=False
log_guard=False
with (directory/'stdout.log').open('wb') as stdout,(directory/'stderr.log').open('wb') as stderr:
    child=subprocess.Popen([str(runtime),'--headless','--max-fps','60','--path',str(copy),'--log-file',str(engine),'--script','res://'+script,'--','--report='+str(output),'--fixture='+str(fixture),'--install='+str((workspace/'../FullDecomp/NwnRootInstall').resolve()),'--probe-mode='+options.mode,'--oracles='+str(project/'reports'),'--entity-api-rest=false'],cwd=workspace,stdout=stdout,stderr=stderr,creationflags=subprocess.CREATE_NO_WINDOW)
    try:
        while child.poll() is None:
            if time.monotonic()-start>35:timed_out=True;break
            if any(file.exists() and file.stat().st_size>8*1024*1024 for file in [engine,directory/'stdout.log',directory/'stderr.log']):log_guard=True;break
            time.sleep(.1)
    finally:
        if child.poll() is None:child.kill()
        child.wait(timeout=10)
result=json.loads(output.read_text(encoding='utf-8-sig')) if output.exists() else None
log=engine.read_text(encoding='utf-8-sig') if engine.exists() else ''
clean=bool(log) and not re.search(r'^ERROR:|^WARNING:|SCRIPT ERROR|Parse Error|ObjectDB instances leaked|Leaked instance|still in use at exit',log,re.M)
changed=[name for name,data in originals.items() if digest((project/name).read_bytes())!=digest(data)]
copy_changed=[name for name,sha in copied.items() if digest((copy/name).read_bytes())!=sha]
data_changed=[name for name,sha in data_inputs.items() if digest((fixture/name).read_bytes())!=sha]
receipt={'success':bool(result and result['success'] and child.returncode==0 and clean and not timed_out and not log_guard and not changed and not copy_changed and not data_changed),'mode':options.mode,'directory':str(directory),'checks':result['checks'] if result else 0,'exitCode':child.returncode,'cleanEngine':clean,'timedOut':timed_out,'logGuard':log_guard,'elapsedSeconds':time.monotonic()-start,'inputs':[{'path':name,'sha256':digest(data),'instrumentedCopySha256':copied[name]} for name,data in originals.items()],'changedInputs':changed,'changedCopiedInputs':copy_changed,'dataInputs':data_inputs,'changedData':data_changed,'fixture':str(fixture),'publicConnections':0,'nativeBuilds':0,'gpuBenchmark':False,'userProcessTouched':False,'scope':'Copied actual default source picker CPU phases and original statement-preserving diagnostic wrappers; authored receive/ack schedule with captured server-vault BICs. No live server latency/FPS or user-window acceptance.'}
receipt['runnerSha256']=digest(runner_bytes)
receipt['runnerUnchanged']=Path(__file__).read_bytes()==runner_bytes
if options.mode in ['clone','policy']:receipt['scope']='Staged full physical-row/class-column input closure, canonical getter equality and mutation isolation on cached data. No actual UI/worker interaction or GPU/FPS claim.'
elif options.mode=='work-staged':receipt['scope']='Existing selected-character worker lifecycle/ruleset regression with copy-only staged snapshot branch. Optional historical1295 modifier oracle was not supplied and is not claimed.'
(directory/'runner.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
print(json.dumps({key:value for key,value in receipt.items() if key not in ['inputs','dataInputs']},indent=2))
raise SystemExit(0 if receipt['success'] else 1)
