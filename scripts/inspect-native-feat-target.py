"""Original client feat target140703310 and GetSubRadialSpell. Feat/spell
lookup, action/mode callbacks, target registration and previews are captured.
No claim of full native pointer picking, modal GUI or packet serialization.
"""
import importlib.util,itertools,json,struct
from pathlib import Path
spec=importlib.util.spec_from_file_location('fixture',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
context,feat,parent,child,ids,rules,manager=[m.heap+n*0x1000 for n in range(1,8)]
def hook(u,a,n,_):
 if a==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(reg) for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
 if a==0x1402a3bd0:lookups.append(['feat',y&65535]);m.finish(0 if c.get('missingFeat') else feat)
 elif a==0x1406ac1c0:m.finish(99)
 elif a==0x140702ad0:calls.append(['mode',y&0xffffffff]);m.finish()
 elif a==0x140702a50:calls.append(['feat',y&0xffffffff,m.si(context+0x14c)&0xffffffff]);m.finish()
 elif a==0x1402af4a0:
  id=y&0xffffffff;lookups.append(['spell',id]);m.finish(0 if c.get('missingSpell') or id==11 and c.get('missingChild') else parent if id==10 else child if id==11 else 0)
 elif a==0x14083bac0:types.append([y&0xffffffff,z&0xffffffff]);m.finish()
 elif a==0x140704a50:u.reg_write(UC_X86_REG_XMM0,struct.unpack('<I',struct.pack('<f',3.5))[0]);m.finish()
 elif a==0x140704bd0:calls.append(['preview',w&0xffffffff,m.si(rsp+0x28)]);m.finish()
 elif not any(lo<=a<hi for lo,hi in [(0x140703310,0x14070364a),(0x1402af850,0x1402af8c2)]):raise AssertionError(f'Uncaptured feat target dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,calls,lookups,types
 c=case;calls=[];lookups=[];types=[];u.mem_write(m.heap,bytes(0x100000));m.wq(0x1412df970,manager);m.wq(manager,manager);m.wq(0x1412df8f8,rules);m.wq(rules+0xd0,rules);m.wi(context+0x14c,0x7f000000)
 m.wi(feat+0x2c,c.get('targetSelf',0));m.wi(feat+0x60,c.get('spellId',10));u.mem_write(0x1412970b0,bytes([c.get('autoSelf',1)&255]));u.mem_write(parent+0x50,struct.pack('<H',c.get('mask',3)));u.mem_write(child+0x50,struct.pack('<H',c.get('childMask',1)));m.wq(parent+0x168,ids);u.mem_write(parent+0x170,bytes([c.get('childCount',0)]));m.wi(ids,11);m.wi(child+0x198,c.get('childFeat',0)<<16)
 packed=(c.get('featId',257)&65535)|((c.get('auxiliary',0)&65535)<<16);signed=packed if packed<0x80000000 else packed|0xffffffff00000000
 rsp=m.stack+0x1fe08;u.mem_write(rsp-0x100,bytes(0x200));m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,context);u.reg_write(UC_X86_REG_RDX,signed)
 u.emu_start(0x140703310,m.stop,count=3000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=c,result=u.reg_read(UC_X86_REG_RAX)&0xffffffff,calls=calls,lookups=lookups,types=types)
cases=[dict(featId=id,auxiliary=aux,targetSelf=self,autoSelf=auto) for id,aux,self,auto in itertools.product([19,28,30,204,899,866,389,390,425,947,257,305],[0,1],[0,1,-1],[0,1,255])]
cases += [dict(auxiliary=aux,mask=mask,childCount=1,childFeat=childFeat,childMask=childMask) for aux,mask,childFeat,childMask in itertools.product([0,1,65535],[0,1,2,3,4,8,16,32,64,127,65535],[0,1,65535],[1,4,9])]
cases += [dict(missingFeat=True),dict(spellId=-1),dict(missingSpell=True),dict(childCount=1,missingChild=True)]
rows=[run(c) for c in cases];out=m.root/'backups/animations/native-feat-target-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows))+'\n');print(json.dumps(dict(rows=len(rows),output=str(out))))
