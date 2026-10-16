"""Unchanged owned-associate submenu14098f8e0; lower GUI allocation,
constructor and SetEntryx capture. Proves slots/icons/tooltips/callback words,
not replication, full role selection, possession, henchman removal or transport.
"""
import importlib.util,json
from pathlib import Path
spec=importlib.util.spec_from_file_location('fixture',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle);parent,child=m.heap+0x1000,m.heap+0x2000
def text(ptr):
 out=b''
 while True:
  value=bytes(u.mem_read(ptr,1));ptr+=1
  if value==b'\0':return out.decode('ascii')
  out+=value
def signed(v):return v-(1<<64) if v>>63 else v
def hook(u,a,n,_):
 if a==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(reg) for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
 if a==0x140c10324:m.finish(child)
 elif a==0x1401f7950:m.finish(x)
 elif a==0x1401fa3a0:
  entries.append(dict(slot=y,icon=text(z),tooltip=w,callback=f'{m.q(rsp+0x30):x}',argument=signed(m.q(rsp+0x38))));m.finish()
 elif not 0x14098f8e0<=a<0x14098fbee:raise AssertionError(f'Uncaptured associate radial boundary {a:x}')
u.hook_add(UC_HOOK_CODE,hook);rows=[]
for kind in [-1,0,1,2,3,4,5,6,7,8,65535]:
 entries=[];u.mem_write(m.heap,bytes(0x100000));rsp=m.stack+0x1fe08;u.mem_write(rsp-0x200,bytes(0x300));m.wq(rsp,m.stop)
 for reg,value in [(UC_X86_REG_RSP,rsp),(UC_X86_REG_RCX,parent),(UC_X86_REG_RDX,kind&0xffffffffffffffff)]:u.reg_write(reg,value)
 u.emu_start(0x14098f8e0,m.stop,count=3000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 rows.append(dict(type=kind,entries=entries,flag=u.mem_read(child+0x7f1,1)[0]))
out=m.root/'backups/animations/native-owned-associate-radial-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows))+'\n');print(json.dumps(dict(rows=len(rows),output=str(out))))
