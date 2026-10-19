"""Execute full native client RemoveVisual762ad0 and actual type/cessation
getters. Linked-list traversal, competing detach, Stop and group selection are
captured providers. Stop's verified finish write is retained between calls.
No server looping-array semantics or canonical effect IDs are substituted.
"""
import importlib,json,itertools,sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle);actor,listing,vt=[m.heap+n*0x1000 for n in range(3)]
ranges=[(0x140762ad0,0x140762b9f),(0x14096c450,0x14096c458),(0x14096c610,0x14096c637)]
def hook(u,a,n,_):
 if a==m.stop:u.emu_stop();return
 x,y,z=[u.reg_read(r)for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8]]
 if a==0x140169110:
  index=indices[m.q(y)]+1;ptr=nodes[index]if index<len(nodes)else 0;m.wq(y,ptr);m.finish(models[index]if ptr else 0)
 elif a==0x140762c10:calls.append(['detachCompeting',models.index(y)]);m.finish()
 elif a==0x140971530:calls.append(['stop',models.index(x),y&0xffffffff]);m.wi(x+0xf4,y&0xffffffff);m.finish()
 elif a==m.stop+0x700:calls.append(['select',y&255,z]);m.finish()
 elif not any(lo<=a<=hi for lo,hi in ranges):raise RuntimeError(f'Uncaptured visual removal dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(entries,target):
 global nodes,models,indices,calls
 u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));m.wq(actor,vt);m.wq(vt+0x1a8,m.stop+0x700);m.wq(actor+0x80,listing);nodes=[];models=[]
 for i,e in enumerate(entries):
  node=m.heap+0x8000+i*0x100;ptr=m.heap+0x10000+i*0x1000 if e else 0;nodes.append(node);models.append(ptr);m.wq(node+0x10,ptr)
  if e:
   u.mem_write(ptr+0xf8,int(e['visual']).to_bytes(2,'little'));m.wi(ptr+0xf4,e['finished']);u.mem_write(ptr+0x10d,bytes([e['type']]));m.wq(ptr+0x88,ptr+0x500 if e['cessation']else 0);u.mem_write(ptr+0x68,(3 if e['cessation']else 0).to_bytes(2,'little'))
 indices={ptr:i for i,ptr in enumerate(nodes)};m.wq(listing,nodes[0]if nodes else 0);steps=[]
 for _ in range(3):
  calls=[];sp=m.stack+0x1fe08;m.wq(sp,m.stop);u.reg_write(UC_X86_REG_RSP,sp);u.reg_write(UC_X86_REG_RCX,actor);u.reg_write(UC_X86_REG_RDX,target);u.emu_start(0x140762ad0,m.stop,count=20000);assert u.reg_read(UC_X86_REG_RIP)==m.stop;steps.append(dict(result=u.reg_read(UC_X86_REG_RAX)&0xffffffff,calls=list(calls)))
 return dict(entries=entries,target=target,steps=steps)
rows=[]
for visual,head,tail,match in itertools.product([0,66,160,65535],['active','finished','cessation','null'],['active','finished','cessation'],[True,False]):
 def entry(state,kind):return None if state=='null'else dict(visual=visual,finished=int(state=='finished'),cessation=int(state=='cessation'),type=kind)
 rows.append(run([entry(head,4),entry(tail,7),dict(visual=(visual+1)&65535,finished=0,cessation=0,type=0)],visual if match else (visual+1)&65535))
rows.extend(run([],v)for v in [0,66,160,65535])
out=m.root/'backups/animations/native-client-visual-remove-observations.json';out.write_text(json.dumps(dict(target=m.digest,limits=__doc__,cases=rows),indent=2)+'\n');print(json.dumps(dict(cases=len(rows),calls=len(rows)*3,output=str(out))))
