"""Original AddObjectToArea14035ba90 and AddToArea140380470, nonclient
creature path. Capture sorted-index/list allocation and lower removal/AoE/AI
owners. Client handshake, DM automap and first-client activation are not proven.
"""
import importlib.util,itertools,json,struct
from pathlib import Path
spec=importlib.util.spec_from_file_location('fixture',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
actor,area,app,spatial,stats,vt,following,event=[m.heap+n*0x1000 for n in range(1,9)];objects={99:actor,100:m.heap+0x10000,101:m.heap+0x12000,103:m.heap+0x14000,104:m.heap+0x16000}
def ids():return [m.si(spatial+i*4)&0xffffffff for i in range(m.si(area+0x230))]
def writeids(values):
 m.wi(area+0x230,len(values))
 for i,id in enumerate(values):m.wi(spatial+i*4,id)
def hook(u,a,n,_):
 x,y,z,w=[u.reg_read(reg) for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
 if a==m.stop:u.emu_stop();return
 if a==0x14055b850:m.finish(app)
 elif a==0x140296470:
  calls.append(['object',y&0xffffffff]);obj=0 if c.get('missing') and y==99 else objects.get(y,0);m.wq(z,obj);m.finish(0 if obj else 1)
 elif a==0x140175070:m.finish(int(y in ids()))
 elif a==0x140364cc0:
  calls.append(['removeObject',y&0xffffffff]);values=ids();values.remove(y);writeids(values);m.finish(1)
 elif a==0x14035e820:
  values=ids();index=next((i for i,id in enumerate(values) if m.rf(objects[id]+0xa4)>=m.xmm(UC_X86_REG_XMM2)),len(values));m.wi(y,index);m.finish(1 if values else 0)
 elif a==0x14008ae10:writeids(ids()+[y&0xffffffff]);m.finish()
 elif a==0x140c417f0:u.mem_write(x,bytes(u.mem_read(y,z)));m.finish(x)
 elif a==m.stop+0x10:m.finish(x if int.from_bytes(u.mem_read(x+0xc,1),'little')==5 else 0)
 elif a==m.stop+0x20:m.finish(x if int.from_bytes(u.mem_read(x+0xc,1),'little')==11 else 0)
 elif a==0x14055b390:calls.append(['client',y&0xffffffff]);m.finish(0)
 elif a==0x140c10324:m.finish(event)
 elif a==0x1404c6490:u.mem_write(event,bytes(0x48));m.finish(event)
 elif a==0x1405570b0:calls.append(['event',y,z,w&0xffffffff,m.si(rsp+0x28)&0xffffffff,m.si(rsp+0x30),int.from_bytes(u.mem_read(m.q(rsp+0x38),2),'little')]);m.finish()
 elif a==0x14055b960:m.finish(app if c.get('hasAI',True) else 0)
 elif a==0x140494e80:calls.append(['area']);m.finish(area if m.si(actor+0xa0)&0xffffffff==88 else 0)
 elif a==0x14039e6b0:
  calls.append(['removeCreature',y]);m.wi(actor+0xa0,0x7f000000);values=ids()
  if 99 in values:values.remove(99);writeids(values)
  m.finish()
 elif a==0x1404f6720:calls.append(['addAoE',103,None if y==0 else 88,[m.xmm(UC_X86_REG_XMM2),m.xmm(UC_X86_REG_XMM3),m.rf(rsp+0x28)],m.si(rsp+0x30)]);m.finish()
 elif a==0x14055b3d0:
  calls.append(['creature',y&0xffffffff]);o=objects.get(y,0);m.finish(o if o and int.from_bytes(u.mem_read(o+0xc,1),'little')==5 else 0)
 elif a in [0x1404953b0,0x140495620]:calls.append(['dead' if a==0x1404953b0 else 'dying',m.si(x+8)&0xffffffff]);m.finish(c.get('dead',0) if a==0x1404953b0 else 0)
 elif a==0x14035ba90 and operation=='creature':calls.append(['addObject',y&0xffffffff,z]);m.finish(1)
 elif a==0x14049ae60:calls.append(['setArea',None if y==0 else 88]);m.wi(actor+0xa0,0x7f000000 if y==0 else 88);m.finish()
 elif a==0x140559cb0:calls.append(['ai',z]);m.wi(actor+0x7c,z);m.finish()
 elif not any(lo<=a<hi for lo,hi in [(0x14035ba90,0x14035bde3),(0x140380470,0x1403808b6)]):raise AssertionError(f'Uncaptured area add dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case,kind):
 global c,calls,operation
 c=case;calls=[];operation=kind;u.mem_write(m.heap,bytes(0x100000));m.wq(0x1412df970,app);m.wq(app+8,app)
 m.wq(vt+0x60,m.stop+0x10);m.wq(vt+0xa8,m.stop+0x20)
 for id,obj in objects.items():m.wq(obj,vt);m.wi(obj+8,id);u.mem_write(obj+0xc,bytes([c.get('type',5) if id==99 else 5 if id==100 else 11 if id==103 else 6]));m.wf(obj+0xa4,1 if id==99 else 0 if id==100 else 2)
 m.wq(actor+0xad0,stats);m.wi(actor+0xa0,88 if c.get('same') else 0x7f000000);m.wi(actor+0x7c,c.get('level',0));m.wi(actor+0x9f4,c.get('suppressed',0));m.wq(area+0x228,spatial);m.wi(area+0x234,64);m.wi(area+0x140,88);m.wi(area+0x150,c.get('players',1));writeids(c.get('ids',[100,101]))
 follow=c.get('following',[]);m.wq(actor+0x508,following);m.wi(actor+0x510,len(follow))
 for i,id in enumerate(follow):m.wi(following+i*4,id)
 rsp=m.stack+0x1fe08;u.mem_write(rsp-0x300,bytes(0x400));m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 if kind=='object':
  u.reg_write(UC_X86_REG_RCX,area);u.reg_write(UC_X86_REG_RDX,99);u.reg_write(UC_X86_REG_R8,c.get('flag',1));start=0x14035ba90
 else:
  u.reg_write(UC_X86_REG_RCX,actor);u.reg_write(UC_X86_REG_RDX,0 if c.get('nullArea') else area);u.reg_write(UC_X86_REG_XMM2,int.from_bytes(struct.pack('<f',3),'little'));u.reg_write(UC_X86_REG_XMM3,int.from_bytes(struct.pack('<f',4),'little'));m.wf(rsp+0x28,5);m.wi(rsp+0x30,c.get('force',0));m.wi(rsp+0x38,c.get('flag',1));start=0x140380470
 u.emu_start(start,m.stop,count=10000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=c,calls=calls,result=u.reg_read(UC_X86_REG_RAX)&0xffffffff,ids=ids(),areaId=m.si(actor+0xa0)&0xffffffff,position=list(struct.unpack('<3f',u.mem_read(actor+0xa4,12))),level=m.si(actor+0x7c))
objectRows=[run(dict(type=type,flag=flag,suppressed=suppressed,ids=values,missing=missing),'object') for type,flag,suppressed,values,missing in itertools.product([5,6],[0,1,2],[0,1],[[],[100,101],[100,99,101]],[False,True])]
creatures=[run(dict(same=same,force=force,players=players,level=level,hasAI=hasAI,following=follow),'creature') for same,force,players,level,hasAI,follow in itertools.product([False,True],[0,1],[0,1],[0,1,2],[False,True],[[],[103,104]])]
creatures += [run(dict(nullArea=True,following=[103,104]),'creature')]
out=m.root/'backups/animations/native-creature-area-add-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,objects=objectRows,creatures=creatures))+'\n');print(json.dumps(dict(objects=len(objectRows),creatures=len(creatures),output=str(out))))
