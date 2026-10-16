"""Original area RemoveObject140364cc0 and creature RemoveFromArea14039e6b0.
Capture lookup, visibility, event, AI, following-AoE and barter boundaries.
Spatial erase, client counts, flags, loop order and final identity/XYZ execute.
"""
import importlib.util,itertools,json,struct
from pathlib import Path
spec=importlib.util.spec_from_file_location('fixture',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
actor,area,app,spatial,stats,vt,following,event,service,barter,client=[m.heap+n*0x1000 for n in range(1,12)]
objects={99:actor,**{id:m.heap+0x10000+(id-100)*0x2000 for id in range(100,106)}}
def readids():return [m.si(spatial+i*4)&0xffffffff for i in range(m.si(area+0x230))]
def erase(id):
 ids=readids()
 if id in ids:ids.remove(id)
 m.wi(area+0x230,len(ids))
 for i,v in enumerate(ids):m.wi(spatial+i*4,v)
def hook(u,a,n,_):
 x,y,z,w=[u.reg_read(reg) for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
 if a==m.stop:u.emu_stop();return
 if a==0x1400b3ed0:ids=readids();m.finish(ids.index(y) if y in ids else 0xffffffff)
 elif a==0x140c417f0:u.mem_write(x,bytes(u.mem_read(y,z)));m.finish(x)
 elif a==0x14055b390:calls.append(['client',y&0xffffffff]);m.finish(client if c.get('client') else 0)
 elif a in [0x14055b850,0x14055b960]:m.finish(app)
 elif a==0x140296470:calls.append(['object',y&0xffffffff]);m.wq(z,objects.get(y,0));m.finish(0 if y in objects else 1)
 elif a==m.stop+0x10:m.finish(x if int.from_bytes(u.mem_read(x+0xc,1),'little')==5 else 0)
 elif a==m.stop+0x20:m.finish(x if int.from_bytes(u.mem_read(x+0xc,1),'little')==11 else 0)
 elif a==m.stop+0x30:calls.append(['playerLeft']);m.finish()
 elif a==0x140559cb0:calls.append(['ai',m.si(y+8)&0xffffffff,z]);m.wi(y+0x7c,z);m.finish()
 elif a==0x14055b3d0:
  calls.append(['creature',y&0xffffffff]);o=objects.get(y,0);m.finish(o if o and int.from_bytes(u.mem_read(o+0xc,1),'little')==5 else 0)
 elif a==0x1404953b0:calls.append(['dead',m.si(x+8)&0xffffffff]);m.finish(c.get('dead',0))
 elif a==0x140c10324:m.finish(event)
 elif a==0x1404c6490:u.mem_write(event,bytes(0x48));data.clear();m.finish(event)
 elif a==0x1404c72e0:data.setdefault('integers',{})[str(y)]=z&0xffffffff;m.finish()
 elif a==0x1404c7320:data.setdefault('objectIds',{})[str(y)]=z&0xffffffff;m.finish()
 elif a==0x1405570b0:calls.append(['event',y,z,w&0xffffffff,m.si(rsp+0x28)&0xffffffff,m.si(rsp+0x30),int.from_bytes(u.mem_read(m.q(rsp+0x38),2),'little'),json.loads(json.dumps(data))]);m.finish()
 elif a==0x140494e80:calls.append(['area']);m.finish(area if m.si(actor+0xa0)&0xffffffff==88 else 0)
 elif a==0x140364cc0 and operation=='creature':calls.append(['removeObject',y&0xffffffff]);erase(y&0xffffffff);m.finish(1)
 elif a==0x1403d3760:calls.append(['clearVisible']);m.finish()
 elif a==0x1403d5850:
  id=m.si(x+8)&0xffffffff;calls.append(['visibility',id,y&0xffffffff]);ptr=x+0x1000;m.finish(ptr if c.get('flags',3)>=0 else 0)
 elif a==0x1403d7390:calls.append(['removeVisible',m.si(x+8)&0xffffffff,y&0xffffffff]);m.finish()
 elif a==0x1404f8bb0:calls.append(['removeAoE',m.si(x+8)&0xffffffff]);m.finish()
 elif a==0x14049ae60:calls.append(['setArea',None]);m.wi(actor+0xa0,0x7f000000);m.finish()
 elif a==0x140372dc0:calls.append(['barter']);m.finish()
 elif not any(lo<=a<hi for lo,hi in [(0x140364cc0,0x140364eba),(0x14039e6b0,0x14039e9a5)]):raise AssertionError(f'Uncaptured area removal dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case,kind):
 global c,calls,data,operation
 c=case;operation=kind;calls=[];data={};u.mem_write(m.heap,bytes(0x100000));m.wq(0x1412df970,app);m.wq(app+8,app)
 m.wq(vt+0x60,m.stop+0x10);m.wq(vt+0xa8,m.stop+0x20);m.wq(vt+0x20,m.stop+0x30)
 for id,obj in objects.items():
  m.wq(obj,vt);m.wi(obj+8,id);u.mem_write(obj+0xc,bytes([5 if id in [99,100,103] else 11 if id==104 else 9]));m.wi(obj+0x7c,1);u.mem_write(obj+0x1004,bytes([max(0,c.get('flags',3))]))
 m.wi(actor+0xa0,0x7f000000 if c.get('noArea') else 88);m.wq(actor+0xad0,stats);m.wi(stats+0xb0,c.get('pc',0));m.wi(actor+0x9f4,c.get('suppressed',0));u.mem_write(actor+0xa4,struct.pack('<3f',1,2,3))
 ids=c.get('ids',[99,100,101,103]);m.wq(area+0x228,spatial);m.wi(area+0x230,len(ids));m.wi(area+0x140,88);m.wi(area+0x150,c.get('players',1))
 for i,id in enumerate(ids):m.wi(spatial+i*4,id)
 if c.get('service'):m.wq(area+0x328,service);m.wq(service,vt)
 if c.get('barter'):m.wq(actor+0x890,barter)
 follow=c.get('following',[]);m.wq(actor+0x508,following);m.wi(actor+0x510,len(follow))
 for i,id in enumerate(follow):m.wi(following+i*4,id)
 rsp=m.stack+0x1fe08;u.mem_write(rsp-0x300,bytes(0x400));m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,area if kind=='object' else actor);u.reg_write(UC_X86_REG_RDX,c.get('id',99) if kind=='object' else c.get('skip',0))
 u.emu_start(0x140364cc0 if kind=='object' else 0x14039e6b0,m.stop,count=10000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=c,calls=calls,ids=readids(),players=m.si(area+0x150),areaId=m.si(actor+0xa0)&0xffffffff,position=list(struct.unpack('<3f',u.mem_read(actor+0xa4,12))),levels={str(id):m.si(obj+0x7c) for id,obj in objects.items()})
objectsRows=[run(dict(client=hasClient,players=players,dead=dead,suppressed=suppressed,ids=ids),'object') for hasClient,players,dead,suppressed,ids in itertools.product([False,True],[0,1,2],[0,1],[0,1],[[99,100,101,103],[100,101,99,99],[100,101],[0x7f000000,99]])]
creatures=[run(dict(skip=skip,flags=flags,pc=pc,service=hasService,barter=hasBarter,noArea=noArea,following=follow),'creature') for skip,flags,pc,hasService,hasBarter,noArea,follow in itertools.product([0,1],[-1,0,1,2,3],[0,1],[False,True],[False,True],[False,True],[[],[104,105,0x7f000000,104]])]
out=m.root/'backups/animations/native-creature-area-removal-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,objects=objectsRows,creatures=creatures))+'\n');print(json.dumps(dict(objects=len(objectsRows),creatures=len(creatures),output=str(out))))
