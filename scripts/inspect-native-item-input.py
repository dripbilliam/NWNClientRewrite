"""Complete original HandlePlayerToServerInputMessage1404531b0 dispatched
to subtype9. Decoded scalar reads, client creature cast, action manager,
UseItem and feedback are captured boundaries. No packet codec/GUI claim.
"""
import importlib.util,itertools,json,struct
from pathlib import Path
spec=importlib.util.spec_from_file_location('fixture',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
message,client,obj,actor,vt=[m.heap+n*0x1000 for n in range(1,6)]
def hook(u,a,n,_):
 global byte,boolean,objectRead,axis,overflow
 if a==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(reg) for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
 if a==0x1404ba840:calls.append(['clientObject']);m.finish(obj if c.get('object',True) else 0)
 elif a==m.stop+0x10:calls.append(['asCreature']);m.finish(actor if c.get('creature',True) else 0)
 elif a==0x1402d9460:overflow+=1;calls.append(['overflow']);m.finish(int(c.get('overflow',0)==overflow))
 elif a==0x1402d9520:calls.append(['underflow']);m.finish(c.get('underflow',0))
 elif a==0x140476130:objectRead+=1;calls.append(['readObjectId']);m.finish(c.get('itemId',55) if objectRead==1 else c.get('targetId',100))
 elif a==0x1402d9630:byte+=1;calls.append(['readByte']);m.finish(c.get('propertyIndex',0) if byte==1 else c.get('variant',3))
 elif a==0x1402d9600:boolean+=1;calls.append(['readBool']);m.finish([c.get('hasVariant',0),c.get('hasTarget',1),c.get('hasPoint',0)][boolean-1])
 elif a==0x1402d9c30:
  calls.append(['readFloat']);u.reg_write(UC_X86_REG_XMM0,struct.unpack('<I',struct.pack('<f',[1.25,2.5,3.75][axis]))[0]);axis+=1;m.finish()
 elif a==0x14037cbc0:calls.append(['actionManager',y&0xffffffff]);m.finish()
 elif a==0x1403a9f70:
  ptr=m.q(rsp+0x30);calls.append(['use',y&0xffffffff,z&255,w&255,m.si(rsp+0x28)&0xffffffff,[m.rf(ptr+i*4) for i in range(3)],m.si(rsp+0x38)&0xffffffff,m.si(rsp+0x40)]);m.finish(c.get('useResult',1))
 elif a==0x1403a2480:calls.append(['feedback',y&0xffffffff]);m.finish()
 elif not 0x1404531b0<=a<0x140455858:raise AssertionError(f'Uncaptured item input dependency {a:x} {c}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,calls,byte,boolean,objectRead,axis,overflow
 c=case;calls=[];byte=boolean=objectRead=axis=overflow=0;u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));m.wq(obj,vt);m.wq(vt+0x60,m.stop+0x10);m.wi(actor+0x8ac,c.get('field8ac',0));m.wi(actor+0xa0,c.get('areaId',7));m.wi(actor+0xec,c.get('commandable',1))
 rsp=m.stack+0x1fc08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,message);u.reg_write(UC_X86_REG_RDX,client);u.reg_write(UC_X86_REG_R8,9);u.emu_start(0x1404531b0,m.stop,count=50000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=c,result=u.reg_read(UC_X86_REG_RAX)&0xffffffff,calls=calls)
cases=[dict(propertyIndex=i,variant=v,hasVariant=hv,hasTarget=ht,hasPoint=hp,useResult=r,commandable=commandable) for i,v,hv,ht,hp,r,commandable in itertools.product([0,255,256],[0,255,256],[0,1],[0,1],[0,1],[0,1,2,-1],[0,1])]
cases += [dict(**{key:v}) for key,values in {'object':[False],'creature':[False],'field8ac':[1,-1],'overflow':[1,2],'underflow':[1],'areaId':[0x7f000000],'hasVariant':[2],'hasTarget':[2],'hasPoint':[2]}.items() for v in values]
out=m.root/'backups/animations/native-item-input-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=[run(c) for c in cases]))+'\n');print(json.dumps(dict(cases=len(cases),output=str(out))))
