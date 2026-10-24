"""Original89.8193.37-17 portrait size/Exists selection, unchanged instructions.
String allocation/copies, resource Exists and cookie check are captured boundaries.
No decoding, GUI draw or original game process is executed.
"""
from pathlib import Path
import importlib.util,json
root=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('mapped',root/'scripts/inspect-native-intratile-coordinator.py')
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
base,out=m.heap+0x8000,m.heap+0x8100
def string(p):return bytes(u.mem_read(p,128)).split(b'\0',1)[0]
def write(p,s):u.mem_write(p,s[:16].ljust(17,b'\0'))
def hook(u,a,n,_):
 global allocated
 if a==m.stop:u.emu_stop();return
 x,y,z=[u.reg_read(r) for r in[UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8]]
 if a in[0x14018de80,0x14018ded0]:write(x,string(y));m.finish(x);return
 if a==0x14018e060:write(x,string(x)+string(m.q(y)));m.finish(x);return
 if a in[0x140c10370,0x140c10410]:m.finish();return
 if a==0x140c10368:allocated+=256;m.finish(m.heap+allocated);return
 if a==0x140c417f0:u.mem_write(x,bytes(u.mem_read(y,z)));m.finish(x);return
 if a==0x14018f590:
  ref=string(y).decode('ascii');calls.append([ref,z]);mask=tga if z==3 else dds
  suffix='tsmlh'.find(ref[-1:].lower());m.finish(int(suffix>=0 and bool(mask&(1<<suffix))));return
 if not(0x14084c1b0<=a<=0x14084c2e7 or 0x14084c2f0<=a<=0x14084c54a):raise RuntimeError(hex(a))
u.hook_add(UC_HOOK_CODE,hook)
cases=[]
for size in range(6):
 for tga in range(32):
  for dds in range(32):
   allocated=0x10000;calls=[];write(base,b'portrait_');write(out,b'')
   rsp=m.stack+0x1fe08;u.mem_write(rsp-0x200,bytes(0x300));m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
   for reg,v in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8],[base,out,size]):u.reg_write(reg,v)
   u.emu_start(0x14084c2f0,m.stop,count=20000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
   cases.append(dict(size=size,tgaMask=tga,ddsMask=dds,calls=calls,result=string(out).decode('ascii')))
output=root/'backups/animations/native-portrait-candidates-v1.json'
output.write_text(json.dumps(dict(target=m.digest,scope=__doc__,cases=cases),indent=2)+'\n')
print(json.dumps(dict(cases=len(cases),target=m.digest)))
