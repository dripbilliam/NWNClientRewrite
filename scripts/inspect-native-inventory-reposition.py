"""Read-only unchanged original repository RepositionModel140882b70.
Only final model transform/parent virtual calls are captured. Explicit repo/icon
objects are fixture memory; no native GUI, packets or server process is run.
"""
import importlib.util,itertools,json,struct
from pathlib import Path
spec=importlib.util.spec_from_file_location('fixture',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
repo,icon,vt=m.heap+0x1000,m.heap+0x2000,m.heap+0x3000
def hook(u,a,n,_):
 if a==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(r)for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
 if a==m.stop+0x100:
  assert x==icon
  calls.append(dict(kind='transform',position=list(struct.unpack('<fff',u.mem_read(z,12))),bits=list(struct.unpack('<III',u.mem_read(z,12)))));m.finish()
 elif a==m.stop+0x108:assert x==icon and y==repo;calls.append(dict(kind='parent'));m.finish()
 elif not 0x140882b70<=a<=0x140882cb6:raise AssertionError(f'Uncaptured reposition dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global calls
 calls=[];u.mem_write(m.heap,bytes(0x10000));u.mem_write(m.stack,bytes(0x20000));m.wq(icon,vt);m.wq(vt+0x140,m.stop+0x100);m.wq(vt+0x110,m.stop+0x108);m.wq(repo+0x10,repo)
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);m.wi(rsp+0x28,case['width']);m.wi(rsp+0x30,case['height']);u.reg_write(UC_X86_REG_RSP,rsp)
 for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],[repo,icon,case['x'],case['y']]):u.reg_write(reg,value)
 u.emu_start(0x140882b70,m.stop,count=10000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 assert len(calls)==2
 return dict(case=case,calls=calls)
if __name__=='__main__':
 rows=[run(dict(x=x,y=y,width=w,height=h)) for x,y,w,h in itertools.product([0,1,9],[0,1,5],[1,2,3,4],[1,2,3,4,5])]
 output=m.root/'backups/animations/native-inventory-reposition-observations-v1.json';assert not output.exists()
 output.write_text(json.dumps(dict(target=m.digest,scope=__doc__,rows=rows),indent=2));print(json.dumps(dict(output=str(output),rows=len(rows))))
