"""Original common portrait setters49b930 and4233a0. Allocation, active
portraits table, string concatenation and CResRef construction/copy are
captured boundaries. Verifies ID retention, table selection and setter order;
the lower CResRef normalization has independent observations.
"""
import importlib.util,itertools,json
from pathlib import Path
spec=importlib.util.spec_from_file_location('fixture',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
objectPtr,vtablePtr,appPtr,rulesPtr,tablePtr,refPtr=[m.heap+n*0x1000 for n in range(1,7)]
def ctext(ptr):
 raw=bytearray()
 while ptr and len(raw)<4096:
  b=u.mem_read(ptr+len(raw),1)[0]
  if not b:break
  raw.append(b)
 return raw.decode('cp1252')
def alloc(n):
 global cursor
 ptr=m.heap+cursor;cursor+=(n+31)&~15;return ptr
def owning(ptr,text):
 raw=text.encode('cp1252');target=alloc(len(raw)+1);u.mem_write(target,raw+b'\0');m.wq(ptr,target if raw else 0);m.wi(ptr+8,len(raw));m.wi(ptr+12,len(raw)+1 if raw else 0)
def stored(ptr):return bytes(u.mem_read(m.q(ptr),m.si(ptr+8)&0xffffffff)).decode('cp1252') if m.q(ptr) else ''
def resref(text):return text.split('\0')[0].encode('cp1252')[:16].ljust(17,b'\0')
def hook(u,at,n,_):
 if at==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(r)for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
 if at==0x140c10368:m.finish(alloc(x));return
 if at==0x140c10370:m.finish();return
 if at==0x1401a68f0:assert x==tablePtr;calls.append(['table',y&0xffffffff,stored(z)]);owning(w,c['value']);m.finish(c['status']);return
 if at==0x14016ab00:owning(y,stored(x)+stored(z));m.finish(y);return
 if at==0x14018ded0:u.mem_write(x,resref(ctext(y)));m.finish(x);return
 if at==0x14018de80:
  assert x==objectPtr+0x40;value=bytes(u.mem_read(y,17));calls.append(['ref',value.split(b'\0')[0].decode('cp1252'),int.from_bytes(u.mem_read(objectPtr+0x52,2),'little')]);u.mem_write(x,value);m.finish(x);return
 if not (0x14049b930<=at<0x14049bb40 or 0x1404233a0<=at<0x1404233a9):raise AssertionError(f'Uncaptured portrait dependency {at:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,calls,cursor
 c=case;calls=[];cursor=0x10000;u.mem_write(m.heap,bytes(0x100000));m.wq(objectPtr,vtablePtr);m.wq(vtablePtr+0x1a0,0x1404233a0)
 m.wq(0x1412df8f8,appPtr);m.wq(appPtr+0x130,rulesPtr);m.wq(rulesPtr+0x188,tablePtr);u.mem_write(objectPtr+0x40,resref('old_ref'));u.mem_write(objectPtr+0x52,(7).to_bytes(2,'little'));u.mem_write(refPtr,resref(c['value']))
 rsp=m.stack+0x1fe08;u.mem_write(rsp-0x500,bytes(0x600));m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,objectPtr);u.reg_write(UC_X86_REG_RDX,refPtr if c['direct'] else c['id']&0xffffffffffffffff)
 try:u.emu_start(0x1404233a0 if c['direct'] else 0x14049b930,m.stop,count=100000)
 except Exception:print(json.dumps(dict(case=c,calls=calls,rip=hex(u.reg_read(UC_X86_REG_RIP)))));raise
 assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=c,id=int.from_bytes(u.mem_read(objectPtr+0x52,2),'little'),reference=ctext(objectPtr+0x40),calls=calls)
rows=[]
for direct,id,status,value in itertools.product([False,True],[0,7,65533,65534,65535,65536,-1],[0,1,2],['','Hu_M_01','AbCdEfGhIjKlMnOp','a\0tail']):rows.append(run(dict(direct=direct,id=id,status=status,value=value)))
out=m.root/'backups/animations/native-object-portrait-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2)+'\n');print(json.dumps(dict(rows=len(rows),output=str(out))))
