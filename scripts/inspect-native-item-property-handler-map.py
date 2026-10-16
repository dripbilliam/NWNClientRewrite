"""Unchanged InitializeItemPropertyArray140473330..140473786 with captured
allocation. Record both88-entry materializer/removal tables; no live edits.
"""
import importlib,sys,json
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u;u.hook_del(m.hook_handle)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
handler=m.heap;cursor=0x1000
def hook(u,a,n,_):
 global cursor
 if a==m.stop:u.emu_stop();return
 if a==0x140c10368:
  length=u.reg_read(UC_X86_REG_RCX);ptr=m.heap+cursor;cursor+=(length+15)&~15;m.finish(ptr)
 elif not 0x140473330<=a<0x140473786:raise RuntimeError(f'Unmapped item-property handler initialization {a:x}')
u.hook_add(UC_HOOK_CODE,hook);rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,handler);u.emu_start(0x140473330,m.stop,count=10000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
rows=[dict(type=i,apply=f'{m.q(m.q(handler+8)+i*8):x}',remove=f'{m.q(m.q(handler+16)+i*8):x}') for i in range(88)]
out=m.root/'backups/animations/native-item-property-handler-map.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2));print(json.dumps(dict(output=str(out),rows=rows)))
