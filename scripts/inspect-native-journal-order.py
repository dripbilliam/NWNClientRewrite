"""Execute original journal selection-sort7d6cd0 and original comparators.
Localized-title resolution is a captured boundary supplying authored CP1252
strings. Original byte comparisons, priority, timer validation/comparison and
index exchanges execute unchanged. No live game/server or game data is modified.
"""
import importlib.util,itertools,json,random,struct
from pathlib import Path
spec=importlib.util.spec_from_file_location('image',Path(__file__).with_name('inspect-native-intratile-coordinator.py'))
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
manager,records,order,clock,app,strings=[m.heap+n for n in [0x1000,0x10000,0x18000,0x20000,0x22000,0x30000]]
def hook(u,a,n,_):
 if a==m.stop:u.emu_stop();return
 x,y,z=[u.reg_read(reg) for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8]]
 if a==0x1406ab950:m.finish(0);return
 if a==0x1406ac330:m.finish(clock);return
 if a==0x140169920:
  ptr=m.q(x);m.wq(z,ptr);m.wq(z+8,m.q(x+8));m.finish(1);return
 if a==0x140c10370:m.finish();return
 if not any(lo<=a<=hi for lo,hi in [(0x1407d6cd0,0x1407d6de0),(0x1407d6830,0x1407d6898),(0x1407d69c0,0x1407d6b27),(0x1407d6c30,0x1407d6cce),(0x140596e50,0x140596e82)]):raise AssertionError(f'Uncaptured original journal dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
fixtures=[dict(sortTitle=title,date=date,time=time,priority=priority) for title,date,time,priority in [('Zulu',3,20,5),('alpha',2,30,0),('A',3,20,5),('AA',3,1,0xffffffff),('Œ',0xffffffff,0,5),('ß',0,0xffffffff,0)]]
permutations=list(itertools.permutations(range(4)))
inputs=[list(p)+[4,5] for p in permutations]+[[5,4,3,2,1,0],[4,5,1,0,2,3]]
rows=[]
for mode,length,indices in itertools.product(range(3),[1,1440000,43200000,0xffffffff],inputs):
 u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));m.wq(manager,records);m.wi(manager+8,len(indices));m.wq(manager+0x10,order);m.wi(manager+0x18,len(indices));m.wi(manager+0x20,mode);m.wf(clock,0);m.wi(clock+0x30,length);m.wq(0x1412df970,app)
 source=[fixtures[i] for i in indices]
 for at,row in enumerate(source):
  text=row['sortTitle'].encode('cp1252');ptr=strings+at*256;u.mem_write(ptr,text+b'\0');m.wq(records+at*0x50,ptr);m.wq(records+at*0x50+8,len(text))
  for offset,key in [(0x20,'date'),(0x24,'time'),(0x3c,'priority')]:m.wi(records+at*0x50+offset,row[key])
  m.wi(order+at*4,at)
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,manager)
 u.emu_start(0x1407d6cd0,m.stop,count=100000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 rows.append(dict(mode=mode,dayLength=length,entries=source,indices=[m.si(order+at*4) for at in range(len(source))],dirty=m.si(manager+0x24)))
out=m.root/'backups/animations/native-journal-order-observations-v1.json';assert not out.exists(),'Preserve previous observations'
out.write_text(json.dumps(dict(target=m.digest,scope=__doc__,rows=rows),indent=2));print(json.dumps(dict(output=str(out),rows=len(rows),target=m.digest)))
