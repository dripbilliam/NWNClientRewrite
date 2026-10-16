"""Complete unchanged visual model detach14096c180..14096c281.
Model parent/scene virtuals, client/render/context lookup and refresh are
explicit lower boundaries. Tests full short-circuit/iteration/alias ordering,
not the lower scene or GPU lighting implementations.
"""
import importlib,itertools,json
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
effect,manager,client,render,area,other,scene,vt=[m.heap+n*0x1000 for n in range(8)]
def hook(u,a,n,_):
 if a==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(r)for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
 if a==m.stop+0x10:
  calls.append(['parent',names[x],y,z,w])
  if c['mutateNext']and names[x]==0:m.wq(effect+0x90,0)
  m.finish()
 elif a==m.stop+0x20:calls.append(['scene',names[x],y]);m.finish()
 elif a==0x1406abb60:calls.append(['client',y]);m.finish(client if c['client']else 0)
 elif a==m.stop+0x30:calls.append(['render']);m.finish(render if c['render']else 0)
 elif a==m.stop+0x40:calls.append(['view58']);m.finish(area if c['area']else 0)
 elif a==0x1406ac1a0:calls.append(['view1406ac1a0']);m.finish(area if c['active']else other)
 elif a==0x1407e9bc0:calls.append(['refresh']);m.finish()
 elif not 0x14096c180<=a<0x14096c281:raise RuntimeError(f'Unexpected native visual detach dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,calls,names
 c=case;calls=[];names={};u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000))
 m.wq(0x1412df970,manager);m.wq(manager,manager+0x100);m.wq(client,vt);m.wq(render,vt);m.wq(vt+0x98,m.stop+0x10);m.wq(vt+0x90,m.stop+0x20);m.wq(vt+0x18,m.stop+0x30);m.wq(vt+0x58,m.stop+0x40);m.wq(area+0x30,scene if c['scene']else 0)
 m.wi(effect+0x54,123);m.wi(effect+0x114,7);u.mem_write(effect+0x10d,bytes([c['type']]))
 models=[m.heap+0x10000+i*0x1000 for i in range(4)]
 if c['alias']:models[2]=models[0]
 for i,ptr in enumerate(models):names.setdefault(ptr,i);m.wq(ptr,vt)
 for i in range(3):m.wq(effect+0x88+i*8,models[i]if c['models'][i]else 0)
 m.wq(effect+0xb8,models[3]if c['procedural']else 0)
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,effect)
 try:u.emu_start(0x14096c180,m.stop,count=10000)
 except Exception:print(json.dumps(dict(case=c,rip=hex(u.reg_read(UC_X86_REG_RIP)),calls=calls)));raise
 assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=c,calls=calls,attached=m.si(effect+0x114),models=[names[m.q(effect+0x88+i*8)]if m.q(effect+0x88+i*8)else None for i in range(3)])
def profile(**kw):
 c=dict(models=[1,1,1],procedural=1,type=4,client=1,render=1,area=1,active=1,scene=1,alias=0,mutateNext=0);c.update(kw);return c
rows=[run(profile(models=models,procedural=proc,type=kind,client=client,render=render,area=area,active=active,scene=scene))for models,proc,kind,(client,render,area,active,scene)in itertools.product([[0,0,0],[1,0,1],[1,1,1]],[0,1],[0,4],[(0,1,1,1,1),(1,0,1,1,1),(1,1,0,1,1),(1,1,1,0,1),(1,1,1,1,0),(1,1,1,1,1)])]
rows.extend(run(profile(**kw))for kw in [dict(alias=1),dict(mutateNext=1),dict(alias=1,mutateNext=1)])
out=m.root/'backups/animations/native-visual-detachment-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2));print(json.dumps(dict(output=str(out),rows=len(rows))))
