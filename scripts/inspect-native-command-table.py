"""Original InitializeCommands14054de30 and ExecuteCommand14050d770.
Only command-array allocation and final handler delivery are captured. Table
assignments and raw-index forwarding execute original instructions. Metadata
only: no bytecode, binary or game assets are emitted.
"""
import importlib.util,json
from pathlib import Path
spec=importlib.util.spec_from_file_location('coordinator',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle);command,table=m.heap,m.heap+0x1000
def hook(u,a,n,_):
    if a==m.stop:u.emu_stop();return
    if a==0x140c10368:assert u.reg_read(UC_X86_REG_RCX)==0x2518;m.finish(table)
    elif not 0x14054de30<=a<0x1405520ce:raise AssertionError(f'Uncaptured command table dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook);rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,command)
u.emu_start(0x14054de30,m.stop,count=30000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
symbols={m.base+e.address:e.name.decode('ascii') for e in m.pe.DIRECTORY_ENTRY_EXPORT.symbols if e.name};rows=[]
for id in range(0x4a3):
    pointer=m.q(table+id*8);rows.append(dict(id=id,handler=f'{pointer:x}',symbol=symbols.get(pointer)))
out=m.root/'backups/animations/native-command-table-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2)+'\n');print(json.dumps(dict(rows=len(rows),output=str(out))))
