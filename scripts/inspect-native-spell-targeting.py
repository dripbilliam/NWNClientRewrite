"""Untouched client target setup140704720, creature veto140704640 and
selection140704300. Full original owners execute; controlled/client objects,
spell lookup, range/preview/render and final message are captured boundaries.
GetSubRadialSpell executes. No claim of complete GUI or packet serialization.
"""
import importlib.util,itertools,json,struct
from pathlib import Path
spec=importlib.util.spec_from_file_location('fixture',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
context,actor,creature,parent,child,children,rules,manager,inventory,container=[m.heap+n*0x1000 for n in range(1,11)]
ranges=[(0x140704720,0x140704a18),(0x140704640,0x14070471f),(0x140704300,0x1407043d4),(0x1402af850,0x1402af8c2)]
def hook(u,a,n,_):
 if a==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(reg) for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
 if a==0x1406ac1a0:m.finish(actor if c.get('controlled',True) else 0)
 elif a==0x1402af4a0:
  lookups.append(y&0xffffffff);m.finish(parent if y&0xffffffff==10 and not c.get('missingParent') else child if y&0xffffffff==c.get('childId',11)&0xffffffff and not c.get('missingChild') else 0)
 elif a==0x1406abbe0:m.finish(inventory if c.get('inventoryMode') is not None else 0)
 elif a==0x1406abfd0:m.finish(container if c.get('containerMode') is not None else 0)
 elif a==0x140704420:calls.append(['ability',y]);m.finish()
 elif a==0x140804d00:
  calls.append(['cast',y&0xffffffff,z&0xffffffff,[m.rf(w+i*4) for i in range(3)],m.si(rsp+0x28)&255,m.si(rsp+0x30)&255,m.si(rsp+0x38)&255,m.si(rsp+0x40)]);m.finish()
 elif a==0x14083bac0:types.append([y&0xffffffff,z&0xffffffff]);m.finish()
 elif a==0x140704a50:u.reg_write(UC_X86_REG_XMM0,struct.unpack('<I',struct.pack('<f',3.5))[0]);m.finish()
 elif a==0x140704bd0:
  calls.append(['preview',u.reg_read(UC_X86_REG_XMM0)&0xffffffff,u.reg_read(UC_X86_REG_XMM1)&0xffffffff,z&0xffffffff,w&0xffffffff,m.si(rsp+0x28)]);m.finish()
 elif a==0x1406ab9e0:m.finish(creature if c.get('creature') else 0)
 elif a==0x1406ac1c0:m.finish(99)
 elif a in [0x140704bb0,0x140704b90,0x14083b890,0x140c10360]:m.finish()
 elif not any(lo<=a<hi for lo,hi in ranges):raise AssertionError(f'Uncaptured targeting dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case,gate=False,selection=False):
 global c,calls,lookups,types
 c=case;calls=[];lookups=[];types=[];u.mem_write(m.heap,bytes(0x100000));m.wq(0x1412df970,manager);m.wq(manager,manager);m.wq(0x1412df8f8,rules);m.wq(rules+0xd0,rules)
 m.wi(actor+8,99);m.wi(creature+8,99 if c.get('self') else 100)
 for i,v in enumerate([1.25,2.5,3.75]):m.wf(actor+0x38+i*4,v);m.wf(context+0x140+i*4,v)
 m.wi(context+0x14c,99);m.wi(inventory+0xb0,c.get('inventoryMode') or 0);m.wi(container+0xb0,c.get('containerMode') or 0)
 for obj,mask in [(parent,c.get('mask',3)),(child,c.get('childMask',2))]:
  u.mem_write(obj+0x50,struct.pack('<H',mask&65535));m.wi(obj+0x194,123);m.wi(obj+0x1a4,456);m.wi(obj+0x1b0,789);m.wf(obj+0x1a8,2.25);m.wf(obj+0x1ac,4.5)
 u.mem_write(parent+0x170,bytes([c.get('childCount',0)&255]));m.wq(parent+0x168,children);m.wi(children,c.get('childId',11))
 u.mem_write(0x141297120,bytes([c.get('autoSelf',1)&255]))
 packed=(c.get('spellId',10)&65535)|(c.get('domainLevel',0)&15)<<24|(c.get('classIndex',0)&3)<<28|(c.get('classIndex',0)&4)<<36|(c.get('metamagic',0)&63)<<31|(c.get('spontaneous',0)&1)<<37
 m.wq(context+0x150,packed)
 rsp=m.stack+0x1fe08;u.mem_write(rsp-0x180,bytes(0x300));m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,context);u.reg_write(UC_X86_REG_RDX,100 if gate else packed);u.reg_write(UC_X86_REG_R8,c.get('ability',0))
 u.emu_start(0x140704640 if gate else 0x140704300 if selection else 0x140704720,m.stop,count=3000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=c,result=u.reg_read(UC_X86_REG_RAX)&0xffffffff,lookups=lookups,types=types,calls=calls,callback=hex(m.q(context+0xe8)),targetId=m.si(context+0x14c)&0xffffffff,position=[m.rf(context+0x140+i*4) for i in range(3)])
rows=[run(dict(mask=mask,childMask=childMask,childCount=children,autoSelf=auto,inventoryMode=inv,containerMode=cont,ability=ability)) for mask,childMask,children,auto,inv,cont,ability in itertools.product([0,1,2,3,4,5,8,9,127,65535],[1,3,5,9],[0,1],[0,1,255],[None,0,1,2],[None,1],[0,1])]
rows += [run(c) for c in [dict(controlled=False),dict(missingParent=True),dict(childCount=1,missingChild=True),dict(spellId=65546,mask=1),dict(childCount=1,childId=-1,missingChild=True)]]
gates=[run(dict(mask=mask,childMask=childMask,childCount=count,creature=creature,self=self),gate=True) for mask,childMask,count,creature,self in itertools.product([0,1,2,3,4,9,65535],[0,1,2,3],[0,1],[False,True],[False,True])]
gates += [run(c,gate=True) for c in [dict(missingParent=True),dict(childCount=1,missingChild=True)]]
selections=[run(dict(classIndex=index,domainLevel=domain,metamagic=meta,spontaneous=converted),selection=True) for index,domain,meta,converted in itertools.product(range(8),[0,9,15],[0,1,32,63],[0,1])]
out=m.root/'backups/animations/native-spell-targeting-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows,gates=gates,selections=selections))+'\n');print(json.dumps(dict(rows=len(rows),gates=len(gates),selections=len(selections),output=str(out))))
