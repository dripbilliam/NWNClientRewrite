"""Untouched CGameEffect::SetCreator140425110, with captured object casts,
context getter and caster-level owner. IDs, sentinel checks and store ordering
execute unchanged; the already-verified caster-level calculation is separate.
"""
import importlib.util,itertools,json
from pathlib import Path
spec=importlib.util.spec_from_file_location('coordinator',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle);wi,wq,si=[getattr(m,n) for n in ['wi','wq','si']]
effect,actor,app,vtable=[m.heap+n*0x1000 for n in range(1,5)]
def hook(u,a,n,_):
    if a==m.stop:u.emu_stop();return
    x,y=[u.reg_read(reg) for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX]]
    if a==0x14055b4c0:m.finish(actor if c.get('exists',True) else 0)
    elif a==m.stop+0x10:m.finish(actor if c.get('world',True) else 0)
    elif a==m.stop+0x20:m.finish(actor if c.get('aoe',False) else 0)
    elif a==m.stop+0x30:calls.append(['spell']);m.finish(c.get('contextSpell',1))
    elif a==0x140494ee0:calls.append(['casterLevel']);m.finish(c.get('contextLevel',3))
    elif not 0x140425110<=a<0x1404251bb:raise AssertionError(f'Uncaptured effect creator dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
    global c,calls
    c=case;calls=[];u.mem_write(m.heap,bytes(0x100000));wq(0x1412df970,app);wq(app+8,app);wq(actor,vtable)
    for off,address in [(0x20,m.stop+0x10),(0xa8,m.stop+0x20),(0x178,m.stop+0x30)]:wq(vtable+off,address)
    wi(actor+0x330,c.get('aoeCreator',123));wi(effect+0x18,88);wi(effect+0x1c,c.get('spell',-1));wi(effect+0x28,c.get('level',-1))
    rsp=m.stack+0x1fe08;u.mem_write(rsp-0x100,bytes(0x200));wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,effect);u.reg_write(UC_X86_REG_RDX,c.get('id',99))
    u.emu_start(0x140425110,m.stop,count=2000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
    return dict(case=c,calls=calls,creatorId=si(effect+0x18)&0xffffffff,spellId=si(effect+0x1c),casterLevel=si(effect+0x28))
rows=[]
for exists,world,aoe,spell,level in itertools.product([False,True],[False,True],[False,True],[-1,0,1,255],[-1,0,10,255]):rows.append(run(dict(exists=exists,world=world,aoe=aoe,spell=spell,level=level)))
for id,creator,spell,level in itertools.product([0,0x7f000000,0xffffffff],[0,0x7f000000,0xffffffff],[-1,0,0x7fffffff],[-1,0,0x7fffffff]):rows.append(run(dict(id=id,aoe=True,aoeCreator=creator,contextSpell=spell,contextLevel=level)))
out=m.root/'backups/animations/native-effect-creator-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2)+'\n');print(json.dumps(dict(rows=len(rows),output=str(out))))
