"""Untouched original cast-command/query owners with captured lower boundaries.
Rule cells, spellbook queries, registry, VM stack and AddCastSpellActions are
synthetic boundaries. This proves request selection/argument ordering, not
AIActionCastSpell execution, resource consumption, projectiles or impacts.
"""
import importlib.util,itertools,json,struct
from pathlib import Path
spec=importlib.util.spec_from_file_location('coordinator',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle);q,si,wi,wq,finish=[getattr(m,n) for n in ['q','si','wi','wq','finish']]
commands,actor,stats,rules,spells,vm,app,location,vtable=[m.heap+n*0x1000 for n in range(1,10)]
defs=m.heap+0x20000;spellBase=m.heap+0xa0000
ranges=[(0x140511540,0x140511c51),(0x1405306a0,0x1405307ce),(0x140530b10,0x140530c74)]
def hook(u,a,n,_):
    if a==m.stop:u.emu_stop();return
    x,y,z,w=[u.reg_read(reg) for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
    if a==0x140286110:
        if not inputs:finish(0);return
        wi(y,inputs.pop(0));finish(1)
    elif a==0x140286160:
        if not inputs:finish(0);return
        wi(y,inputs.pop(0));finish(1)
    elif a==0x140286030:wq(z,location);finish(1)
    elif a==0x140c10360:finish()
    elif a==0x140286410:outputs.append((y&0xffffffff)-(0x100000000 if y&0x80000000 else 0));finish(1)
    elif a in [0x14055b4c0,0x14055b3d0]:finish(actor if c.get('actor',True) and (y&0xffffffff)==99 else actor if c.get('target',True) and (y&0xffffffff)==100 and a==0x14055b4c0 else 0)
    elif a==m.stop+0x10:finish(actor if c.get('kind','creature')=='creature' else 0)
    elif a==m.stop+0x20:finish(actor if c.get('kind','creature')=='placeable' else 0)
    elif a==0x1403fa4a0:finish(c['classes'][y&255]['id'])
    elif a==0x140409160:
        calls.append(['uses',y&0xffffffff,z&255,w&255,si(rsp+0x28)&255]);finish(c['classes'][z&255].get('uses',1)&255)
    elif a==0x140404f80:
        cls=c['classes'][y&255];calls.append(['ready',y&255,z&0xffffffff]);u.mem_write(w,bytes([cls.get('level',1)&255]));u.mem_write(q(rsp+0x28),bytes([cls.get('slot',0)&255]));finish(cls.get('ready',1)&255)
    elif a==0x140404c70:
        calls.append(['meta',y&255,z&255,w&255]);finish(c.get('slotMeta',16)&255)
    elif a==0x140403340:calls.append(['ability',y&0xffffffff]);finish(c.get('ability',0))
    elif a==0x140408aa0:calls.append(['casterLevel',y&0xffffffff]);finish(c.get('casterLevel',3)&255)
    elif a==0x1402af4a0:finish(spellBase+(y&0xffffffff)*0x200 if (y&0xffffffff) in c.get('spellIds',[1,2]) else 0)
    elif a==0x1402af530:
        id=(x-spellBase)//0x200;calls.append(['level',id,y&255]);finish(c.get('levels',{}).get(str(id),{}).get(str(y&255),c.get('level',1))&255)
    elif a==0x14037d540:
        args=[y&0xffffffff,z&0xffffffff,w&0xffffffff]+[si(rsp+offset)&0xffffffff for offset in [0x28,0x30]]
        args+=list(struct.unpack('<3f',u.mem_read(q(rsp+0x38),12)))
        args += [si(rsp+offset)&0xffffffff for offset in [0x40,0x48,0x50,0x58]]+[si(rsp+0x60)&255]+[si(rsp+offset)&0xffffffff for offset in [0x68,0x70,0x78]]+[si(rsp+0x80)&255]
        casts.append(['creature',args]);finish(1)
    elif a==0x1404b1880:
        casts.append(['placeable',[y&0xffffffff,z&0xffffffff,*struct.unpack('<3f',u.mem_read(w,12)),si(rsp+0x28)&0xffffffff,si(rsp+0x30)&0xffffffff,si(rsp+0x38)&255]]);finish(1)
    elif not any(lo<=a<hi for lo,hi in ranges):raise AssertionError(f'Uncaptured request boundary {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
    global c,inputs,outputs,calls,casts
    c=case;outputs=[];calls=[];casts=[];u.mem_write(m.heap,bytes(0x100000))
    wq(0x1412df8f8,rules);wq(0x1412df910,vm);wq(0x1412df970,app);wq(app+8,app);wq(rules+0xd0,spells);wq(rules+0x110,defs);wi(spells,c.get('spellCount',64));wi(commands+8,c.get('context',1));wi(commands+12,99)
    wq(actor,vtable);wq(vtable+0x60,m.stop+0x10);wq(vtable+0x98,m.stop+0x20);wi(actor+0xec,c.get('commandable',1));wq(actor+0xad0,stats);u.mem_write(stats+0xd8,bytes([len(c['classes'])]));u.mem_write(location,struct.pack('<3fI',2,3,4,123))
    for cls in c['classes']:
        at=defs+(cls['id']&255)*0x530;wi(at+0x4d8,cls.get('caster',1));wi(at+0x4ec,cls.get('memo',1))
    for id in [1,2]:wi(spellBase+id*0x200+0x178,c.get('master',2) if id==1 else id);u.mem_write(spellBase+id*0x200+0x6f,bytes([c.get('innate',1)&255]))
    rsp=m.stack+0x1fe08;u.mem_write(rsp-0x300,bytes(0x400));wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
    mode=c.get('mode','cast');ordinal=c.get('ordinal',48);id=c.get('id',1);meta=c.get('meta',255);domain=c.get('domain',0)
    if mode=='cast':
        address=0x140511540;inputs=[id]
        if ordinal in [48,501]:inputs.append(100)
        if ordinal not in [501,502]:
            inputs += [meta,c.get('cheat',0)]
            if ordinal==48:inputs.append(domain)
        inputs.append(c.get('path',0))
        argc=c.get('argc',9)
        if ordinal==48:
            if argc>=7:inputs.append(c.get('instant',0))
            if argc>=8:inputs += [c.get('class',-1),c.get('spontaneous',0)]
        elif ordinal==234:
            if argc>=6:inputs.append(c.get('instant',0))
            if argc>=7:inputs += [c.get('class',-1),c.get('spontaneous',0),domain]
    elif mode=='level':address=0x1405306a0;inputs=[c.get('class',0),id];argc=2
    elif mode=='uses':address=0x140530b10;inputs=[99,c.get('class',0),id,meta,domain];argc=5
    if c.get('truncate'):inputs=inputs[:-1]
    for reg,v in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],[commands,ordinal,argc,0]):u.reg_write(reg,v)
    u.emu_start(address,m.stop,count=10000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
    result=u.reg_read(UC_X86_REG_RAX)&0xffffffff;result-=0x100000000 if result&0x80000000 else 0
    return dict(case=c,result=result,outputs=outputs,calls=calls,casts=casts)
def fixture(**kwargs):
    c=dict(classes=[dict(id=0,memo=1)]);c.update(kwargs);return c
rows=[]
for ordinal,cls,meta,cheat,path in itertools.product([48,234,501,502],[-1,0,255,256],[0,16,255],[0,1],[-1,0,4,5]):rows.append(run(fixture(ordinal=ordinal,**{'class':cls},meta=meta,cheat=cheat,path=path)))
for kind,commandable,actorPresent,targetPresent,context in itertools.product(['creature','placeable','other'],[0,1],[False,True],[False,True],[0,1]):rows.append(run(fixture(kind=kind,commandable=commandable,actor=actorPresent,target=targetPresent,context=context)))
for classes in [[],[dict(id=0,memo=0,uses=0),dict(id=1,memo=1)], [dict(id=0,memo=0)], [dict(id=0,memo=0,uses=0)], [dict(id=0,memo=1,ready=0)], [dict(id=0,memo=1,level=255)], [dict(id=n,caster=0) if n<8 else dict(id=n) for n in range(9)]]:
    for ability,casterLevel,meta in itertools.product([0,1,2],[3,255],[0,255]):rows.append(run(fixture(classes=classes,ability=ability,casterLevel=casterLevel,meta=meta)))
for levels,spellIds,innate in itertools.product([{'1':{'0':255},'2':{'0':2}},{'1':{'0':255},'2':{'0':255}}],[[1,2],[1],[]],[1,255]):rows.append(run(fixture(classes=[dict(id=0,memo=0)],levels=levels,spellIds=spellIds,innate=innate)))
for mode,cls,id,meta,domain in itertools.product(['level','uses'],[-256,-1,0,255,256],[-1,1,65],[-1,0,255],[-1,0,256]):rows.append(run(fixture(mode=mode,**{'class':cls},id=id,meta=meta,domain=domain)))
for ordinal,argc in itertools.product([48,234],[5,6,7,8,9]):rows.append(run(fixture(ordinal=ordinal,argc=argc,**{'class':0},instant=2,spontaneous=3,domain=4)))
for id in [-1,64,65]:rows.append(run(fixture(id=id,cheat=1)))
for mode in ['cast','level','uses']:rows.append(run(fixture(mode=mode,truncate=True)))
out=Path(__file__).resolve().parents[1]/'backups/animations/native-cast-request-observations.json'
out.write_text(json.dumps(dict(build='EE89.8193.37-17',sha256='3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a',owners=['140511540','1405306a0','140530b10'],rows=rows),indent=2)+'\n')
print(f'{len(rows)} original request/query executions captured: {out.name}')
