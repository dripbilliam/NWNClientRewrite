"""Original Window::SetTitle6c7310 flags, with an already-owned title string.
The self-assignment path skips the string allocator; original length test and
flag operations execute. Synthetic title lengths/flags only, no game joins.
"""
import importlib.util,json,itertools
from pathlib import Path
spec=importlib.util.spec_from_file_location('fixture',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle);owner=m.heap+0x1000
def hook(u,a,n,_):
 if a==m.stop:u.emu_stop();return
 if not 0x1406c7310<=a<=0x1406c7375:raise RuntimeError(f'Unexpected title dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook);rows=[]
for length,flags in itertools.product([0,1,32],[0,1,16,32,64,112,0xffffffff]):
 u.mem_write(owner,bytes(0x1000));m.wq(owner+0xf0,length);m.wi(owner+0x178,flags);sp=m.stack+0x1fe08;m.wq(sp,m.stop);u.reg_write(UC_X86_REG_RSP,sp);u.reg_write(UC_X86_REG_RCX,owner);u.reg_write(UC_X86_REG_RDX,owner+0xe0)
 u.emu_start(0x1406c7310,m.stop,count=100);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 after=m.si(owner+0x178)&0xffffffff;assert after==((flags|64)if length else(flags&~64));rows.append(dict(titleLength=length,before=flags,after=after))
out=m.root/'backups/animations/native-nui-window-title-v1.json';out.write_text(json.dumps(dict(target=m.digest,limits=__doc__,cases=rows),indent=2)+'\n');print(json.dumps(dict(cases=len(rows),output=str(out))))
