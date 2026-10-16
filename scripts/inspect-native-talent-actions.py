"""Complete original talent object/location wrappers140380fb0/140380e20,
script command14050f620 and accessors1405485f0. VM primitives, registry, area,
RNG, lower UseFeat/UseSkill/UseItem/AddCastSpellActions and cleanup captured.
No claim of native VM internals or complete lower item/skill/spell effects.
"""
import importlib.util,itertools,json,struct
from pathlib import Path
spec=importlib.util.spec_from_file_location('fixture',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
command,vm,app,actor,target,area,talent,location=[m.heap+n*0x1000 for n in range(1,9)]
ranges=[(0x140380fb0,0x140381205),(0x140380e20,0x140380fae),(0x14050f620,0x14050f7dc),(0x1405485f0,0x140548688)]
def point(ptr):return list(struct.unpack('<3f',u.mem_read(ptr,12))) if ptr else None
def cast(rsp,y,z,w):return dict(spellId=y&0xffffffff,classIndex=z&255,domainLevel=w&255,metamagic=m.si(rsp+0x28)&255,spontaneous=m.si(rsp+0x30),position=point(m.q(rsp+0x38)),targetId=m.si(rsp+0x40)&0xffffffff,location=m.si(rsp+0x48),front=m.si(rsp+0x50),cheat=m.si(rsp+0x58),path=m.si(rsp+0x60)&255,instant=m.si(rsp+0x68),featId=m.si(rsp+0x78),casterLevel=m.si(rsp+0x80)&255)
def hook(u,a,n,_):
 global pops,pushed
 if a==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(reg) for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
 if a==0x140286030:
  name='talent' if y==3 else 'location';pops.append(name);okay=len(pops)!=c.get('failPop',0)
  if okay:m.wq(z,talent if y==3 else location)
  m.finish(int(okay))
 elif a==0x140286160:
  pops.append('object');okay=len(pops)!=c.get('failPop',0)
  if okay:m.wi(y,c.get('targetId',100))
  m.finish(int(okay))
 elif a==0x14055b3d0:calls.append(['creature',y&0xffffffff]);m.finish(actor if y==99 and c.get('selfExists',True) else target if y!=99 and c.get('targetCreature',True) else 0)
 elif a==0x140494e80:calls.append(['area']);m.finish(area if c.get('area',True) else 0)
 elif a==0x140490b80:calls.append(['clearActions']);m.finish()
 elif a==0x140c7ed00:calls.append(['random']);m.finish(c.get('random',1))
 elif a==0x1403a91d0:calls.append(['feat',y&65535,z&65535,w&0xffffffff,m.si(rsp+0x28)&0xffffffff,point(m.q(rsp+0x30))]);m.finish(c.get('lowerResult',1))
 elif a==0x1403aa390:calls.append(['skill',y&255,z&255,w&0xffffffff,point(m.q(rsp+0x28)),m.si(rsp+0x30)&0xffffffff,m.si(rsp+0x38)&0xffffffff,m.si(rsp+0x40)]);m.finish(c.get('lowerResult',1))
 elif a==0x1403a9f70:calls.append(['item',y&0xffffffff,z&255,w&255,m.si(rsp+0x28)&0xffffffff,point(m.q(rsp+0x30)),m.si(rsp+0x38)&0xffffffff,m.si(rsp+0x40)]);m.finish(c.get('lowerResult',1))
 elif a==0x14037d540:calls.append(['cast',cast(rsp,y,z,w)]);m.finish(c.get('lowerResult',1))
 elif a==0x140286410:pushed=y&0xffffffff;pushed=pushed if pushed<0x80000000 else pushed-0x100000000;m.finish(c.get('push',1))
 elif a==0x14048c550:cleanup.append('talent');m.finish()
 elif a==0x140c10360:cleanup.append('location' if x==location else 'talent-free');m.finish()
 elif not any(lo<=a<hi for lo,hi in ranges):raise AssertionError(f'Uncaptured talent action dependency {a:x} {c}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case,mode):
 global c,calls,pops,pushed,cleanup
 c=case;calls=[];pops=[];pushed=None;cleanup=[];u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));m.wq(0x1412df910,vm);m.wq(0x1412df970,app);m.wq(app+8,app);m.wi(command+12,99);m.wi(actor+0xec,c.get('commandable',1));m.wi(area+0x140,c.get('areaId',7))
 for index,value in enumerate([1.25,2.5,3.75]):m.wf(target+0xa4+index*4,value)
 for index,value in enumerate([4.5,-6.25,8.75]):m.wf(location+index*4,value)
 m.wi(location+0x18,12345) # Native talent location wrapper ignores this area.
 m.wi(talent,c.get('type',0));m.wi(talent+4,c.get('id',100));u.mem_write(talent+8,bytes([c.get('classIndex',254)&255]));m.wi(talent+12,c.get('itemId',0x7f000000));m.wi(talent+16,c.get('propertyIndex',-1));u.mem_write(talent+20,bytes([c.get('casterLevel',7)&255,c.get('metamagic',0)&255]))
 rsp=m.stack+0x1fc08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 if mode.startswith('wrapper'):
  values=[actor,c.get('type',0),c.get('id',100),location if mode.endswith('location') else c.get('targetId',100)]
  for offset,value in [(0x28,c.get('classIndex',254)),(0x30,c.get('itemId',0x7f000000)),(0x38,c.get('propertyIndex',-1)),(0x40,c.get('casterLevel',7)),(0x48,c.get('metamagic',0))]:m.wi(rsp+offset,value)
  start=0x140380e20 if mode.endswith('location') else 0x140380fb0
 else:
  ordinal=c.get('ordinal',310 if mode.endswith('location') else 309);values=[command,ordinal,2,0];start=0x1405485f0 if mode=='access' else 0x14050f620
 for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],values):u.reg_write(reg,value&0xffffffffffffffff)
 u.emu_start(start,m.stop,count=30000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 result=u.reg_read(UC_X86_REG_RAX)&0xffffffff;result=result if result<0x80000000 else result-0x100000000
 return dict(case=c,mode=mode,result=result,calls=calls,pops=pops,pushed=pushed,cleanup=cleanup)
rows=[]
cases=[dict(type=typ,id=id,commandable=cmd,targetCreature=target,area=area,areaId=areaId,itemId=item,propertyIndex=prop,lowerResult=result) for typ,id,cmd,target,area,areaId,item,prop,result in itertools.product([-2,-1,0,1,2,3],[5,100,65541],[0,1,-1],[False,True],[False,True],[7,0x7f000000],[0x7f000000,55],[-1,0,257],[0,1])]
rows=[run(c,mode) for c in cases for mode in ['wrapper-object','wrapper-location']]
scriptcases=[dict(type=typ,id=id,selfExists=exists,targetCreature=target,itemId=item,propertyIndex=prop,classIndex=cls,casterLevel=258,metamagic=511) for typ,id,exists,target,item,prop,cls in itertools.product([-2147483648,-2,-1,0,1,2,3],[5,100],[False,True],[False,True],[0x7f000000,55],[-1,257],[0,254,255,511])]
rows += [run(c,mode) for c in scriptcases for mode in ['script-object','script-location']]
rows += [run(dict(failPop=fail),mode) for fail in [1,2] for mode in ['script-object','script-location']]
rows += [run(dict(type=typ,id=id,ordinal=ordinal,push=push,failPop=pop), 'access') for typ,id,ordinal,push,pop in itertools.product([-2147483648,-2,-1,0,1,2,2147483647],[-2147483648,-1,0,65535,2147483647],[362,363],[0,1],[0,1])]
out=m.root/'backups/animations/native-talent-action-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows))+'\n');print(json.dumps(dict(rows=len(rows),output=str(out))))
