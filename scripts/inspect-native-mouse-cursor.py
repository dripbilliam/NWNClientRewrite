"""Execute unchanged original cursor initializer, software selection and press update.
No process/profile/network/window input is touched. Resource reload, memset,
sprintf and software GUI publication are captured boundaries. SDL hardware
raster scaling and full world-target policy are not established by this oracle.
"""
import importlib.util,itertools,json
from pathlib import Path
spec=importlib.util.spec_from_file_location('image',Path(__file__).with_name('inspect-native-intratile-coordinator.py'))
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle);manager=m.heap+0x1000
ranges=[(0x14083a2c0,0x14083b17b),(0x14083b200,0x14083b250),(0x14083b3e0,0x14083b730)]
publications=[]
def cstring(address):return bytes(u.mem_read(address,128)).split(b'\0')[0].decode('ascii')
def hook(u,address,size,_):
    if address==m.stop:u.emu_stop();return
    x,y,z=[u.reg_read(r) for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8]]
    if address==0x140c42060:u.mem_write(x,bytes([y&255])*z);m.finish(x);return
    if address==0x140047000:
        value=(cstring(y)%z).encode('ascii');u.mem_write(x,value+b'\0');m.finish(len(value));return
    if address==0x14083b250:m.finish();return
    if address==0x14016eb10:m.finish(1);return
    if address==0x1401f67a0:publications.append(dict(name=cstring(y),centered=z!=0));m.finish();return
    if not any(lo<=address<hi for lo,hi in ranges):raise AssertionError(f'Uncaptured original cursor dependency {address:x}')
u.hook_add(UC_HOOK_CODE,hook)
def call(address,*args):
    u.mem_write(m.stack,bytes(0x20000));rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
    for register,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],args):u.reg_write(register,value)
    for index,value in enumerate(args[4:]):m.wq(rsp+0x28+index*8,value)
    u.emu_start(address,m.stop,count=100000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
u.mem_write(m.heap,bytes(0x100000));call(0x14083a2c0,manager)
names=[cstring(manager+0x928+index*17) for index in range(293)]
assert names[0]=='' and names[1]=='gui_mp_defaultu' and names[-1]=='gui_mp_custom99d'
observations=[]
for index,centered,allow,pressed in itertools.product(range(1,293),[False,True],[False,True],[False,True]):
    # Original guard accepts 293, but names only exist through292; pressed292
    # remains292. The initializer's empty0 is recorded separately, not invented.
    m.wi(manager+0x1cb0,-1);publications.clear()
    call(0x14083b3e0,manager,index,int(centered),int(allow),int(pressed),0)
    assert len(publications)==1
    observed=publications[0];observations.append(dict(id=index,centered=centered,allowPressed=allow,pressed=pressed,**{'name':observed['name'],'publishedCentered':observed['centered']}))
cache=[]
for index,centered,allow in itertools.product([1,3,21,59,75,91,93,291],[False,True],[False,True]):
    m.wi(manager+0x1cb0,-1);publications.clear();call(0x14083b3e0,manager,index,int(centered),int(allow),0,0)
    call(0x14083b3e0,manager,index,int(not centered),int(not allow),1,0)
    assert len(publications)==1 # same base ID skips even changed flags
    call(0x14083b200,manager,1);call(0x14083b200,manager,0)
    assert len(publications)==3
    cache.append(dict(id=index,centered=centered,allowPressed=allow,publications=publications.copy()))
output=m.root/'backups/animations/native-mouse-cursor-observations-v1.json';assert not output.exists(),'Preserve original observations'
output.write_text(json.dumps(dict(target=m.digest,scope=__doc__,names=names,selection=observations,press=cache),indent=2)+'\n')
print(json.dumps(dict(output=str(output),names=len(names),selection=len(observations),press=len(cache))))
