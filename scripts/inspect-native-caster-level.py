"""Original caster level, class slot/level and feat-source owners.
Class-level/index/feat-source instructions execute inside GetCasterLevel.
Captured boundaries: spell lookup, virtual casts, effect integer, spell-like
level and feat-array membership. Rules/history fixtures are synthetic. Script
wrapper pops/pushes and AoE lifecycle are separate; no full-cast claim.
"""
import importlib.util,json,struct,itertools
from pathlib import Path
spec=importlib.util.spec_from_file_location('coordinator',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle);q,si,wi,wq,wf,finish=[getattr(m,n) for n in ['q','si','wi','wq','wf','finish']]
actor,stats,spell,rules,vtable,effectPtrs,historyPtrs=[m.heap+n*0x1000 for n in range(1,8)]
classRules=m.heap+0x10000
ranges=[(0x140494ee0,0x140495129),(0x1403fa4f0,0x1403fa5a4),(0x140402dc0,0x140402e01),(0x140401b30,0x140401c61)]
def hook(u,a,n,_):
    if a==m.stop:u.emu_stop();return
    x,y,z,w=[u.reg_read(reg) for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
    if a==m.stop+0x10:finish(actor if c.get('type',5)==11 else 0)
    elif a==m.stop+0x20:finish(actor if c.get('type',5)==5 else 0)
    elif a==m.stop+0x30:finish(actor if c.get('type',5)==9 else 0)
    elif a==0x1402af4a0:finish(spell if c.get('spellExists',True) else 0)
    elif a==0x140408aa0:finish(c.get('abilityLevel',255))
    elif a==0x140423fc0:finish(si(x+0x30))
    elif a==0x140296910:
        index=(x-(m.heap+0x40000)-0x140)//0x1000;entry=c.get('history',[])[index];finish(int((y&65535) in [feat&65535 for feat in entry.get('feats',[])]))
    elif a==0x140115890:finish()
    elif not any(lo<=a<hi for lo,hi in ranges):raise AssertionError(f'Uncaptured caster level dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
    global c
    c=case;u.mem_write(m.heap,bytes(0x100000));wq(0x1412df8f8,rules);wq(rules+0x110,classRules);wq(rules+0xd0,rules)
    wq(actor,vtable);wq(vtable+0xa8,m.stop+0x10);wq(vtable+0x60,m.stop+0x20);wq(vtable+0x98,m.stop+0x30);wq(actor+0xad0,stats);wq(stats+0x30,actor)
    wi(actor+0x344,c.get('aoeLevel',17));wi(actor+0x820,c.get('overrideFlag',0));wi(actor+0x824,c.get('overrideLevel',-20));wi(actor+0x97c,c.get('equipmentOverride',0));wi(actor+0x218,1)
    for i,value in enumerate(c.get('overrideIds',[1,2,3])):wi(actor+0x9e8+i*4,value)
    u.mem_write(actor+0x22c,bytes([c.get('index',0)&255]));u.mem_write(actor+0x23c,struct.pack('<H',c.get('feat',65535)&65535));u.mem_write(spell+0x6f,bytes([c.get('innate',1)&255]))
    classes=c.get('classes',[dict(type=0,level=7,penalty=0),dict(type=1,level=3,penalty=1)]);u.mem_write(stats+0xd8,bytes([len(classes)&255]))
    for i,entry in enumerate(classes):u.mem_write(stats+0x25c+i*0x188,bytes([entry['type']&255,entry['level']&255,entry.get('penalty',0)&255]))
    for i in range(20):
        ptr=classRules+i*0x530;wi(ptr+0x4d8,c.get('spellCaster',1));wi(ptr+0x51c,c.get('minimum',1));wf(ptr+0x518,c.get('factor',1))
    effects=c.get('effects',[]);wi(actor+0x158,len(effects));wq(actor+0x150,effectPtrs)
    for i,entry in enumerate(effects):
        ptr=m.heap+0x30000+i*0x1000;wq(effectPtrs+i*8,ptr);u.mem_write(ptr+8,struct.pack('<H',entry['type']&65535));wi(ptr+0x30,entry['level'])
    history=c.get('history',[]);wi(stats+0x40,len(history));wq(stats+0x38,historyPtrs)
    for i,entry in enumerate(history):
        ptr=m.heap+0x40000+i*0x1000;wq(historyPtrs+i*8,ptr);u.mem_write(ptr+0x15c,bytes([entry['class']&255]))
    rsp=m.stack+0x1fe08;u.mem_write(rsp-0x300,bytes(0x400));wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
    mode=c.get('mode','caster');args=[actor,0,0,0];start=0x140494ee0
    if mode=='class':args=[stats,c.get('index',0)&255,c.get('negative',1),c.get('multiply',1)];start=0x1403fa4f0
    elif mode=='source':args=[stats,c.get('feat',0)&65535,0,0];start=0x140401b30
    elif mode=='index':args=[stats,c.get('classType',0)&255,0,0];start=0x140402dc0
    for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],args):u.reg_write(reg,value)
    u.emu_start(start,m.stop,count=20000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
    value=u.reg_read(UC_X86_REG_RAX)&(0xffffffff if mode=='caster' else 255)
    if mode=='caster' and value>=0x80000000:value-=0x100000000
    return dict(case=c,value=value)
rows=[]
for level,penalty,negative,multiply,factor in itertools.product([0,1,3,9,255],[0,2,15,255],[0,1,2],[0,1,2],[0,.5,1,1.3]):
    rows.append(run(dict(mode='class',classes=[dict(type=0,level=level,penalty=penalty)],negative=negative,multiply=multiply,factor=factor,minimum=3)))
for index,spellCaster,minimum in itertools.product([0,1,2,255,256],[0,1,2],[-1,0,3,1000]):rows.append(run(dict(mode='class',index=index,spellCaster=spellCaster,minimum=minimum,factor=.5)))
for typeId in [0,1,2,255,256,257]:rows.append(run(dict(mode='index',classType=typeId)))
history=[dict(**{'class':1},feats=[10]),dict(**{'class':0},feats=[20,65000]),dict(**{'class':1},feats=[10,30])]
for feat,classes in itertools.product([10,20,30,65000,65536,65535],[[],[dict(type=0,level=1)],[dict(type=0,level=3)],[dict(type=0,level=255),dict(type=1,level=1)]]):rows.append(run(dict(mode='source',feat=feat,classes=classes,history=history)))
for index,exists,innate,overrideFlag in itertools.product([0,1,2,254,255,256],[False,True],[0,1,10,255],[0,1,2]):rows.append(run(dict(index=index,spellExists=exists,innate=innate,overrideFlag=overrideFlag)))
for effectList in [[],[dict(type=1,level=15)],[dict(type=62,level=15)],[dict(type=62,level=0),dict(type=62,level=20)],[dict(type=62,level=-5)],[dict(type=65598,level=5)]]:rows.append(run(dict(equipmentOverride=1,effects=effectList)))
for typeId in [3,4,5,9,10,11,12,13,14]:rows.append(run(dict(type=typeId,index=255)))
for feat in [10,20,30,50,65000]:rows.append(run(dict(index=255,feat=feat,history=history)))
for level in [0,1,255,256,257]:rows.append(run(dict(index=254,abilityLevel=level,spellExists=False)))
for factor in [-1,1000,1e10]:rows.append(run(dict(mode='class',factor=factor)))
out=m.root/'backups/animations/native-caster-level-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2)+'\n');print(json.dumps(dict(rows=len(rows),output=str(out))))
