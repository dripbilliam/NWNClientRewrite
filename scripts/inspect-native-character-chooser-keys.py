"""Read-only original CPlayModuleUpDownKeyHackControl and selection callback.
Unchanged key dispatch, bounds and conditional pixel-scroll arithmetic execute.
Tab selection/preview rendering, slider read, update registration and base edit
handling are captured GUI services. Populated list fixtures only; not full UI.
"""
import importlib.util,itertools,json
from pathlib import Path
spec=importlib.util.spec_from_file_location('image',Path(__file__).with_name('inspect-native-intratile-coordinator.py'))
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle);owner=m.heap+0x1000;control=m.heap+0x5000
def hook(u,a,n,_):
 if a==m.stop:u.emu_stop();return
 y=u.reg_read(UC_X86_REG_RDX)&0xffffffff;y=y-0x100000000 if y>=0x80000000 else y
 if a==0x1401eff30:calls.append(['select',y]);m.wi(owner+0x12f8,y);m.finish()
 elif a==0x140712440:calls.append(['preview',y]);m.finish()
 elif a==0x1401e6290:m.finish(case['scroll'])
 elif a==0x1401fb540:calls.append(['scroll',m.si(owner+0x177c)]);m.finish()
 elif a==0x1401e99b0:calls.append(['base-key',y]);m.finish()
 elif not(0x140710a90<=a<=0x140710ae3 or 0x14070f3c0<=a<=0x14070f480):raise AssertionError(f'Uncaptured chooser-key dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(count,selected,key,scroll,index):
 global case,calls
 case=dict(count=count,selected=selected,key=key,scroll=scroll,rowHeight=[32,43][index%2],viewportHeight=[90,123][index%2]);calls=[]
 u.mem_write(m.heap,bytes(0x10000));u.mem_write(m.stack,bytes(0x20000))
 m.wq(control+0x100,owner);m.wq(control+0x108,0x14070f3c0)
 for offset,value in [(0x12f8,selected),(0x1308,count),(0x15f8,case['rowHeight']),(0x15fc,case['viewportHeight']),(0x177c,-999)]:m.wi(owner+offset,value)
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop)
 for reg,value in [(UC_X86_REG_RSP,rsp),(UC_X86_REG_RCX,control),(UC_X86_REG_RDX,key)]:u.reg_write(reg,value)
 u.emu_start(0x140710a90,m.stop,count=10000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=case,selected=m.si(owner+0x12f8),scrollRequest=next((v for kind,v in calls if kind=='scroll'),None),calls=calls)
if __name__=='__main__':
 rows=[]
 for count in [1,5,130]:
  for selected,key,scroll in itertools.product(sorted(set([-1,0,count-1])),[13,27]+list(range(0x124,0x12a)),[0,17,76]):rows.append(run(count,selected,key,scroll,len(rows)))
 out=m.root/'backups/animations/native-character-chooser-key-observations-v1.json';assert not out.exists(),'Preserve prior evidence';out.write_text(json.dumps(dict(target=m.digest,scope=__doc__,rows=rows),indent=2));print(json.dumps(dict(output=str(out),cases=len(rows))))
