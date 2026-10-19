"""Original door constructor lock stores, two LoadDoor field read/store
segments and complete ReadFieldBYTEasBOOL. Typed ReadFieldBYTE admission is
captured (already parsed GFF); full constructor/door/resource loader not claimed.
"""
import importlib,itertools,json
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle);door,gff,root=[m.heap+i*0x1000 for i in range(3)]
def hook(u,a,n,_):
 if a in [0x140420c3a,0x1404220e9,0x14041d8f3,0x140420bbf,0x14041d8cc]:u.emu_stop();return
 if a==0x1401a0ee0:
  x,y,z,w=[u.reg_read(r)for r in[UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP);label=bytes(u.mem_read(z,16)).split(b'\0')[0].decode();fallback=u.mem_read(rsp+0x28,1)[0];entry=c.get(label);found=entry is not None and entry['type']==0;value=entry['value']&255 if found else fallback;trace.append(['read',label,fallback,int(found),value]);m.wi(w,int(found));m.finish(value)
 elif not(0x140420c11<=a<0x140420c3a or 0x1404220c1<=a<0x1404220e9 or 0x1401a0f60<=a<0x1401a0f80 or 0x14041d8e6<=a<0x14041d8f3 or 0x140420b97<=a<0x140420bbf or 0x14041d8c6<=a<0x14041d8cc):raise AssertionError(f'Unexpected door lock dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,trace
 c=case;trace=[];u.mem_write(m.heap,bytes(0x10000));u.mem_write(m.stack,bytes(0x20000));u.mem_write(door+0x41f,bytes([c.get('oldDC',0)&255]));m.wi(door+0x424,c.get('oldLocked',0));m.wi(door+0x450,c.get('oldLocked',0));rsp=m.stack+0x1fe00;u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RBP,rsp+0x100)
 for reg,v in[(UC_X86_REG_R14,door),(UC_X86_REG_R15,gff),(UC_X86_REG_R12,root)]:u.reg_write(reg,v)
 if c.get('constructor'):
  u.mem_write(door+0x41f,bytes([0xcd])*64);u.reg_write(UC_X86_REG_RBX,door);u.reg_write(UC_X86_REG_RDI,0);u.emu_start(0x14041d8e6,0x14041d8f3,count=10);u.emu_start(0x14041d8c6,0x14041d8cc,count=10)
 else:
  u.emu_start(0x140420b97,0x140420bbf,count=1000);u.emu_start(0x140420c11,0x140420c3a,count=1000);u.emu_start(0x1404220c1,0x1404220e9,count=1000)
 return dict(case=c,trace=trace,openLockDC=u.mem_read(door+0x41f,1)[0],locked=m.si(door+0x424),keyRequired=m.si(door+0x450))
entries=[None,dict(type=0,value=0),dict(type=0,value=1),dict(type=0,value=255),dict(type=5,value=71)]
cases=[dict(oldDC=dc,oldLocked=locked,OpenLockDC=a,Locked=b,KeyRequired=k)for dc,locked,a,b,k in itertools.product([0,17,255],[0,1,256,-1],entries,entries,entries)]+[dict(constructor=True)]
rows=[run(c)for c in cases];out=m.root/'backups/animations/native-door-lock-fields-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2)+'\n');print(json.dumps(dict(rows=len(rows))))
