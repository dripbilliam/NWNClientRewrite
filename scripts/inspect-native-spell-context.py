"""Original scalar spell-context commands and bounded constructor stores.
Captured boundaries: VM push, canonical object lookup and virtual object casts.
Original command type gates and integer/WORD conversion execute. These
queries do not prove impact history writes, caster level, save DC or effects.
"""
import importlib.util,itertools,json,struct
from pathlib import Path
spec=importlib.util.spec_from_file_location('coordinator',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle);q,si,wi,wq,wf,rf,finish=[getattr(m,n) for n in ['q','si','wi','wq','wf','rf','finish']]
command,vm,actor,app,objects,vtable,target,actorArea,targetArea=[m.heap+n*0x1000 for n in range(1,10)]
addresses={'GetSpellId':0x140530610,'GetSpellFeatId':0x140530580,'GetSpellCastSpontaneously':0x140530480,
    'GetMetaMagicFeat':0x14052b9b0,'GetSpellCasterItem':0x140530510,'GetSpellTargetObject':0x140530a70,
    'GetSpellTargetLocation':0x140530920,
    'GetLastSpellCaster':0x140530310,'GetLastSpell':0x140530310,'GetLastSpellHarmful':0x140530310}
ranges=[(0x140530310,0x14053047e),(0x140530480,0x140530509),(0x140530580,0x140530604),(0x140530610,0x140530692),(0x14048bab9,0x14048bb2b),
    (0x14052b9b0,0x14052ba24),(0x140530510,0x14053057e),(0x140530a70,0x140530b10),(0x140530920,0x140530a68)]
fields={'nativeSpellPoint208':[0x208,0x20c,0x210],'nativeSpellTarget214':0x214,'nativeSpellId218':0x218,'nativeSpellDomain21c':0x21c,
    'nativeSpellImpact224':0x224,'nativeSpellSpontaneous228':0x228,'nativeSpellClass22c':0x22c,'nativeSpellMetamagic22d':0x22d,
    'nativeLastSpellCaster230':0x230,'nativeLastSpell234':0x234,'nativeLastSpellHarmful238':0x238,'nativeSpellFeat23c':0x23c}
def hook(u,a,n,_):
    global output
    if a==m.stop or (c['command']=='initialize' and a==0x14048bb2b):u.emu_stop();return
    x,y,z=[u.reg_read(reg) for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8]]
    if a==0x14055b850:finish(objects)
    elif a==0x140296470:
        exists=c.get('targetExists',True) if (y&0xffffffff)!=99 else c['exists']
        if exists:wq(z,target if (y&0xffffffff)!=99 else actor);finish(0)
        else:finish(1)
    elif a==m.stop+0x10:finish(actor if 5<=c['objectType']<=14 else 0)
    elif a==m.stop+0x20:finish(actor if c['objectType']==5 else 0)
    elif a==m.stop+0x30:finish(actor if c['objectType']==9 else 0)
    elif a==m.stop+0x40:finish(actor if c['objectType']==10 else 0)
    elif a==0x14055b4c0:finish(actor if c['exists'] else 0)
    elif a==0x140494e80:finish((actorArea if c.get('actorArea',True) else 0) if x==actor else targetArea if c.get('targetArea',True) else 0)
    elif a==0x140286330:
        output=dict(position=list(struct.unpack('<3f',u.mem_read(z,12))),nativeOrientation=list(struct.unpack('<3f',u.mem_read(z+12,12))),areaId=si(z+24)&0xffffffff);finish(c.get('push',1))
    elif a in [0x140286410,0x140286470]:
        output=y&0xffffffff
        if a==0x140286410 and output>=0x80000000:output-=0x100000000
        finish(c.get('push',1))
    elif not any(lo<=a<hi for lo,hi in ranges):raise AssertionError(f'Uncaptured spell context dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
    global c,output
    c=case;output=None;u.mem_write(m.heap,bytes(0x100000));wq(0x1412df910,vm);wq(0x1412df970,app);wq(app+8,app)
    wq(actor,vtable);wq(vtable+0x20,m.stop+0x10)
    wq(vtable+0x60,m.stop+0x20);wq(vtable+0x98,m.stop+0x30);wq(vtable+0x30,m.stop+0x40)
    u.mem_write(actor+12,bytes([c.get('objectType',5)]));wi(command+12,99);wi(command+8,c.get('valid',1))
    for off in [0x214,0x218,0x228,0x230,0x234,0x238,0x818]:wi(actor+off,c.get('value',0))
    u.mem_write(actor+0x22d,bytes([c.get('value',0)&255]))
    wi(actorArea+0x140,0x80000002);wi(targetArea+0x140,0x80000003)
    u.mem_write(actor+0x208,struct.pack('<3f',1.25,-2.5,7));u.mem_write(actor+0xb0,struct.pack('<3f',.5,-.25,0))
    u.mem_write(actor+0x23c,struct.pack('<H',c.get('value',0)&65535))
    rsp=m.stack+0x1fe08;u.mem_write(rsp-0x400,bytes(0x500));wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
    u.reg_write(UC_X86_REG_RCX,command);u.reg_write(UC_X86_REG_RDX,{'GetLastSpellCaster':245,'GetLastSpell':246,'GetLastSpellHarmful':423}.get(c['command'],0))
    if c['command']=='initialize':
        u.mem_write(actor+0x208,bytes([0xa5])*0x40);u.reg_write(UC_X86_REG_RSI,actor);u.reg_write(UC_X86_REG_R15,0);u.reg_write(UC_X86_REG_XMM6,0);start=0x14048bab9
    else:start=addresses[c['command']]
    u.emu_start(start,m.stop,count=5000)
    if c['command']=='initialize':
        values={}
        for name,off in fields.items():
            if isinstance(off,list):value=[rf(actor+n) for n in off]
            elif off in [0x21c,0x22c,0x22d]:value=u.mem_read(actor+off,1)[0]
            elif off==0x23c:value=int.from_bytes(u.mem_read(actor+off,2),'little')
            else:value=si(actor+off)&0xffffffff if off in [0x214,0x230] else si(actor+off)
            values[name]=value
        return dict(case=c,fields=values)
    assert u.reg_read(UC_X86_REG_RIP)==m.stop
    return dict(case=c,output=output,result=(u.reg_read(UC_X86_REG_RAX)&0xffffffff))
rows=[run(dict(command='initialize'))]
for commandName,objectType,value in itertools.product(addresses,[0,3,4,5,6,7,9,10,11,12,13,14,15],[0,1,32768,65535,0xffffffff]):rows.append(run(dict(command=commandName,objectType=objectType,value=value,exists=True)))
for commandName in addresses:
    rows.append(run(dict(command=commandName,objectType=5,value=7,exists=False)))
    rows.append(run(dict(command=commandName,objectType=5,value=7,exists=True,push=0)))
for flag in [0,2]:rows.append(run(dict(command='GetSpellTargetObject',objectType=5,value=7,exists=True,valid=flag)))
for flag,objectType,targetExists,hasActorArea,hasTargetArea in itertools.product([0,1,2],[3,4,5,6,9,10,11,14],[False,True],[False,True],[False,True]):rows.append(run(dict(command='GetSpellTargetLocation',objectType=objectType,value=100,exists=True,valid=flag,targetExists=targetExists,actorArea=hasActorArea,targetArea=hasTargetArea)))
out=m.root/'backups/animations/native-spell-context-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2)+'\n');print(json.dumps(dict(rows=len(rows),output=str(out))))
