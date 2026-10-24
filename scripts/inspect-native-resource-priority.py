"""Read-only execution of AddKeyTable14018e330 on synthetic catalogs.

Original priority-group arithmetic, insertion scans and array writes execute.
Catalog construction, allocation, string comparison, copy and reload are
captured boundaries; this does not prove archive/manifest decoding.
"""
import importlib,sys,json,itertools
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
manager,array=m.heap,m.heap+0x1000
cursor=0x10000
def alloc(size):
 global cursor
 result=m.heap+cursor;cursor+=(size+31)&~15;assert cursor<0xf0000;u.mem_write(result,bytes(size));return result
def string(pointer):
 data=m.q(pointer);length=m.si(pointer+8);return bytes(u.mem_read(data,length)).decode('ascii') if data else ''
def exo(value):
 pointer=alloc(16);data=alloc(len(value)+1);u.mem_write(data,value.encode()+b'\0');m.wq(pointer,data);m.wi(pointer+8,len(value));m.wi(pointer+12,len(value)+1);return pointer
def hook(u,address,size,data):
 x,y,z,w=[u.reg_read(reg) for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
 if address==m.stop:u.emu_stop();return
 if address==0x140c10324:m.finish(alloc(x));return
 if address==0x140187a40:m.finish(x);return
 if address==0x14018a690:
  m.wi(x+0x20,y);u.mem_write(x+0x28,bytes(u.mem_read(z,16)));m.wi(x+0x48,w);m.finish(1);return
 if address==0x14018d0a0:m.finish();return
 if address==0x14016ae00:m.finish(int(string(x).lower()==string(y).lower()));return
 if address==0x140c417f0:u.mem_write(x,bytes(u.mem_read(y,z)));m.finish(x);return
 if address==0x140115890:m.finish();return
 if address==0x14018ccf0:m.finish(1);return
 if not 0x14018e330<=address<=0x14018e799:raise RuntimeError(f'Unexpected original dependency {address:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(sources):
 global cursor
 cursor=0x10000;u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));m.wq(manager+0x18,array);m.wi(manager+0x20,0);m.wi(manager+0x24,64)
 for source in sources:
  name=exo(source['name']);rsp=m.stack+0x1fe08;u.mem_write(rsp-0x100,bytes(0x200));m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
  for register,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],[manager,source['priority'],name,source['type']]):u.reg_write(register,value)
  u.emu_start(0x14018e330,m.stop,count=20000);assert u.reg_read(UC_X86_REG_RIP)==m.stop;assert u.reg_read(UC_X86_REG_RAX)==1
 ordered=[]
 for i in range(m.si(manager+0x20)):
  p=m.q(m.q(manager+0x18)+i*8);ordered.append(dict(name=string(p+0x28),priority=m.si(p+0x48),type=m.si(p+0x20)))
 return dict(registrations=sources,ordered=ordered)
source=lambda name,priority,type:dict(name=name,priority=priority,type=type)
base=[source('base',1000000,1),source('retail',2000000,1),source('localized',3000000,1),source('override',12000000,2),source('module',23000000,3)]
rows=[]
for placement,extras in itertools.product(itertools.product([30000000,31000000],repeat=3),range(4)):
 haks=[source('hak_'+str(i),priority,3)for i,priority in enumerate(placement)]
 manifests=[source('primary',40000000,5)]+[source('extra_'+str(i),40000000,5)for i in range(extras)]
 rows.append(run(base+list(reversed(haks))+manifests))
rows.append(run(base+[source('same',40000000,5),source('same',40000000,5)]))
rows.append(run(base+[source('same',40000000,5),source('other',40000000,5),source('same',40000000,5)]))
rows.append(run(base+[source('hak_same',31000000,3),source('hak_other',31000000,3),source('hak_same',31000000,3)]))
out=m.root/'backups/animations/native-resource-priority-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,scope=__doc__,rows=rows),indent=2));print(json.dumps(dict(output=str(out),rows=len(rows))))
