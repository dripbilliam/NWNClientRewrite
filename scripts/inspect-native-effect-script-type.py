"""Original GetScriptEffectType140423fe0, invoked at its verified direct-call
start. Guarded region ends at the proven common return140424632. No lower
owner is intercepted: enum guards/results execute native. This is enum mapping
evidence, not effect application or a claim of complete decompilation.
"""
import importlib.util,json,struct
from pathlib import Path
spec=importlib.util.spec_from_file_location('coordinator',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle);effect=m.heap+0x1000;visited=set()
def hook(u,a,n,_):
    if a==m.stop:u.emu_stop();return
    if not 0x140423fe0<=a<0x140424633:raise AssertionError(f'Effect script-type path escaped audited region at {a:x}')
    visited.add(a)
u.hook_add(UC_HOOK_CODE,hook)
rows=[]
for effectType in [*range(100),255,256,65535]:
    for allTypes in [0,1,2,-1]:
        u.mem_write(effect,bytes(0x200));m.wq(effect+0x48,effect+0x110);m.wi(effect+0x40,8);u.mem_write(effect+8,struct.pack('<H',effectType));rsp=m.stack+0x1fe08;m.wq(rsp,m.stop)
        u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,effect);u.reg_write(UC_X86_REG_RDX,allTypes&0xffffffff)
        try:u.emu_start(0x140423fe0,m.stop,count=3000)
        except Exception:print(json.dumps(dict(type=effectType,all=allTypes,rip=hex(u.reg_read(UC_X86_REG_RIP)))));raise
        assert u.reg_read(UC_X86_REG_RIP)==m.stop
        rows.append(dict(type=effectType,all=allTypes,value=u.reg_read(UC_X86_REG_RAX)&0xffffffff))
for kind in [-1,0,1,2]:
    for allTypes in [0,1]:
        u.mem_write(effect,bytes(0x200));m.wq(effect+0x48,effect+0x110);m.wi(effect+0x40,8);m.wi(effect+0x11c,kind);u.mem_write(effect+8,struct.pack('<H',65));rsp=m.stack+0x1fe08;m.wq(rsp,m.stop)
        u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,effect);u.reg_write(UC_X86_REG_RDX,allTypes)
        u.emu_start(0x140423fe0,m.stop,count=3000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
        rows.append(dict(type=65,all=allTypes,integer3=kind,value=u.reg_read(UC_X86_REG_RAX)&0xffffffff))
for kind,allTypes in [(k,a) for k in range(-1,24) for a in [0,1]]:
    u.mem_write(effect,bytes(0x200));m.wq(effect+0x48,effect+0x110);m.wi(effect+0x40,8);m.wi(effect+0x110,kind);u.mem_write(effect+8,struct.pack('<H',8));rsp=m.stack+0x1fe08;m.wq(rsp,m.stop)
    u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,effect);u.reg_write(UC_X86_REG_RDX,allTypes)
    u.emu_start(0x140423fe0,m.stop,count=3000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
    rows.append(dict(type=8,all=allTypes,integer0=kind,value=u.reg_read(UC_X86_REG_RAX)&0xffffffff))
out=m.root/'backups/animations/native-effect-script-type-observations-v3.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows,executedAddresses=[hex(n) for n in sorted(visited)]),indent=2)+'\n');print(json.dumps(dict(rows=len(rows),output=str(out))))
