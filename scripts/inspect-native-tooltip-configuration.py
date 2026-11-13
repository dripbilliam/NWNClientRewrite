"""Execute original tooltip default/range, callback and GUI clock units.

Bounded configuration-registration slices and complete callback/clock/getter
instructions are unchanged. Platform timer return values are explicit providers.
No original process, game login, file mutation or GPU. Mouse/ownership policy
is not implemented or accepted by these observations.
"""
import importlib.util,json
from pathlib import Path
spec=importlib.util.spec_from_file_location('image',Path(__file__).with_name('inspect-native-intratile-coordinator.py'))
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
gui,exo,clock,value,option=[m.heap+n*0x1000 for n in range(5)]
gui_global=0x1406bdb77+m.si(0x1406bdb73)
exo_global=0x14059789d+m.si(0x140597899)
allowed=[(0x1406b755a,0x1406b7564),(0x1406b7596,0x1406b75ff),(0x140134200,0x140134218),(0x1406bdb70,0x1406bdb85),(0x140597880,0x1405978ca),(0x140597050,0x140597058)]
def hook(u,address,size,data):
    if address in [m.stop,0x1406b7565,0x1406b7600]:u.emu_stop();return
    if address==0x14016dd30:m.finish(timer_now);return
    if not any(start<=address<=end for start,end in allowed):raise AssertionError(f'Unexpected original dependency {address:x}')
u.hook_add(UC_HOOK_CODE,hook)
def reset():
    u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000))
    m.wq(gui_global,gui);m.wq(exo_global,exo);m.wq(exo+0x10,m.heap+0x6000)
    u.reg_write(UC_X86_REG_RBP,m.heap+0x10000)
def call(entry,args):
    sp=m.stack+0x1fe08;m.wq(sp,m.stop);u.reg_write(UC_X86_REG_RSP,sp)
    for register,v in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],args):u.reg_write(register,v)
    u.emu_start(entry,m.stop,count=1000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
    return u.reg_read(UC_X86_REG_RAX)
reset();u.emu_start(0x1406b755a,m.stop,count=100);assert u.reg_read(UC_X86_REG_RIP)==0x1406b7565
default=m.q(m.heap+0x10000+0x2b8);assert default==100000
reset();u.reg_write(UC_X86_REG_RSP,m.stack+0x1fdc0);u.reg_write(UC_X86_REG_RAX,option)
u.emu_start(0x1406b7596,m.stop,count=1000);assert u.reg_read(UC_X86_REG_RIP)==0x1406b7600
minimum,maximum=m.q(option+0x168),m.q(option+0x178);assert (minimum,maximum)==(1000,5000000)
callbacks=[]
for delay in [1000,100000,275000,5000000]:
    reset();m.wi(gui+0x98,12345);m.wq(value,delay);call(0x1406bdb70,[0,value])
    row=dict(input=delay,delay=m.si(gui+0x9c),saved=m.si(gui+0xa0),counter=m.si(gui+0x98));assert row==dict(input=delay,delay=delay,saved=delay,counter=12345);callbacks.append(row)
clocks=[]
for rate,delta in [(0,1),(0,16667),(0,100000),(60,0),(240,0)]:
    reset();m.wi(clock,1 if rate else 0);m.wi(clock+4,rate);m.wq(clock+8,1000000);timer_now=1000000+delta
    call(0x140597880,[clock]);difference=call(0x140597050,[clock]);expected=1000000//rate if rate else delta
    assert difference==expected and m.q(clock+0x10)==1000000
    clocks.append(dict(fixedRate=rate,providedMicrosecondDelta=delta,observedMicrosecondDelta=difference))
out=m.root/'backups/animations/native-tooltip-configuration-v1.json';assert not out.exists(),'Immutable evidence already exists'
out.write_text(json.dumps(dict(binarySha256=m.digest,scope=__doc__,defaultUsec=default,minimumUsec=minimum,maximumUsec=maximum,callbacks=callbacks,clocks=clocks),indent=2)+'\n')
print(json.dumps(dict(defaultUsec=default,minimumUsec=minimum,maximumUsec=maximum,callbacks=len(callbacks),clocks=len(clocks),file=str(out))))
