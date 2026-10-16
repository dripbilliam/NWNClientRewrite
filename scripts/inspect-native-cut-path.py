"""Original CutWaypointPath14038a500, including a null waypoint allocation.
All instructions execute without lower helper replacements.
"""
import importlib.util,itertools,json
from pathlib import Path
spec=importlib.util.spec_from_file_location('fixture',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle);actor=m.heap;path=m.heap+0x2000
def hook(u,a,n,_):
 if a==m.stop:u.emu_stop()
 elif not 0x14038a500<=a<0x14038a58e:raise AssertionError(hex(a))
u.hook_add(UC_HOOK_CODE,hook)
rows=[]
for count,index,sequence in itertools.product([0,2,10],[-2,0,2],[0,255]):
 u.mem_write(m.heap,bytes(0x100000));m.wq(actor+0x530,path);m.wi(path+0x7c,count);m.wi(path+0x98,index);u.mem_write(path+0x130,bytes([sequence]))
 for offset,values in [(0xa4,[1,2,3]),(0xb0,[4,5,6])]:
  for i,v in enumerate(values):m.wf(actor+offset+i*4,v)
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,actor);u.emu_start(0x14038a500,m.stop,count=1000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 rows.append(dict(count=count,index=index,sequence=sequence,after=dict(sequence=u.mem_read(path+0x130,1)[0],flag=m.si(path+0x128),field12c=m.si(path+0x12c),remaining=m.si(path+0x134),position=[m.rf(path+0x138+i*4) for i in range(3)],orientation=[m.rf(path+0x144+i*4) for i in range(3)])))
out=m.root/'backups/animations/native-cut-path-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows))+'\n');print(json.dumps(dict(rows=len(rows),output=str(out))))
