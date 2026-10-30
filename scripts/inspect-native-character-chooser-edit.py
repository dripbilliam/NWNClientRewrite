"""Read-only original hidden chooser edit construction and key handling.
Unchanged CGuiEdit constructor, chooser key override, base key handler and
uninitialized callback execute. String allocation/virtual operations, base
object construction, Shift query, cursor callback and focus service are captured
boundaries. No original process, server or physical input is accessed.
"""
import importlib.util,itertools,json
from pathlib import Path
spec=importlib.util.spec_from_file_location('image',Path(__file__).with_name('inspect-native-intratile-coordinator.py'))
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
control=m.heap+0x1000;string=m.heap+0x3000;vtable=m.heap+0x4000;line=m.heap+0x5000;target=m.heap+0x6000
methods={offset:m.stop+0x100+index*0x10 for index,offset in enumerate([0xb8,0x48,0x50,0x78,0x140,0x148,0x150,0x160,0x168,0x158,0xe8,0xe0])}
services={address:offset for offset,address in methods.items()}
cursor=m.stop+0x300
ranges=[(0x1401e7dc0,0x1401e7ee5),(0x140710a90,0x140710ae3),(0x1401e99b0,0x1401e9c97),(0x1401e58c0,0x1401e58c2)]
def hook(u,a,n,_):
 if a==m.stop:u.emu_stop();return
 x=u.reg_read(UC_X86_REG_RCX);y=u.reg_read(UC_X86_REG_RDX)
 if a==0x1401fac90:m.finish(x)
 elif a==0x1400492f0:m.finish(string)
 elif a==0x1406daac0:m.finish(case['shift'])
 elif a==0x1401eb870:calls.append(['focus',x==target]);m.finish()
 elif a==cursor:calls.append(['cursor',y-0x100000000 if y&0x80000000 else y]);m.finish()
 elif a in services:
  offset=services[a]
  if offset==0x140:calls.append(['insert',u.mem_read(y,1)[0]])
  elif offset==0x148:calls.append(['delete',y])
  elif offset==0x168:calls.append(['column',y&0xffffffff])
  elif offset==0x158:calls.append(['line',y&0xffffffff])
  m.finish({0xb8:0,0x150:0,0x160:2,0xe8:1,0xe0:line}.get(offset,1))
 elif not any(lo<=a<=hi for lo,hi in ranges):raise AssertionError(f'Uncaptured edit dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def call(address,key):
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop)
 for reg,value in [(UC_X86_REG_RSP,rsp),(UC_X86_REG_RCX,control),(UC_X86_REG_RDX,key)]:u.reg_write(reg,value)
 u.emu_start(address,m.stop,count=20000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return u.reg_read(UC_X86_REG_RAX)
def run(key,shift,links):
 global case,calls
 case=dict(key=key,shift=shift,links=links);calls=[]
 u.mem_write(m.heap,bytes(0x10000));u.mem_write(m.stack,bytes(0x20000));m.wq(string,vtable)
 u.mem_write(line,b'ABC\n\0')
 for offset,address in methods.items():m.wq(vtable+offset,address)
 call(0x1401e7dc0,0xffffffff)
 defaults=dict(submitCallback=hex(m.q(control+0xb0)),cancelCallback=hex(m.q(control+0xc0)),next=m.q(control+0xf0),previous=m.q(control+0xf8))
 assert defaults==dict(submitCallback='0x1401e58c0',cancelCallback='0x1401e58c0',next=0,previous=0)
 calls=[];m.wq(control+0x100,target);m.wq(control+0x108,cursor)
 if links:m.wq(control+0xf0,target);m.wq(control+0xf8,target)
 result=call(0x140710a90,key)
 return dict(case=case,constructor=defaults,handled=result,calls=calls)
if __name__=='__main__':
 rows=[run(*case) for case in itertools.product([9,13,27,8,0x123,0x124,0x125,0x126,0x127,0x128,0x12e,65,10,0,0x129,32], [0,1],[False,True])]
 out=m.root/'backups/animations/native-character-chooser-edit-observations-v2.json';assert not out.exists(),'Preserve prior evidence'
 out.write_text(json.dumps(dict(target=m.digest,scope=__doc__,rows=rows),indent=2));print(json.dumps(dict(output=str(out),cases=len(rows))))
