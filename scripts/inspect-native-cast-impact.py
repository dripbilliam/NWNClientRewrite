"""Untouched SpellCastAndImpact ordinary event ownership. Lower presentation,
spell lookup/allocation and scheduler are captured boundaries, not full casting.
"""
import importlib.util,itertools,json,struct
from pathlib import Path
spec=importlib.util.spec_from_file_location('fixture',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
q,si,wi,wq,finish=[getattr(m,n) for n in ['q','si','wi','wq','finish']]
actor,spell,area,rules,app,vtable,point,allocated,script=[m.heap+n*0x1000 for n in range(1,10)]
def hook(u,a,n,_):
    if a==m.stop:u.emu_stop();return
    x,y,z,w=[u.reg_read(reg) for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
    if a==0x140c10370:finish()
    elif a==0x1402af4a0:finish(0 if c.get('missing') else spell)
    elif a==m.stop+0x10:finish(actor)
    elif a==0x140c10324:
        addr=allocated+len(allocations)*0x100;allocations.append(addr);u.mem_write(addr,bytes(0x100));finish(addr)
    elif a in [0x1402da730,0x1402da770]:finish()
    elif a in [0x14055b3d0,0x14055b6c0]:finish(0)
    elif a==0x14048f550:calls.append(['broadcast']);finish()
    elif a==0x14037bd50:finish()
    elif a==0x14003d8c0:finish()
    elif a==0x140494e80:finish(area if c.get('area',True) else 0)
    elif a==0x14055b960:finish(app)
    elif a==0x1405570b0:
        data=q(rsp+0x30)
        calls.append(['event',si(rsp+0x28)&0xffffffff,z&0xffffffff,w&0xffffffff,si(rsp+0x20)&0xffffffff,
         {'spellId':si(data),'featId':int.from_bytes(u.mem_read(data+4,2),'little'),'casterId':si(data+8)&0xffffffff,'targetId':si(data+12)&0xffffffff,'itemId':si(data+16)&0xffffffff,'position':list(struct.unpack('<3f',u.mem_read(data+20,12))),'areaId':si(data+48)&0xffffffff}]);finish()
    elif not 0x14049c4b0<=a<0x14049ca5c:raise AssertionError(f'Uncaptured dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
    global c,calls,allocations
    c=case;calls=[];allocations=[];u.mem_write(m.heap,bytes(0x100000));wq(0x1412df8f8,rules);wq(rules+0xd0,spell);wq(0x1412df970,app);wq(app+8,app)
    wq(actor,vtable);wq(vtable+0x60,m.stop+0x10);wi(actor+8,99);wi(actor+0x224,c.get('done',0));wi(actor+0x220,c.get('delay',150));wi(area+0x140,88);u.mem_write(actor+0x23c,struct.pack('<H',c.get('feat',65535)));wq(spell+0x58,script);wi(spell+0x60,6);u.mem_write(script,b'impact\0');u.mem_write(point,struct.pack('<3f',1.25,-2,3));
    rsp=m.stack+0x1fe08;u.mem_write(rsp-0x500,bytes(0x600));wq(rsp,m.stop)
    # index,item,flags,unused,path,instant at native stack arguments5..10.
    for off,value in [(0x28,0),(0x30,0x7f000000),(0x38,0),(0x40,0),(0x48,0),(0x50,c.get('instant',0))]:wi(rsp+off,value)
    for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],[actor,1,point,c.get('target',100)]):u.reg_write(reg,value)
    u.reg_write(UC_X86_REG_RSP,rsp);u.emu_start(0x14049c4b0,m.stop,count=30000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
    return {'case':c,'calls':calls,'impact':si(actor+0x224)}
rows=[run(dict(instant=instant,done=done,delay=delay,target=target)) for instant,done,delay,target in itertools.product([0,1],[0,1],[0,150,0xffffffff],[100,0x7f000000])]
rows.append(run({'missing':True}))
print(json.dumps({'owner':'SpellCastAndImpact14049c4b0','limits':'Ordinary non-projectile, creature caster, present area, captured lower presentation/scheduler boundaries.','rows':rows}))
