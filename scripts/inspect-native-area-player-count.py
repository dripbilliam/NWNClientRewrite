"""Complete original IncrementPlayersInArea14035f2c0 and
DecrementPlayersInArea14035ce70, with captured canonical lookup/type-cast and
AI-level mutation boundaries. Original door script selector executes. Ordered
live spatial arrays, stale IDs and first/last-player gates are exercised.
"""
import importlib,sys,json,itertools
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
m=importlib.import_module('inspect-native-intratile-coordinator')
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
area,app,spatial,vt=[m.heap+i*0x1000 for i in range(4)]
kinds=[3,4,5,7,11,10,10,9,9,6,12,13,14,16];objects={100+i:m.heap+0x10000+i*0x1000 for i in range(len(kinds))}
casts={m.stop+0x100:('asCreature',5),m.stop+0x110:('asAreaEffect',11),m.stop+0x120:('asTrigger',7),m.stop+0x130:('asDoor',10),m.stop+0x140:('asPlaceable',9)}
def hook(u,a,n,_):
 if a==m.stop:u.emu_stop();return
 x,y,z=[u.reg_read(r) for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8]]
 if a==0x14055b850 or a==0x14055b960:m.finish(app)
 elif a==0x140296470:id=y&0xffffffff;calls.append(['object',id]);m.wq(z,objects.get(id,0));m.finish(0 if id in objects else 1)
 elif a in casts:
  name,kind=casts[a];calls.append([name,m.si(x+8)&0xffffffff]);m.finish(x if u.mem_read(x+12,1)[0]==kind else 0)
 elif a==0x140420880:calls.append(['scriptName',m.si(x+8)&0xffffffff,y&0xffffffff])
 elif a==0x140559cb0:
  id=m.si(y+8)&0xffffffff;calls.append(['ai',id,z&0xffffffff])
  if not c['locked']:m.wi(y+0x7c,z)
  if c['truncate']:m.wi(area+0x230,min(1,m.si(area+0x230)))
  m.finish(0 if c['locked'] else 1)
 elif not any(lo<=a<hi for lo,hi in [(0x14035f2c0,0x14035f461),(0x14035ce70,0x14035cf49),(0x140420880,0x140420899)]):raise RuntimeError(f'Unmapped area count dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,calls
 c=case;calls=[];u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));m.wq(0x1412df970,app);m.wq(app+8,app);m.wi(area+0x150,c['count']);m.wq(area+0x228,spatial);m.wi(area+0x230,len(c['ids']))
 for i,id in enumerate(c['ids']):m.wi(spatial+i*4,id)
 for i,(id,ptr)in enumerate(objects.items()):m.wq(ptr,vt);m.wi(ptr+8,id);u.mem_write(ptr+12,bytes([kinds[i]]));m.wi(ptr+0x7c,c['level']);m.wi(ptr+0x360,int(i%2==0));m.wi(ptr+0x5a0,int(i%2==0))
 for offset,address in [(0x60,m.stop+0x100),(0xa8,m.stop+0x110),(0x80,m.stop+0x120),(0x30,m.stop+0x130),(0x98,m.stop+0x140),(0x1e0,0x140420880)]:m.wq(vt+offset,address)
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,area)
 u.emu_start(0x14035f2c0 if c['operation']=='increment' else 0x14035ce70,m.stop,count=20000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=c,calls=calls,count=m.si(area+0x150),levels=[m.si(p+0x7c)for p in objects.values()],ids=[m.si(spatial+i*4)&0xffffffff for i in range(m.si(area+0x230))])
vectors=[[],list(objects),[999,102,105,106,107,108,999]]
rows=[run(dict(operation=op,count=count,level=level,ids=ids,truncate=truncate,locked=locked))for op,count,level,ids,truncate,locked in itertools.product(['increment','decrement'],[-2147483648,-1,0,1,2,2147483647],[0,1,2],vectors,[False,True],[False,True])]
out=m.root/'backups/animations/native-area-player-count-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,kinds=kinds,rows=rows),indent=2));print(json.dumps(dict(output=str(out),rows=len(rows))))
