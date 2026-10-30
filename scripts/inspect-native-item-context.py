"""Execute unchanged item context root59d0, repository7ee0 and equipment6af0.
Item/actor/base lookup, GUI entry publication and interaction permission are
captured boundaries. Power population is a separate original instruction oracle.
No process/profile/network/window is opened. These cases exclude alternate
inventory, associates and pending destruction; full UI parity remains unproven.
"""
import importlib.util,json,itertools
from pathlib import Path
spec=importlib.util.spec_from_file_location('image',Path(__file__).with_name('inspect-native-intratile-coordinator.py'))
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
menu,item,actor,base,inventory,app,rules=[m.heap+n*0x1000 for n in range(1,8)]
proof=json.loads((m.root/'backups/animations/rea-native-item-context-v1.json').read_text())
allowed={'0x1409a59d0','0x1409a7ee0','0x1409a6af0'}
ranges=[(int(b['start'],16),int(b['end'],16)+1) for row in proof['rows'] if row['result']['procedure']['address'] in allowed for b in row['result']['procedure']['body']['ranges']]
actions={0x1409a8430:'examine',0x1409a82f0:'drop',0x1409a8240:'buy',0x1409a84a0:'sell',0x1409a84d0:'unequip',0x1409a8330:'equip',0x1409a8660:'split',0x1409a8460:'pickup',0x1409a8700:'open',0x1409a5f10:'spells'}
entries={};case={}
def string(ptr):return bytes(u.mem_read(ptr,64)).split(b'\0')[0].decode('ascii')
def hook(u,address,size,_):
    if address==m.stop:u.emu_stop();return
    x,y,z,w=[u.reg_read(r) for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
    if address==0x1406abc80:m.finish(item);return
    if address==0x14029ca00:m.finish(base);return
    if address==0x1406ac1a0:m.finish(actor);return
    if address==0x1406ac1c0:m.finish(101);return
    if address in [0x1406ac320,0x1406abbe0,0x1406abfd0,0x1406abbc0]:m.finish(inventory);return
    if address==0x1406f7870:m.finish(0);return
    if address in [0x1406f9bd0,0x1401f9fd0,0x1401f7e80,0x1409a71a0]:m.finish();return
    if address==0x1408564e0:m.finish(1);return
    if address==0x140800dd0:m.finish(102 if case['ring_filled'] else 0x7f000000);return
    if address in [0x1401fa3a0,0x1401faa40]:
        callback=m.q(rsp+0x30);entries[y]=dict(slot=y,icon=string(z).lower(),ref=w,action=actions[callback],payload=m.q(rsp+0x38),disabled=False);m.finish();return
    if address==0x1401f8b30:
        if y in entries:entries[y]['disabled']=True
        m.finish();return
    if not any(lo<=address<hi for lo,hi in ranges):raise AssertionError(f'Uncaptured item-context dependency {address:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(c):
    global entries,case
    case=c;entries={};u.mem_write(m.heap,bytes(0x100000));m.wq(0x1412df970,app);m.wq(app,app);m.wq(0x1412df8f8,rules);m.wq(0x141428db0,0)
    m.wi(actor+8,101);m.wi(actor+0x270,0x7f000000);m.wi(item+0x264,101 if c['owned'] else 0x7f000000);m.wi(item+0x268,int(c['channel']=='C'));m.wi(item+0x284,c['stack']);m.wi(item+0x1c0,int(c['canUse']));m.wi(item+0x50,103);m.wi(base+4,c['slots']);m.wi(base+0x80,int(c['container']));m.wi(inventory+0x178,int(c['store']));m.wi(inventory+0x268c,103 if c['container_open'] else 0x7f000000);m.wi(inventory+0x2690,int(c['container_owned']))
    flags=3 if c['channel']=='I' else 9 if c['channel']=='M' else 1 if c['channel']=='R' or c['container_owned'] else 0
    u.mem_write(m.stack,bytes(0x20000));rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
    for register,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],[menu,flags,103,0]):u.reg_write(register,value)
    u.emu_start(0x1409a59d0,m.stop,count=100000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
    return dict(context=c,entries=sorted(entries.values(),key=lambda r:r['slot']))
cases=[]
for channel,slots,canUse,store,stack,container,opened,ring in itertools.product(['R','I','M','C','ground'],[0,16,32,48,128,256,3],[False,True],[False,True],[1,3],[False,True],[False,True],[False,True]):
    for owned_container in ([False,True] if channel=='C' else [False]):
        cases.append(dict(channel=channel,slots=slots,canUse=canUse,store=store,stack=stack,container=container,container_open=opened,ring_filled=ring,container_owned=owned_container,owned=channel in ['R','I']))
output=m.root/'backups/animations/native-item-context-observations-v1.json';assert not output.exists(),'Preserve original observations'
output.write_text(json.dumps(dict(target=m.digest,scope=__doc__,cases=[run(c) for c in cases]),indent=2)+'\n')
print(json.dumps(dict(output=str(output),cases=len(cases))))
