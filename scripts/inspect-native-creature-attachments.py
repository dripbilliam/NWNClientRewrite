"""Original tail/wing admission and model selection through the model-load call.
Captures table/string/allocation services, stops before rendering/resource load.
The native branch decisions, table IDs, scope and colour preparation execute.
"""
import sys,importlib,json,struct,itertools,re
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
actor,appearance,rules,tables,tail,wing,cloak,parts,vtable=[m.heap+n*0x1000 for n in range(1,10)]
def string(p):return bytes(u.mem_read(p,128)).split(b'\0')[0].decode('ascii') if p else ''
def putstr(p,s):
 global allocation
 address=m.heap+0x20000+allocation*0x100;allocation+=1;data=s.encode()+b'\0';u.mem_write(address,data);m.wq(p,address);m.wi(p+8,len(data)-1);m.wi(p+12,len(data))
def hook(u,a,n,data):
 global allocation
 x,y,z,w=[u.reg_read(r) for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
 if a==m.stop+0x10:
  result.update(absent=True,scope=y&255);m.finish();return
 if a==m.stop+0x20:
  result.update(absent=False,scope=z&255,model=string(y));u.emu_stop();return
 if a==0x140c10370:m.finish();return
 if a==0x140c10368:
  address=m.heap+0x20000+allocation*0x100;allocation+=1;assert x<256;m.finish(address);return
 if a==0x14076b6e0:m.finish(cloak);return
 if a==0x1401a68f0:
  column=string(m.q(z));reads.append(dict(table={tail:'tailmodel',wing:'wingmodel',cloak:'cloakmodel'}[x],row=y,column=column));value=str(hide) if x==cloak else ('custom_mount' if column=='MODEL' else 'default');putstr(w,value);m.finish(1);return
 if a==0x140c81d54:m.finish(int(re.match(r'[+-]?\d+',string(x)).group()));return
 if a==0x14018dea0:
  value=string(m.q(y)).encode()[:16];u.mem_write(x,value+bytes(17-len(value)));m.finish(x);return
 if a==0x140c10410:m.finish();return
 if not(0x140979d10<=a<0x14097a430 or 0x14097a5f0<=a<0x14097ad10):raise RuntimeError(hex(a))
u.hook_add(UC_HOOK_CODE,hook)
cases=[]
for kind,id,cloakId,hide in itertools.product(['tail','wings'],[0,34,347],[0,14],[0,1,2,-1]):
 u.mem_write(m.heap,bytes(0x100000));allocation=0;reads=[];result={};offset=0xd8 if kind=='tail' else 0xdc
 m.wq(0x1412df8f8,rules);m.wq(rules+0x130,tables);m.wq(tables+0x1c8,tail);m.wq(tables+0x1d0,wing);m.wq(tables+0x1d8,cloak)
 m.wq(actor+0x100,parts);m.wq(parts,vtable);m.wq(vtable+0xf8,m.stop+0x10);m.wq(vtable+0xf0,m.stop+0x20);m.wi(actor+0x10c,1);m.wi(appearance+offset,id);u.mem_write(appearance+0xf8,struct.pack('<H',cloakId))
 sp=m.stack+0x1fe08;m.wq(sp,m.stop);u.reg_write(UC_X86_REG_RSP,sp);u.reg_write(UC_X86_REG_RCX,actor);u.reg_write(UC_X86_REG_RDX,0);u.reg_write(UC_X86_REG_R8,appearance)
 u.emu_start(0x140979d10 if kind=='tail' else 0x14097a5f0,m.stop,count=20000)
 cases.append(dict(kind=kind,id=id,cloak=cloakId,hide=hide,reads=reads,**result))
out=m.root/'backups/animations/native-creature-attachments-v1.json';out.write_text(json.dumps(dict(target=m.digest,limits=__doc__,cases=cases),indent=2)+'\n');print(json.dumps(dict(cases=len(cases))))
