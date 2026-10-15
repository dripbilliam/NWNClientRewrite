"""Read-only bounded original death flag/scheduling and creature event11.
Possession, bag creation, effects, scheduler, area removal, object lookup,
encounter accounting and destructor are captured owner boundaries. These
comparisons do not establish body-bag population or actual destruction parity.
"""
import importlib.util,itertools,json,struct
from pathlib import Path
spec=importlib.util.spec_from_file_location('coordinator',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle);q,si,wi,wq,finish=[getattr(m,n) for n in ['q','si','wi','wq','finish']]
actor,effect,app,stats,encounter,module,area,ids,allocation,vtable,ai=[m.heap+n*0x1000 for n in range(11)]
candidates={id:m.heap+0x10000+id*0x1000 for id in [7,9,10,6]}
def hook(u,a,n,_):
    if a in [m.stop,end]:u.emu_stop();return
    x,y,z,w=[u.reg_read(reg) for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
    if a==0x1403d54d0:calls.append(['possessed']);finish(c['possessed'])
    elif a==0x14049c170:calls.append(['bag']);finish()
    elif a==0x14055b960:finish(ai)
    elif a==0x1405570b0:
        event=si(rsp+0x30);payload=q(rsp+0x38);calls.append(['event',event,w&0xffffffff,si(rsp+0x28)&0xffffffff,z&0xffffffff,int.from_bytes(u.mem_read(payload,2),'little') if payload else None]);finish()
    elif a==0x14055b440:calls.append(['encounter',y&0xffffffff]);finish(encounter if c['encounter'] else 0)
    elif a==0x14043e480:calls.append(['removeCount',m.xmm(UC_X86_REG_XMM1),z&0xffffffff]);finish()
    elif a==0x140c10324:finish(allocation)
    elif a==0x1404233d0:u.mem_write(x,bytes(0x110));finish(x)
    elif a==0x140425210:wi(x+0x100,z);finish()
    elif a==m.stop+0x108:finish(actor)
    elif a==0x14048e350:calls.append(['effect',int.from_bytes(u.mem_read(y+8,2),'little'),int.from_bytes(u.mem_read(y+10,2),'little')&7,si(y+0x100),z&0xffffffff,w&0xffffffff]);finish()
    elif a==0x14055b6e0:finish(module)
    elif a==0x1404c6490:u.mem_write(x,bytes(0x48));finish(x)
    elif a==0x1404953b0:calls.append(['dead']);finish(c['dead'])
    elif a==0x14039e6b0:calls.append(['removeArea',y&0xffffffff]);finish()
    elif a==0x140494e80:calls.append(['area']);finish(area if c['retainedArea'] else 0)
    elif a==0x14055b4c0:calls.append(['object',y&0xffffffff]);finish(candidates.get(y,0))
    elif a in [m.stop+0x110,m.stop+0x118,m.stop+0x120]:finish(x)
    elif a==0x1400b5450:
        id=next(id for id,ptr in candidates.items() if x in [ptr+0x3c8,ptr+0x458,ptr+0x4e8]);calls.append(['removeObserver',id,y&0xffffffff]);finish()
    elif a==m.stop+0x100:calls.append(['destroy',y&0xffffffff]);finish()
    elif not (start<=a<end):raise RuntimeError(f'Unmapped corpse lifecycle dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
    global c,calls,start,end
    c=case;calls=[];u.mem_write(m.heap,bytes(0x100000));wq(0x1412df970,app);wq(app+8,app);wi(actor+8,77);wi(effect+0x18,888);wq(actor+0xad0,stats);m.wf(stats+0xd0,1.25);wi(module+0x30,444);wq(actor,vtable);wq(vtable,m.stop+0x100);wq(vtable+0x60,m.stop+0x108)
    for field,name in [(0x89c,'pc'),(0xf0,'destroyable'),(0x8bc,'noPermDeath'),(0x4e8,'lootable'),(0x4ec,'decay'),(0x94c,'removed'),(0x948,'encounterId')]:wi(actor+field,c[name])
    u.mem_write(actor+0x771,bytes([c['field771']]));u.mem_write(actor+0x908,struct.pack('<H',c['associate']&65535));wq(area+0x158,ids);wi(area+0x160,5)
    for n,id in enumerate([7,10,9,6,999]):wi(ids+n*4,id)
    for id,ptr in candidates.items():wq(ptr,vtable);u.mem_write(ptr+12,bytes([id]))
    wq(vtable+0x80,m.stop+0x110);wq(vtable+0x30,m.stop+0x118);wq(vtable+0x98,m.stop+0x120)
    frame=m.stack+0x10000;rsp=frame-0x100;u.mem_write(rsp-0x100,bytes(0x400));u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RBP,frame);wi(frame+3,c['flag']);wi(frame+0x7f,17);wi(frame+0x298,11)
    for reg,v in [(UC_X86_REG_RDI,actor),(UC_X86_REG_RSI,actor),(UC_X86_REG_R12,effect),(UC_X86_REG_R13,1),(UC_X86_REG_RBX,0)]:u.reg_write(reg,v)
    if c['mode']=='flag':
        start,end=0x14042acf8,0x14042ad1c;u.reg_write(UC_X86_REG_RAX,actor);u.reg_write(UC_X86_REG_RBX,c['spectacular']&0xffffffff)
    elif c['mode']=='schedule':start,end=0x14042b2dc,0x14042b513
    else:start,end=0x14038f07a,0x14038f220;u.reg_write(UC_X86_REG_RDI,0)
    try:u.emu_start(start,m.stop,count=10000)
    except Exception:print(json.dumps(dict(case=c,rip=hex(u.reg_read(UC_X86_REG_RIP)),calls=calls)));raise
    assert u.reg_read(UC_X86_REG_RIP)==end
    return dict(case=c,calls=calls,flag=si(frame+3),removed=si(actor+0x94c))
default=dict(mode='flag',pc=0,possessed=0,destroyable=1,noPermDeath=0,field771=0,spectacular=0,flag=0,lootable=0,decay=5000,encounter=False,encounterId=999,associate=0,dead=1,retainedArea=False,removed=0)
flags=[run(default|dict(field771=field,spectacular=spectacular,destroyable=destroyable,noPermDeath=noPerm)) for field,spectacular,destroyable,noPerm in itertools.product([0,15,255],[-1,0,1,2],[0,1,2],[0,1,2])]
schedules=[run(default|dict(mode='schedule',pc=pc,possessed=possessed,flag=flag,lootable=lootable,decay=decay,encounter=encounterFlag,encounterId=encounterId)) for pc,possessed,flag,lootable,decay,encounterFlag,encounterId in itertools.product([0,1,2],[0,1],[0,1,2],[0,1,2],[5000,0xffffffff],[False,True],[0x7f000000,999])]
events=[run(default|dict(mode='event',pc=pc,possessed=possessed,destroyable=destroyable,associate=associate,dead=dead,lootable=lootable,removed=removed,retainedArea=retained,encounter=encounterFlag)) for pc,possessed,destroyable,associate,dead,lootable,removed,retained,encounterFlag in itertools.product([0,1],[0,1,2],[0,1,2],[0,7,8,65543],[0,1,2],[0,1],[0,1],[False,True],[False,True])]
out=m.root/'backups/animations/native-corpse-lifecycle-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,flags=flags,schedules=schedules,events=events),indent=2));print(json.dumps(dict(output=str(out),flags=len(flags),schedules=len(schedules),events=len(events))))
