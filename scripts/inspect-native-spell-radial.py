"""Untouched client target admission1409a4910 and selection1409a4540.
Client object resolution, controlled creature and final cast submission are
captured boundaries. This verifies target bits and packed selection fields,
not full radial rendering, client replication or network serialization.
"""
import importlib.util,itertools,json
from pathlib import Path
spec=importlib.util.spec_from_file_location('fixture',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
radial,actor,target,spell,rules,manager,vt,point=[m.heap+n*0x1000 for n in range(1,9)]
def hook(u,a,n,_):
 if a==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(reg) for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
 if a==0x1402af4a0:m.finish(0 if c.get('missing') else spell)
 elif a==0x1406abb60:m.finish(0 if c.get('type') is None else target)
 elif a==0x1406ac1a0:m.finish(actor)
 elif a==m.stop+0x10:m.finish((actor if c.get('self') else target) if c.get('type')==5 else 0)
 elif a==0x140804d00:
  calls.append(dict(spellId=y&0xffffffff,targetId=z&0xffffffff,position=[m.rf(w+i*4) for i in range(3)],
   classIndex=m.si(rsp+0x28)&255,domainLevel=m.si(rsp+0x30)&255,metamagic=m.si(rsp+0x38)&255,spontaneous=m.si(rsp+0x40)))
  m.finish()
 elif not any(lo<=a<hi for lo,hi in [(0x1409a4910,0x1409a4b10),(0x1409a4540,0x1409a4605)]):raise AssertionError(f'Uncaptured radial dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case,selection=False):
 global c,calls
 c=case;calls=[];u.mem_write(m.heap,bytes(0x100000));m.wq(0x1412df970,manager);m.wq(manager,manager);m.wq(0x1412df8f8,rules);m.wq(rules+0xd0,rules)
 m.wq(target,vt);m.wq(vt+0x58,m.stop+0x10);u.mem_write(target+0xc,bytes([c.get('type') or 0]));m.wi(radial+0x88c,99)
 u.mem_write(radial+0x898,int(c.get('filter',65535)).to_bytes(2,'little'));u.mem_write(spell+0x50,int(c.get('mask',0)).to_bytes(2,'little'))
 for i,v in enumerate([1.25,2.5,3.75]):m.wf(radial+0x880+i*4,v)
 rsp=m.stack+0x1fe08;u.mem_write(rsp-0x100,bytes(0x200));m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,radial)
 packed=c.get('spellId',10)|c.get('domainLevel',0)<<24|(c.get('classIndex',0)&3)<<28|(c.get('classIndex',0)&4)<<36|c.get('metamagic',0)<<31|c.get('spontaneous',0)<<37
 u.reg_write(UC_X86_REG_RDX,packed if selection else 10)
 u.emu_start(0x1409a4540 if selection else 0x1409a4910,m.stop,count=2000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=c,**(dict(calls=calls) if selection else dict(result=u.reg_read(UC_X86_REG_RAX)&0xffffffff)))
rows=[run(dict(type=t,self=s,mask=mask,filter=filter,missing=missing)) for t,s,mask,filter,missing in itertools.product([None,5,6,7,8,9,10,11],[False,True],[0,1,2,4,8,16,32,64,127,65535],[65535,1,2,4,32],[False,True])]
selections=[run(dict(spellId=id,classIndex=index,domainLevel=domain,metamagic=meta,spontaneous=converted),True) for id,index,domain,meta,converted in itertools.product([0,100,65535],range(8),[0,1,9,15],[0,1,2,4,8,16,32,63],[0,1])]
out=m.root/'backups/animations/native-spell-radial-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows,selections=selections))+'\n');print(json.dumps(dict(rows=len(rows),selections=len(selections),output=str(out))))
