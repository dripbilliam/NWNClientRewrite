"""Untouched script save/time wrappers. VM pop/push and SavingThrowRoll
are captured boundaries. Types/defaults, narrowing and float arithmetic execute.
Two-argument saves seed their otherwise indeterminate category scratch only
as evidence; the live adapter must not invent that scratch value.
"""
import importlib.util,itertools,json,struct
from pathlib import Path
spec=importlib.util.spec_from_file_location('coordinator',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle);si,wi,wq=[getattr(m,n) for n in ['si','wi','wq']]
command,vm,app,actor,vtable,clock=[m.heap+n*0x1000 for n in range(1,7)]
def hook(u,a,n,_):
    global output
    if a==m.stop:u.emu_stop();return
    x,y,z=[u.reg_read(reg) for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8]];rsp=u.reg_read(UC_X86_REG_RSP)
    if a in [0x140286110,0x140286160]:wi(y,arguments.pop(0));m.finish(1)
    elif a==0x14055b850:m.finish(app)
    elif a==0x140296470:
        if c.get('exists',True):wq(z,actor)
        m.finish(0 if c.get('exists',True) else 1)
    elif a==m.stop+0x10:m.finish(actor)
    elif a==0x1403ec600:
        calls.append([y&255,z&65535,u.reg_read(UC_X86_REG_R9)&255,si(rsp+0x28)&0xffffffff,si(rsp+0x30),si(rsp+0x38)&65535,si(rsp+0x40)])
        m.finish(c.get('result',1))
    elif a==0x140286410:output=y&0xffffffff;m.finish(1)
    elif a==0x1402863b0:output=m.xmm(UC_X86_REG_XMM1);m.finish(1)
    elif a==0x14055ba10:m.finish(clock)
    elif not (0x14053d2b0<=a<0x14053d414 or 0x14054a260<=a<0x14054a322):raise AssertionError(f'Uncaptured spell script dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
    global c,calls,arguments,output
    c=case;calls=[];output=None;u.mem_write(m.heap,bytes(0x100000));wq(0x1412df910,vm);wq(0x1412df970,app);wq(app+8,app)
    wi(command+0xc,99);wq(actor,vtable);wq(vtable+0x60,m.stop+0x10);u.mem_write(actor+0xc,bytes([c.get('objectType',5)]));u.mem_write(clock+0x2c,bytes([c.get('minutes',5)&255]))
    arguments=[c.get('count',1)] if c['mode']=='time' else [100,c.get('dc',10)]+([c.get('category',0),c.get('versus',101)] if c.get('argc',4)>2 else [])
    rsp=m.stack+0x1fe08;u.mem_write(rsp-0x200,bytes(0x300));wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
    # Save wrapper's optional-category storage is rsp(entry)-0x28.
    wi(rsp-0x28,c.get('categoryScratch',0))
    u.reg_write(UC_X86_REG_RCX,command);u.reg_write(UC_X86_REG_RDX,c['ordinal']);u.reg_write(UC_X86_REG_R8,c.get('argc',4))
    u.emu_start(0x14054a260 if c['mode']=='time' else 0x14053d2b0,m.stop,count=3000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
    return dict(case=c,output=output,calls=calls)
rows=[]
for ordinal,count,minutes in itertools.product([121,122,123,124],[-2147483648,-16777217,-1,0,1,16777217,2147483647],[0,1,5,255]):rows.append(run(dict(mode='time',ordinal=ordinal,count=count,minutes=minutes)))
for ordinal,dc,category,result in itertools.product([108,109,110],[-1,0,65535,65536,2147483647],[-1,0,15,255,256],[0,1,2,255,256]):rows.append(run(dict(mode='save',ordinal=ordinal,dc=dc,category=category,result=result)))
for exists,type,argc,scratch in itertools.product([False,True],[4,5,6],[2,4],[0,15,256]):rows.append(run(dict(mode='save',ordinal=108,exists=exists,objectType=type,argc=argc,categoryScratch=scratch)))
out=m.root/'backups/animations/native-spell-script-support-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2)+'\n');print(json.dumps(dict(rows=len(rows),output=str(out))))
