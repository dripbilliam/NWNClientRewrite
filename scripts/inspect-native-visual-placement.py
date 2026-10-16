"""Complete unchanged placement1409702e0..140970e19. Registry/client/model
virtuals, CExoString/heap helpers, procedural initialization and final model
state/scene application are explicit lower responses. Verifies all upper
parent/name/rotation/flag/order paths, not their lower transform implementations.
"""
import importlib,itertools,json,struct
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
effect,manager,registry,client,render,host,viewA,viewB,vt=[m.heap+n*0x1000 for n in range(9)]
def string(ptr):
 if not ptr:return ''
 raw=bytearray()
 while u.mem_read(ptr+len(raw),1)[0]:raw.append(u.mem_read(ptr+len(raw),1)[0])
 return raw.decode('ascii')
def cs(ptr):return string(m.q(ptr))
def allocate(size):
 global allocation
 ptr=m.heap+0x80000+allocation*0x100;allocation+=1;return ptr
def writecs(ptr,value):
 data=value.encode()+b'\0';dst=allocate(len(data));u.mem_write(dst,data);m.wq(ptr,dst);m.wi(ptr+8,len(data)-1);m.wi(ptr+12,len(data))
def vector(ptr,values):
 for i,v in enumerate(values):m.wf(ptr+i*4,v)
def read(ptr,n=3):return[m.rf(ptr+i*4)for i in range(n)]
def hook(u,a,n,_):
 if a==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(r)for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
 if a==0x140c10370:m.finish()
 elif a==0x140c10368:m.finish(allocate(x))
 elif a==0x14016ab00:writecs(y,cs(x)+cs(z));m.finish(y)
 elif a==0x1406abb70:calls.append(['registry']);m.finish(registry if c['registry']else 0)
 elif a==0x140296470:
  calls.append(['object',y]);m.wq(z,client);m.finish(0 if c['object']else 1)
 elif a==m.stop+0x10:calls.append(['render']);m.finish(render)
 elif a==m.stop+0x20:calls.append(['modelHandle',y&255,z&0xffffffff]);m.finish(host)
 elif a==m.stop+0x30:calls.append(['viewA']);m.finish(viewA if c['first']else 0)
 elif a==m.stop+0x40:calls.append(['viewB']);m.finish(viewB if c['second']else 0)
 elif a==m.stop+0x50:calls.append(['parent',names[x],9,string(z),w&0xffffffff]);m.finish()
 elif a==m.stop+0x60:
  id=names[x];calls.append(['pose',id,string(y)]);vector(z,[id+.25,id+.5,id+.75]);vector(w,[.5,.5,.5,.5]);m.finish()
 elif a==m.stop+0x70:calls.append(['setPose',names[x],string(y),read(z),read(w,4)]);m.finish()
 elif a==0x14096a110:calls.append(['startProgram',y&65535]);m.finish()
 elif a==0x1409688b0:
  assert m.q(x)==effect and m.q(x+8)==render;calls.append(['apply',names[y]])
  if c['mutateApply']and names[y]==3:m.wq(effect+0x90,0)
  m.finish()
 elif not 0x1409702e0<=a<0x140970e19:raise RuntimeError(f'Unexpected native placement dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,calls,names,allocation
 c=case;calls=[];names={};allocation=0;u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000))
 m.wq(0x1412df970,manager);m.wq(manager,manager+0x100);m.wq(client,vt);m.wq(render,vt)
 for off,target in [(0x18,0x10),(0x140,0x20),(0xa0,0x30),(0x28,0x40),(0x98,0x50),(0x138,0x60),(0x130,0x70)]:m.wq(vt+off,m.stop+target)
 writecs(viewA+0x1e0,c['prefixA']);writecs(viewB+0x1c8,c['prefixB']);m.wi(effect+0x54,123);m.wi(effect+0xd8,c['updated']);m.wi(effect+0x114,7);m.wi(effect+0x120,c['orient']);u.mem_write(effect+0xfa,bytes([c['phase']]))
 models=[m.heap+0x10000+i*0x1000 for i in range(7)]
 if c['alias']:models[2]=models[0]
 for i,ptr in enumerate(models):names.setdefault(ptr,i);m.wq(ptr,vt)
 for i in range(3):m.wq(effect+0x88+i*8,models[i]if c['models'][i]else 0);m.wq(effect+0xa0+i*8,models[i+4]if c['extra']else 0);u.mem_write(effect+0xd0+i*2,struct.pack('<H',[10,20,30][i]))
 m.wq(effect+0xb8,models[3]if c['procedural']else 0)
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,effect);u.reg_write(UC_X86_REG_RDX,c['force'])
 try:u.emu_start(0x1409702e0,m.stop,count=100000)
 except Exception:print(json.dumps(dict(case=c,rip=hex(u.reg_read(UC_X86_REG_RIP)),calls=calls)));raise
 assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=c,calls=calls,result=u.reg_read(UC_X86_REG_RAX)&0xffffffff,updated=m.si(effect+0xd8),attached=m.si(effect+0x114),models=[names[m.q(effect+0x88+i*8)]if m.q(effect+0x88+i*8)else None for i in range(3)])
def profile(**kw):
 c=dict(force=0,updated=0,registry=1,object=1,orient=0,first=1,second=0,prefixA='prefix',prefixB='other',models=[1,1,1],procedural=1,extra=0,phase=2,alias=0,mutateApply=0);c.update(kw);return c
rows=[run(profile(force=force,updated=updated,registry=registry,object=object,orient=orient,first=first,second=second,models=models,procedural=proc,extra=extra))for (force,updated),(registry,object),orient,(first,second),models,proc,extra in itertools.product([(0,0),(0,1),(1,1)],[(0,1),(1,0),(1,1)],[0,1],[(0,0),(0,1),(1,0),(1,1)],[[0,0,0],[1,1,1]],[0,1],[0,1])]
rows.extend(run(profile(**kw))for kw in [dict(alias=1),dict(mutateApply=1),dict(phase=1),dict(phase=3),dict(phase=0),dict(prefixA=''),dict(first=0,prefixB='')])
out=m.root/'backups/animations/native-visual-placement-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2));print(json.dumps(dict(output=str(out),rows=len(rows))))
