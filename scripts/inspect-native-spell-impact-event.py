"""Bounded untouched creature EventHandler spell-impact8/item-on-hit19 branch.
VM execution, object lookup/area, projectile calculation and disposal are
captured lower owners. Context writes/restoration and native guards execute.
"""
import importlib.util,itertools,json,struct
from pathlib import Path
spec=importlib.util.spec_from_file_location('coordinator',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle);q,si,wi,wq=[getattr(m,n) for n in ['q','si','wi','wq']]
actor,target,payload,app,vtable,area,otherArea=[m.heap+n*0x1000 for n in range(1,8)]
fields={'spellId':0x218,'targetId':0x214,'itemId':0x818,'savingSpell':0x184,'override':0x820,'casterLevel':0x824,'effectSpell':0x774}
def snapshot():
    return dict(**{key:si(actor+off) for key,off in fields.items()},feat=int.from_bytes(u.mem_read(actor+0x23c,2),'little'),position=list(struct.unpack('<3f',u.mem_read(actor+0x208,12))))
def hook(u,a,n,_):
    if a==0x14038f06d:u.emu_stop();return
    x,y,z,w=[u.reg_read(reg) for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
    if a==0x14055b850:m.finish(app)
    elif a==0x140296470:
        if c.get('targetExists',True):wq(z,target)
        m.finish(0 if c.get('targetExists',True) else 1)
    elif a==0x140494e80:
        if c.get('nullArea'):m.finish(0)
        else:m.finish(area if x==actor or c.get('sameArea',True) else otherArea)
    elif a==0x14048fe20:calls.append(['projectileTime',y&255]);m.finish()
    elif a==0x140283990:calls.append(['runScript',z&0xffffffff,w&0xffffffff,si(u.reg_read(UC_X86_REG_RSP)+0x28),snapshot()]);m.finish(c.get('scriptResult',1))
    elif a==0x140c10370 or a==0x140c10360:m.finish()
    elif not (0x14038edb0<=a<0x14038f06d or 0x1403a2ff0<=a<0x1403a2ff7):raise AssertionError(f'Uncaptured spell event dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
    global c,calls
    c=case;calls=[];u.mem_write(m.heap,bytes(0x100000));wq(0x1412df970,app);wq(app+8,app);wq(actor,vtable);wq(vtable+0x180,0x1403a2ff0);wi(actor+8,99)
    initial={'spellId':44,'targetId':77,'itemId':88,'savingSpell':-1,'override':c.get('oldOverride',0),'casterLevel':12,'effectSpell':-1}
    for key,value in initial.items():wi(actor+fields[key],value)
    u.mem_write(actor+0x23c,struct.pack('<H',55));u.mem_write(actor+0x208,struct.pack('<3f',1,2,3));u.mem_write(target+0xa4,struct.pack('<3f',4,5,6));u.mem_write(target+0xc,bytes([c.get('targetType',5)&255]))
    wi(payload,1);u.mem_write(payload+4,struct.pack('<H',c.get('feat',65535)&65535));wi(payload+8,c.get('caster',99));wi(payload+0xc,c.get('target',100));wi(payload+0x10,c.get('item',0x7f000000));u.mem_write(payload+0x14,struct.pack('<3f',7,8,9));wi(payload+0x34,c.get('casterLevel',3))
    rsp=m.stack+0x1f008;rbp=rsp+0x300;u.mem_write(rsp-0x200,bytes(0xc00));u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RBP,rbp)
    wi(rbp+0x298,c.get('event',8));wi(rbp+0x2a0,c.get('caller',99));u.reg_write(UC_X86_REG_RSI,actor);u.reg_write(UC_X86_REG_R14,payload if c.get('payload',True) else 0);u.reg_write(UC_X86_REG_R13,c.get('event',8));u.reg_write(UC_X86_REG_RDI,0)
    u.emu_start(0x14038edb0,m.stop,count=10000);assert u.reg_read(UC_X86_REG_RIP)==0x14038f06d
    return dict(case=c,calls=calls,fields=snapshot())
rows=[]
for event,targetType,exists,same,null,scriptResult in itertools.product([8,19],range(3,15),[False,True],[False,True],[False,True],[0,1]):rows.append(run(dict(event=event,targetType=targetType,targetExists=exists,sameArea=same,nullArea=null,scriptResult=scriptResult)))
for event,key,value in itertools.product([8,19],['caster','caller','target','payload'],[0,0x7f000000]):rows.append(run(dict(event=event,**{key:value})))
for event,level,old in itertools.product([8,19],[-1,0,255],[0,1,2]):rows.append(run(dict(event=event,casterLevel=level,oldOverride=old)))
out=m.root/'backups/animations/native-spell-impact-event-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2)+'\n');print(json.dumps(dict(rows=len(rows),output=str(out))))
