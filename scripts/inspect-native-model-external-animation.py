"""Original AnimateExternal14008c080, header counter bracketing and virtual
call. The animation body is captured, optionally replacing the header pointer.
Does not prove the full Gob::Animate or renderer header/cache implementation.
"""
import importlib.util,itertools,json,struct
from pathlib import Path
spec=importlib.util.spec_from_file_location('fixture',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle);obj,vt,head,other=[m.heap+n*0x1000 for n in range(1,5)];animate=m.stop+0x10
def hook(u,a,n,_):
 if a==m.stop:u.emu_stop();return
 if a==animate:
  delta=u.reg_read(UC_X86_REG_XMM1)&0xffffffff;calls.append(dict(delta=delta,head=m.si(head+0x1b8),other=m.si(other+0x1b8)))
  if c['replace']:m.wq(obj+0x88,other)
  m.finish()
 elif not 0x14008c080<=a<0x14008c0c0:raise AssertionError(f'Unexpected external-animation dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,calls
 c=case;calls=[];u.mem_write(m.heap,bytes(0x10000));m.wq(obj,vt);m.wq(vt+0x28,animate);m.wq(obj+0x88,head if c['header'] else 0);m.wi(head+0x1b8,c['counter']);m.wi(other+0x1b8,50)
 rsp=m.stack+0x1fe08;u.mem_write(rsp-0x100,bytes(0x200));m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,obj);u.reg_write(UC_X86_REG_XMM1,int.from_bytes(struct.pack('<f',c['delta']),'little'));u.emu_start(0x14008c080,m.stop,count=100);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=c,calls=calls,head=m.si(head+0x1b8),other=m.si(other+0x1b8))
rows=[run(dict(header=header,replace=replace,counter=count,delta=delta))for header,replace,count,delta in itertools.product([0,1],[0,1],[0,-1,0x7fffffff],[0,1,.25,-1])]
out=m.root/'backups/animations/native-model-external-animation-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows))+'\n');print(json.dumps(dict(rows=len(rows),output=str(out))))
