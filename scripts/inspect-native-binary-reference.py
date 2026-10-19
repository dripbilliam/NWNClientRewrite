"""Complete original binary node dispatcher07abe0/base reader07b6c0 with
reference flags11. Heap, memcpy and node-kind queries are captured lower
boundaries. Synthetic payloads only; no proprietary assets copied. Confirms
the raw64-byte model field, signed/raw DWORD reattachable and controller remap,
not reference instance creation, child model loading or runtime reattachment.
"""
import importlib,itertools,json
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
disk,model=m.heap,m.heap+0x4000
def hook(u,a,n,_):
 global allocation
 if a==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(r)for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
 if a in [0x140c10368,0x140c10324]:p=m.heap+0x10000+allocation*0x1000;allocation+=1;m.finish(p)
 elif a==0x140c4f038:
  p=m.heap+0x10000+allocation*0x1000;allocation+=1
  if x:u.mem_write(p,bytes(u.mem_read(x,min(y,0x1000))))
  m.finish(p)
 elif a in [0x140c10370,0x140c4f024]:m.finish()
 elif a==0x140c417f0:u.mem_write(x,bytes(u.mem_read(y,z)));m.finish(x)
 elif a in [0x14008c360,0x14008c300,0x14008c2e0]:m.finish(0)
 elif not(0x14007abe0<=a<0x14007b6bc or 0x14007b6c0<=a<0x14007b9e1):raise AssertionError(f'Unexpected reference reader dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global allocation
 allocation=0;u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));m.wi(disk+0x6c,0x11)
 payload=case['name'].encode('ascii');u.mem_write(disk+0x70,payload+bytes(64-len(payload)));m.wi(disk+0xb0,case['reattachable'])
 controls=[8,20,36,68,72,76,128,160,176];m.wi(disk+0x54,0x100);m.wi(disk+0x58,len(controls))
 for i,v in enumerate(controls):m.wi(model+0x100+i*12,v)
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);m.wq(rsp+0x28,0)
 for reg,v in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],[m.heap+0x9000,disk,m.heap+0x8000,model]):u.reg_write(reg,v)
 u.reg_write(UC_X86_REG_RSP,rsp);u.emu_start(0x14007abe0,m.stop,count=100000);assert u.reg_read(UC_X86_REG_RIP)==m.stop;node=u.reg_read(UC_X86_REG_RAX)
 return dict(case=case,rawModel=list(u.mem_read(node+0xa0,64)),reattachable=m.si(node+0xe0),flags=m.si(node+0x98),controls=controls,controllers=[m.si(m.q(node+0x78)+i*12)for i in range(len(controls))])
rows=[run(dict(name=name,reattachable=flag))for name,flag in itertools.product(['','vfx_model','MixedCase_Reference','x'*63,'Y'*64,'first\0tail'],[0,1,2,-1,-2147483648,2147483647])]
out=m.root/'backups/animations/native-binary-reference-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows))+'\n');print(json.dumps(dict(output=str(out),rows=len(rows))))
