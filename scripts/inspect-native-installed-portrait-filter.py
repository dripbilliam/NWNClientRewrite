"""Original1972f0 installed portrait callback, every ushort resource type.
No directory contents, resource payloads or game processes are touched.
"""
from pathlib import Path
import importlib.util,json
root=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('mapped',root/'scripts/inspect-native-intratile-coordinator.py')
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
def hook(u,a,n,_):
 if a==m.stop:u.emu_stop();return
 if not 0x1401972f0<=a<=0x140197307:raise RuntimeError(hex(a))
u.hook_add(UC_HOOK_CODE,hook);accepted=[]
for resource_type in range(65536):
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RAX,0);u.reg_write(UC_X86_REG_R8,resource_type)
 u.emu_start(0x1401972f0,m.stop,count=32);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 if u.reg_read(UC_X86_REG_RAX)&255:accepted.append(resource_type)
assert accepted==[3,2033]
out=dict(target=m.digest,address='0x1401972f0',scope=__doc__,typesTested=65536,accepted=accepted)
(root/'backups/animations/native-installed-portrait-filter-v1.json').write_text(json.dumps(out,indent=2)+'\n');print(json.dumps(out))
