"""Untouched zero-argument EffectComplex dispatch. VM allocation/base
constructor/creator tagging/push/free are captured boundaries. Native effect
types, masks, INT defaults and subtype writes execute, including control spells.
Application and removal are not covered by constructor evidence.
"""
import importlib.util,json,struct
from pathlib import Path
spec=importlib.util.spec_from_file_location('coordinator',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle);command,effect,ints=m.heap,m.heap+0x1000,m.heap+0x2000
def hook(u,a,n,_):
    global output
    if a==m.stop:u.emu_stop();return
    x,y,z=[u.reg_read(reg) for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8]]
    if a==0x140c10324:m.finish(effect)
    elif a==0x1404233d0:m.wq(effect+0x48,ints);m.finish(effect)
    elif a==0x140425110:m.wi(effect+0x18,y);m.finish()
    elif a==0x140286330:
        output=dict(type=int.from_bytes(u.mem_read(effect+8,2),'little'),subtype=int.from_bytes(u.mem_read(effect+0xa,2),'little'),integers=[m.si(ints+i*4) for i in range(8)],creatorId=m.si(effect+0x18)&0xffffffff);m.finish(1)
    elif a in [0x140423770,0x140c10360]:m.finish()
    elif not any(lo<=a<hi for lo,hi in [(0x1405180b0,0x140518a6e),(0x14051ab90,0x14051ac48),(0x140425210,0x14042521c)]):raise AssertionError(f'Uncaptured control constructor dependency {a:x} ordinal={ordinal}')
u.hook_add(UC_HOOK_CODE,hook);rows=[]
owners=json.loads((m.root/'backups/animations/native-command-table-observations.json').read_text())['rows']
for ordinal in [134,148,154,156,157,158,159,160,161,252,270,271,767,583]:
    owner=0x14051ab90 if ordinal==583 else 0x1405180b0
    assert owners[ordinal]['handler']==f'{owner:x}','Wrong native constructor owner'
    output=None;u.mem_write(m.heap,bytes(0x100000));m.wi(command+0xc,99);rsp=m.stack+0x1fe08;u.mem_write(rsp-0x200,bytes(0x300));m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
    for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8],[command,ordinal,0]):u.reg_write(reg,value)
    u.emu_start(owner,m.stop,count=5000);assert u.reg_read(UC_X86_REG_RIP)==m.stop;rows.append(dict(ordinal=ordinal,output=output))
out=m.root/'backups/animations/native-control-constructor-observations-v4.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2)+'\n');print(json.dumps(dict(rows=len(rows),output=str(out))))
