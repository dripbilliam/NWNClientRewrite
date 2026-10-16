"""Read-only original item LoadFromGff execution. Typed GFF, resrefs,
LoadFromTemplate, lower data/saved state, tag insertion and visual selection
are captured boundaries. Checks wrapper branches, status/return handling,
field widths and ordering; does not execute those lower owners here.
"""
import importlib.util,itertools,json
from pathlib import Path
spec=importlib.util.spec_from_file_location('fixture',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
objectPtr,resourcePtr,rootPtr,appPtr,serverPtr,modulePtr=[m.heap+n*0x1000 for n in range(1,7)]
def ctext(ptr):
 raw=bytearray()
 while ptr and len(raw)<4096:
  b=u.mem_read(ptr+len(raw),1)[0]
  if not b:break
  raw.append(b)
 return raw.decode('cp1252')
def stored(ptr):return bytes(u.mem_read(m.q(ptr),m.si(ptr+8)&0xffffffff)).decode('cp1252') if m.q(ptr) else ''
def owning(ptr,text):
 global cursor
 raw=text.encode('cp1252');data=m.heap+cursor;cursor+=(len(raw)+32)&~15;u.mem_write(data,raw+b'\0');m.wq(ptr,data if raw else 0);m.wi(ptr+8,len(raw));m.wi(ptr+12,len(raw)+1 if raw else 0)
def hook(u,at,n,_):
 if at==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(r)for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
 if at==0x14018ded0:u.mem_write(x,ctext(y).encode('cp1252')[:16].ljust(17,b'\0'));m.finish(x);return
 if at==0x1401a12d0:
  assert x==resourcePtr and z==rootPtr
  name=ctext(w);status=c['equipped'] if name=='EquippedRes' else c['inventory'];value=c['reference'] if status else ''
  calls.append(['read','resref',name,'',status,value]);m.wi(m.q(rsp+0x28),status);u.mem_write(y,value.encode('cp1252')[:16].ljust(17,b'\0'));m.finish(y);return
 if at in [0x1401a0ee0,0x1401a0f60]:
  assert x==resourcePtr and y==rootPtr
  name=ctext(z);status=c['dropStatus'] if name=='Dropable' else c['pickStatus'];kind='byte' if at==0x1401a0ee0 else 'bool';raw=c['value']&255 if status else 0;value=raw if kind=='byte' else int(raw!=0)
  calls.append(['read',kind,name,0,status,value]);m.wi(w,status);m.finish(value);return
 if at==0x14046a7c0:assert x==objectPtr and z==0;calls.append(['template',ctext(y)]);m.finish(c['result']);return
 if at==0x140469440:assert x==objectPtr and y==resourcePtr and z==rootPtr;calls.append(['data',w&0xffffffff,m.si(rsp+0x28)]);m.finish(c['result']);return
 if at==0x1404974b0:assert x==objectPtr+0x48 and y==resourcePtr and z==rootPtr;calls.append(['saved']);m.finish();return
 if at==0x14055b6e0:assert x==serverPtr;m.finish(modulePtr);return
 if at==0x14003d8c0:owning(x,bytes(u.mem_read(y,z&0xffffffff)).decode('cp1252'));m.finish(x);return
 if at==0x14047a930:assert x==modulePtr;calls.append(['tag',stored(y),z&0xffffffff]);m.finish();return
 if at==0x14046d140:assert x==objectPtr;calls.append(['visual']);m.finish();return
 if at==0x140c10410:m.finish(u.reg_read(UC_X86_REG_RAX));return
 if not 0x14046a9d0<=at<0x14046ac03:raise AssertionError(f'Uncaptured item wrapper dependency {at:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,calls,cursor
 c=case;calls=[];cursor=0x10000;u.mem_write(m.heap,bytes(0x100000));m.wq(0x1412df970,appPtr);m.wq(appPtr+8,serverPtr)
 m.wi(objectPtr+0x50,42);owning(objectPtr+0x68,'ItemTag');m.wi(objectPtr+0x448,7);m.wi(objectPtr+0x44c,9)
 rsp=m.stack+0x1fe08;u.mem_write(rsp-0x500,bytes(0x600));m.wq(rsp,m.stop);m.wi(rsp+0x28,c['inside']);u.reg_write(UC_X86_REG_RSP,rsp)
 for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],[objectPtr,resourcePtr,rootPtr,c['loading']]):u.reg_write(reg,value)
 try:u.emu_start(0x14046a9d0,m.stop,count=100000)
 except Exception:print(json.dumps(dict(case=c,calls=calls,rip=hex(u.reg_read(UC_X86_REG_RIP)))));raise
 assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=c,result=u.reg_read(UC_X86_REG_RAX)&0xffffffff,drop=m.si(objectPtr+0x448),pick=m.si(objectPtr+0x44c),calls=calls)
rows=[]
for equipped,inventory,result,value,status in itertools.product([0,1,2,-1],[0,1],[0,1,2,-7],[0,2,255],[(0,0),(1,0),(0,-1),(2,1)]):
 rows.append(run(dict(equipped=equipped,inventory=inventory,result=result,value=value,dropStatus=status[0],pickStatus=status[1],reference='Equipped' if equipped else 'Inventory',loading=2,inside=-3)))
for equipped,inventory in [(1,1),(0,1),(0,0)]:rows.append(run(dict(equipped=equipped,inventory=inventory,result=1,value=2,dropStatus=1,pickStatus=1,reference='',loading=0,inside=0)))
out=m.root/'backups/animations/native-item-gff-wrapper-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2)+'\n');print(json.dumps(dict(rows=len(rows),output=str(out))))
