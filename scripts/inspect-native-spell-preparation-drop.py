"""Execute original CSpellBox drop1409c21d0 and completion1409c2340 unchanged.
Only GetType, SetSpell and Clear publication boundaries are captured; no live
client/server is used. Constructor-registered selection restore runs unchanged
with no outstanding highlighted level. Ready writes execute in the binary;
icon pointers are null, so this is policy/write-order, not GPU/input proof.
"""
import importlib.util,itertools,json
from pathlib import Path
spec=importlib.util.spec_from_file_location('image',Path(__file__).with_name('inspect-native-intratile-coordinator.py'))
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
source,destination,hit,owner,vtable,gettype=[m.heap+n for n in [0x1000,0x2000,0x3000,0x4000,0xe0000,0xf0000]]
writes=[]
def hook(u,a,n,_):
 if a==m.stop:u.emu_stop();return
 if a==gettype:m.finish(0x53704278);return
 if a==0x1409c2630:
  x=u.reg_read(UC_X86_REG_RCX);rsp=u.reg_read(UC_X86_REG_RSP)
  spell=u.reg_read(UC_X86_REG_RDX)&0xffffffff;meta=m.si(rsp+0x28);domain=u.reg_read(UC_X86_REG_R9)&0xffffffff;cls=m.si(rsp+0x30)&255
  writes.append(dict(target='source' if x==source else 'destination',clear=False,spellId=spell,metamagic=meta,domain=domain,classIndex=cls,slot=m.si(x+0x150),level=m.si(x+0x154)))
  m.wi(x+0x144,spell);m.wi(x+0x160,meta);m.wi(x+0x164,domain);u.mem_write(x+0x15c,bytes([cls]));m.finish();return
 if a==0x1409c1fc0:
  x=u.reg_read(UC_X86_REG_RCX);assert u.reg_read(UC_X86_REG_RDX)==1
  writes.append(dict(target='source' if x==source else 'destination',clear=True,classIndex=int.from_bytes(u.mem_read(x+0x15c,1),'little'),slot=m.si(x+0x150),level=m.si(x+0x154)))
  m.wi(x+0x144,-1);m.finish();return
 if not any(lo<=a<=hi for lo,hi in [(0x1409c21d0,0x1409c2336),(0x1409c2340,0x1409c245f),(0x1408900f0,0x140890129)]):raise AssertionError(f'Uncaptured original spell dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(address,*args):
 rsp=m.stack+0x1fe08;u.mem_write(m.stack,bytes(0x20000));m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],args):u.reg_write(reg,value)
 u.emu_start(address,m.stop,count=10000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return u.reg_read(UC_X86_REG_RAX)&0xffffffff
rows=[]
for kind,old,domain,dest_domain,meta,dest_meta,cls in itertools.product([0,1],[-1,7],[0,1],[0,1],[0,1,2,32],[0,4,16],[0,7]):
 writes=[];u.mem_write(m.heap,bytes(0x100000));m.wq(vtable+0x20,gettype)
 for ptr,mode,spell,mm,dd,slot in [(source,kind,5,meta,domain,0),(destination,0,old,dest_meta,dest_domain,2)]:
  m.wq(ptr,vtable);m.wi(ptr+0x140,mode);m.wi(ptr+0x144,spell);m.wi(ptr+0x150,slot);m.wi(ptr+0x154,3);m.wi(ptr+0x158,1);m.wi(ptr+0x160,mm);m.wi(ptr+0x164,dd);u.mem_write(ptr+0x15c,bytes([cls]))
 m.wq(0x1412992c0,owner);m.wq(0x1412992c8,0x1408900f0);m.wi(owner+0x17e0,-2)
 flags=run(0x1409c21d0,destination,0x40,source)
 final=run(0x1409c2340,source,flags,source,hit)
 rows.append(dict(kind=kind,old=old,domain=domain,destDomain=dest_domain,metamagic=meta,destMetamagic=dest_meta,classIndex=cls,writes=writes,flags=flags,finalFlags=final,sourceReady=m.si(source+0x158),destinationReady=m.si(destination+0x158)))
out=m.root/'backups/animations/native-spell-preparation-drop-observations-v1.json';assert not out.exists(),'Preserve prior evidence'
out.write_text(json.dumps(dict(target=m.digest,scope=__doc__,rows=rows),indent=2));print(json.dumps(dict(output=str(out),rows=len(rows),target=m.digest)))
