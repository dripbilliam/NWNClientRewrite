"""Execute original spell target type/cursor setup and self/other predicate,
plus server-script mask/cursor setup. Actor/spell lookup, target registration,
preview/publication and reset boundaries are captured; no game/window/network
is opened. This does not establish range, LOS, associates or full target input.
"""
import importlib.util,json,itertools,struct
from pathlib import Path
spec=importlib.util.spec_from_file_location('image',Path(__file__).with_name('inspect-native-intratile-coordinator.py'))
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
target,spell,actor,creature=[m.heap+off for off in [0x1000,0xd000,0xe000,0xf000]]
evidence=json.loads((m.root/'backups/animations/rea-native-cursor-targets-v1.json').read_text())
addresses={'0x140704720','0x140704640','0x14098d5f0'}
ranges=[(int(b['start'],16),int(b['end'],16)+1) for row in evidence['rows'] if row['result']['procedure']['address'] in addresses for b in row['result']['procedure']['body']['ranges']]
entries=[];is_creature=False;current_id=101
def hook(u,address,size,_):
    if address==m.stop:u.emu_stop();return
    x,y,z=[u.reg_read(r) for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8]]
    if address==0x1402af4a0:m.finish(spell);return
    if address==0x1406ac1a0:m.finish(actor);return
    if address==0x1406ac1c0:m.finish(101);return
    if address==0x1406ab9e0:m.wi(creature+8,current_id);m.finish(creature if is_creature else 0);return
    if address in [0x1406abbe0,0x1406abfd0,0x140704a50,0x140704bd0,0x14098cb10,0x14083b9e0]:m.finish();return
    if address==0x14083bac0:entries.append(dict(kind=y,cursor=z));m.finish();return
    if not any(lo<=address<hi for lo,hi in ranges):raise AssertionError(f'Uncaptured original target dependency {address:x}')
u.hook_add(UC_HOOK_CODE,hook)
def call(address,*args):
    u.mem_write(m.stack,bytes(0x20000));rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
    for register,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],args):u.reg_write(register,value)
    u.emu_start(address,m.stop,count=100000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
    return u.reg_read(UC_X86_REG_RAX)
u.mem_write(m.heap,bytes(0x100000));m.wq(0x1412df970,m.heap+0xa000);m.wq(m.heap+0xa000,m.heap+0xb000);m.wq(0x1412df8f8,m.heap+0xc000);m.wi(actor+8,101)
u.mem_write(0x141297120,b'\0')
spells=[]
for mask in range(128):
    entries.clear();u.mem_write(target,bytes(0x500));u.mem_write(spell+0x50,struct.pack('<H',mask));m.wi(target+0x150,123)
    assert call(0x140704720,target,123,1)==1
    predicate=[]
    for is_creature,current_id in itertools.product([False,True],[101,102]):predicate.append(dict(creature=is_creature,id=current_id,rejected=call(0x140704640,target,current_id)!=0))
    spells.append(dict(mask=mask,badCursor=m.si(target+0x118),centered=m.si(target+0x11c)!=0,entries=entries.copy(),predicate=predicate))
scripts=[]
for mask in range(1024):
    entries.clear();u.mem_write(target,bytes(0x500));call(0x14098d5f0,target,mask,95,97)
    scripts.append(dict(mask=mask,badCursor=m.si(target+0x118),centered=m.si(target+0x11c)!=0,entries=entries.copy()))
output=m.root/'backups/animations/native-target-cursor-observations-v1.json';assert not output.exists(),'Preserve original observations'
output.write_text(json.dumps(dict(target=m.digest,scope=__doc__,spells=spells,scripts=scripts),indent=2)+'\n')
print(json.dumps(dict(output=str(output),spells=len(spells),scripts=len(scripts))))
