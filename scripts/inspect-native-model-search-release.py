"""Complete original BinarySearchModel and Model::DelRef. ASCII comparison and
the downstream MaxTree delete operation are explicit lower providers. Global
search/refcount routing only; not full parsing, GPU or exact cache eviction.
Read-only hash-pinned original code; no live process or original file changes.
"""
import importlib,itertools,json
from pathlib import Path
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
needle,table,model=m.heap,m.heap+0x1000,m.heap+0x2000
def cstr(p):return bytes(u.mem_read(p,128)).split(b'\0')[0].decode('ascii')
def hook(u,a,n,_):
 if a==m.stop:u.emu_stop();return
 if a==0x140c9a9fc:
  x,y=[u.reg_read(r)for r in [UC_X86_REG_RCX,UC_X86_REG_RDX]];left,right=cstr(x).lower(),cstr(y).lower();calls.append(['compare',cstr(x),cstr(y)]);m.finish((left>right)-(left<right))
 elif a==0x14008a070:calls.append(['delete',u.reg_read(UC_X86_REG_RCX)==model]);m.finish()
 elif not(0x140098ba0<=a<=0x140098c2d or 0x14008dd20<=a<=0x14008dd43):raise AssertionError(hex(a))
u.hook_add(UC_HOOK_CODE,hook)
def begin(entry):
 u.mem_write(m.stack,bytes(0x20000));rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 u.emu_start(entry,m.stop,count=10000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
search=[];release=[]
for count,name in itertools.product([0,1,2,16,17,32],['','absent','a_model000','A_MODEL000','a_model007','a_model031','z_missing']):
 calls=[];u.mem_write(m.heap,bytes(0x100000));names=[f'a_model{i:03}'for i in range(count)];pointers=[]
 for i,text in enumerate(names):
  ptr=model+i*0x100;pointers.append(ptr);m.wq(table+i*8,ptr);u.mem_write(ptr+0x10,text.encode()+b'\0')
 m.wq(0x1413018b8,table);u.mem_write(needle,name.encode()+b'\0');u.reg_write(UC_X86_REG_RCX,needle);u.reg_write(UC_X86_REG_RDX,0);u.reg_write(UC_X86_REG_R8,(count-1)&0xffffffff)
 begin(0x140098ba0);result=u.reg_read(UC_X86_REG_RAX);index=pointers.index(result)if result in pointers else None
 assert index==(names.index(name.lower())if name.lower()in names else None)
 search.append(dict(case=dict(count=count,name=name),index=index,calls=calls))
for count in [-1,0,1,2,3,17,2147483647]:
 calls=[];u.mem_write(m.heap,bytes(0x100000));m.wi(model+0x94,count);u.reg_write(UC_X86_REG_RCX,model);u.reg_write(UC_X86_REG_RDX,0)
 begin(0x14008dd20);after=m.si(model+0x94);result=u.reg_read(UC_X86_REG_RAX)&0xffffffff
 assert after==count-1 and result==((count-1)&0xffffffff);assert calls==([['delete',True]]if count==1 else [])
 release.append(dict(case=dict(count=count),remaining=after,returnWord=result,calls=calls))
out=m.root/'backups/animations/native-model-search-release-v1.json'
if out.exists():raise FileExistsError(out)
out.write_text(json.dumps(dict(binarySha256=m.digest,scope=__doc__,search=search,release=release),indent=2));print(json.dumps(dict(output=str(out),search=len(search),release=len(release))))
