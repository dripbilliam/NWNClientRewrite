"""Original CalculateLastSpellProjectileTime and original magnitude/log SSE.
Captured boundaries: spell/registry lookup, virtual creature cast, inventory
membership, CRT sqrt and log exception/errno helper. No projectile recipient,
impact script, effect or original CPU-state parity is claimed.
"""
import importlib.util,json,struct,itertools,math,random
from pathlib import Path
spec=importlib.util.spec_from_file_location('coordinator',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle);q,si,wi,wq,wf,rf,finish=[getattr(m,n) for n in ['q','si','wi','wq','wf','rf','finish']]
actor,target,spell,rules,app,vtable,item,repo,equipment=[m.heap+n*0x1000 for n in range(1,10)]
ranges=[(0x14048fe20,0x1404900af),(0x1402303d0,0x14023040d),(0x140c946b0,0x140c94aa6)]
def floating(value):u.reg_write(UC_X86_REG_XMM0,int.from_bytes(struct.pack('<f',value),'little'));finish()
def hook(u,a,n,_):
    if a==m.stop:u.emu_stop();return
    x,y,z=[u.reg_read(reg) for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8]]
    if a==0x1402af4a0:finish(spell if c.get('spellExists',True) else 0)
    elif a==m.stop+0x10:finish(actor if c.get('creature',True) else 0)
    elif a==0x14055b6c0:finish(item if c.get('item',False) else 0)
    elif a==0x140468bd0:calls.append(['repository']);finish(c.get('repository',0))
    elif a==0x140462b40:calls.append(['equipped']);finish(c.get('equipped',0))
    elif a==0x14055b850:finish(app)
    elif a==0x140296470:
        if c.get('targetExists',True):wq(z,target);finish(0)
        else:finish(1)
    elif a==0x140c7d6d8:floating(math.sqrt(m.xmm(UC_X86_REG_XMM0)))
    elif a==0x140cb5b64:calls.append(['log-exception',z&0xffffffff]);u.reg_write(UC_X86_REG_XMM0,u.reg_read(UC_X86_REG_XMM1));finish()
    elif not any(lo<=a<hi for lo,hi in ranges):raise AssertionError(f'Uncaptured projectile dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
    global c,calls
    c=case;calls=[];u.mem_write(m.heap,bytes(0x100000));wq(0x1412df8f8,rules);wq(rules+0xd0,rules);wq(0x1412df970,app);wq(app+8,app);wi(0x1415d8224,0)
    wq(actor,vtable);wq(vtable+0x60,m.stop+0x10);wq(actor+0x958,repo);wq(actor+0x950,equipment)
    wi(actor+0x218,1);wi(actor+0x214,0x7f000000 if c.get('location',False) else 100);wi(actor+0x220,777)
    for off,values in [(0xa4,c.get('from',[1,2,3])),(0x208,c.get('to',[4,6,7]))]:
        for i,value in enumerate(values):wf(actor+off+i*4,value)
    for i,value in enumerate(c.get('to',[4,6,7])):wf(target+0xa4+i*4,value)
    wi(spell+0x128,c.get('projectile',1));wi(spell+0x140,c.get('defaultPath',0))
    rsp=m.stack+0x1fe08;u.mem_write(rsp-0x200,bytes(0x300));wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,actor);u.reg_write(UC_X86_REG_RDX,c.get('path',0)&255)
    u.emu_start(0x14048fe20,m.stop,count=10000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
    return dict(case=c,time=si(actor+0x220),calls=calls)
rows=[]
for distance,path,defaultPath,location in itertools.product([0,.1,.5,1,2,3,10,30,100,100000],range(9),[0,1,3,5,6,7,8],[False,True]):rows.append(run(dict(**{'from':[0,0,0]},to=[distance,0,0],path=path,defaultPath=defaultPath,location=location)))
for itemFlag,repository,equipped,creature in itertools.product([False,True],[0,1,2],[0,1,2],[False,True]):rows.append(run(dict(item=itemFlag,repository=repository,equipped=equipped,creature=creature)))
for key,values in [('projectile',[0,2]),('spellExists',[False]),('targetExists',[False]),('defaultPath',[262,256,-1]),('path',[256,257,-1])]:
    for value in values:rows.append(run(dict(**{key:value})))
rng=random.Random(3737)
for i in range(256):rows.append(run(dict(**{'from':[rng.uniform(-100,100) for _ in range(3)]},to=[rng.uniform(-100,100) for _ in range(3)],path=i%9,defaultPath=i%9)))
out=m.root/'backups/animations/native-spell-projectile-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2)+'\n');print(json.dumps(dict(rows=len(rows),output=str(out))))
