"""Execute complete original GUI tooltip timing/motion/instant/removal routines.

GUI hit, modal ancestry, cursor 3D transforms and virtual show/finish callbacks
are explicit lower providers. No original process or GPU. These observations
prove policy state transitions, not hit geometry, control flags or final pixels.
"""
import importlib.util,itertools,json
from pathlib import Path
spec=importlib.util.spec_from_file_location('image',Path(__file__).with_name('inspect-native-intratile-coordinator.py'))
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle);gui=m.heap;objects=[0,m.heap+0x1000,m.heap+0x2000];vtable=m.heap+0x3000
allowed_ranges=[(0x1401f55d0,0x1401f5730),(0x1401f5190,0x1401f5265),(0x1401f6b80,0x1401f6c5c),(0x1401f6fc0,0x1401f707f),(0x1401f6590,0x1401f65c4)]
def hook(u,address,size,data):
    x=u.reg_read(UC_X86_REG_RCX)
    if address==m.stop:u.emu_stop();return
    if address==0x1401f4e30:m.finish(objects[case['hit']]);return
    if address==0x1401fb330:m.finish(int(case['allowed']));return
    if address==m.stop+0x100:events.append(['trigger',objects.index(x)]);m.finish();return
    if address==m.stop+0x200:events.append(['finish',objects.index(x)]);m.finish();return
    if address==m.stop+0x300:m.finish(m.heap+0x9000);return
    if address==m.stop+0x400:m.finish();return
    if not any(start<=address<=end for start,end in allowed_ranges):raise AssertionError(f'Unexpected tooltip dependency {address:x}')
u.hook_add(UC_HOOK_CODE,hook)
def reset(value):
    global case,events
    case=value;events=[];u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000))
    for pointer in objects[1:]:m.wq(pointer,vtable);m.wi(pointer+8,value.get('flags',0))
    m.wq(vtable+0xd0,m.stop+0x100);m.wq(vtable+0xd8,m.stop+0x200)
    for offset,number in [(0x98,value['remaining']),(0x9c,value['delay']),(0xa0,value['saved']),(0xd4,100),(0xd8,200),(0xa4,value.get('origin',[10,20])[0]),(0xa8,value.get('origin',[10,20])[1])]:m.wi(gui+offset,number)
    m.wq(gui+0x68,objects[value['active']]);m.wi(gui+0x90,1);m.wq(gui+0x88,m.heap+0x4000);m.wq(m.heap+0x4000,m.heap+0x4100)
    m.wq(gui+0x40,m.heap+0x5000);m.wq(m.heap+0x5008,m.heap+0x5100);m.wq(m.heap+0x5100,m.heap+0x5200);m.wq(m.heap+0x5240,m.stop+0x300)
    m.wq(gui+0xc0,m.heap+0x6000);m.wq(m.heap+0x6000,m.heap+0x6100);m.wq(m.heap+0x61b0,m.stop+0x400)
    if value.get('visible'):m.wq(gui+0x170,m.heap+0x7000);m.wq(m.heap+0x70a0,1)
def call(entry,args):
    sp=m.stack+0x1fe08;m.wq(sp,m.stop);u.reg_write(UC_X86_REG_RSP,sp)
    for register,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],args):u.reg_write(register,value)
    u.emu_start(entry,m.stop,count=5000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
    active=m.q(gui+0x68);assert active in objects
    return dict(remaining=m.si(gui+0x98),delay=m.si(gui+0x9c),saved=m.si(gui+0xa0),active=objects.index(active),point=[m.si(gui+0xd4),m.si(gui+0xd8)],origin=[m.si(gui+0xa4),m.si(gui+0xa8)],events=events)
def baseline(**values):return dict(remaining=11111,delay=100000,saved=200000,active=2,hit=1,allowed=True,flags=0,**values)
rows=[]
for remaining,delta,hit,allowed,flags in itertools.product([-1,0,1,100000],[0,1,100000,100001],[0,1],[False,True],[0,1024]):
    case=baseline();case.update(remaining=remaining,delta=delta,hit=hit,allowed=allowed,flags=flags);reset(case)
    rows.append(dict(kind='advance',input=case,output=call(0x1401f5190,[gui,delta])))
for active,hit,delta in itertools.product([0,1],[0,1,2],[(0,0),(32,0),(33,0),(0,32),(0,33),(20,25),(-33,0)]):
    case=baseline(origin=[100,200]);case.update(active=active,hit=hit,point=[100+delta[0],200+delta[1]]);reset(case)
    rows.append(dict(kind='motion',input=case,output=call(0x1401f55d0,[gui,*case['point']])))
for kind,visible,hit,allowed,flags in itertools.product(['instant','trigger'],[False,True],[0,1],[False,True],[0,1024]):
    for enabled in ([False,True]if kind=='instant'else[False]):
        case=baseline(visible=visible,enabled=enabled);case.update(hit=hit,allowed=allowed,flags=flags);reset(case)
        rows.append(dict(kind=kind,input=case,output=call(0x1401f6b80 if kind=='instant'else 0x1401f6fc0,[gui,int(enabled)])))
for active,owner in itertools.product([0,1,2],[1,2]):
    case=baseline(owner=owner);case.update(active=active);reset(case)
    rows.append(dict(kind='remove',input=case,output=call(0x1401f6590,[gui,objects[owner]])))
out=m.root/'backups/animations/native-tooltip-policy-v1.json';assert not out.exists(),'Immutable original observations already exist'
out.write_text(json.dumps(dict(binarySha256=m.digest,scope=__doc__,observations=rows),indent=2)+'\n')
print(json.dumps(dict(observations=len(rows),file=str(out))))
