"""Original speed/attack-count handlers and movement-factor setter.
Complete original clearing copy constructor executes. Object/dead/immunity,
allocation/icon apply and class/ruleset queries
are captured lower owners. Native INT mutation, FLOAT product order, ID
versus pointer removal, clamping and76c/8e8 writes execute. Setter executes
independently; handler cases capture it as a trace boundary.
"""
import importlib.util,itertools,json,struct
from pathlib import Path
from native_effect_copy_fixture import NativeEffectCopyFixture
from native_rule_fixture import ruleset_hash
spec=importlib.util.spec_from_file_location('coordinator',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle);actor,stats,effect,ints,pool,storage,vtable,app=m.heap,m.heap+0x1000,m.heap+0x2000,m.heap+0x3000,m.heap+0x4000,m.heap+0x5000,m.heap+0x8000,m.heap+0x9000
copy_fixture=NativeEffectCopyFixture(m)
def hook(u,a,n,_):
    global allocation
    if a==m.stop:u.emu_stop();return
    if copy_fixture.handle(a):return
    x,y,z,w=[u.reg_read(reg) for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
    if a==m.stop+0x10:m.finish(actor if c.get('objectType',5)==5 else 0)
    elif a==0x1404953b0:m.finish(c.get('dead',0))
    elif a==0x14055b3d0:m.finish(actor if c.get('sourceExists',True) else 0)
    elif a==0x140400ab0:calls.append(['immunity',y&255]);m.finish(c.get('immune',0))
    elif a==0x1403a3670 and c['mode']!='setter':calls.append(['factor',m.xmm(UC_X86_REG_XMM1)]);m.finish()
    elif a==0x140c10324:allocation+=1;m.finish(m.heap+0x10000+allocation*0x1000)
    elif a==0x14048e350:calls.append(['icon',[m.si(m.q(y+0x48)+i*4) for i in range(8)],z&0xffffffff]);m.finish(1)
    elif a==0x1403fa4a0:m.finish(c.get('classes',[])[y&255][0])
    elif a==0x1403fa4f0:m.finish(c.get('classes',[])[y&255][1]&255)
    elif a==0x1402a40d0:
        value=m.xmm(UC_X86_REG_XMM2)
        for label,v in c.get('rulesOverrides',{}).items():
            if ruleset_hash(label)==y:value=v
        u.reg_write(UC_X86_REG_XMM0,int.from_bytes(struct.pack('<f',value),'little'));m.finish()
    elif not any(lo<=a<hi for lo,hi in [(0x14042ee20,0x14042ef18),(0x14042f110,0x14042f4fd),(0x140437820,0x1404378bb),(0x140437980,0x140437bbf),(0x1403a3670,0x1403a37f1),(0x1402ae870,0x1402ae899),(0x140423fc0,0x140423fcb),(0x140425210,0x14042521c)]):raise AssertionError(f'Uncaptured speed effect dependency {a:x} case={c}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
    global c,calls,allocation
    c=case;calls=[];allocation=0;u.mem_write(m.heap,bytes(0x100000));m.wq(0x1412df970,app);m.wq(app+8,app);m.wq(actor,vtable);m.wq(vtable+0x60,m.stop+0x10);m.wq(actor+0xad0,stats);u.mem_write(stats+0xd8,bytes([len(c.get('classes',[]))&255]));m.wi(actor+0xfc,c.get('plot',0));m.wq(actor+0x150,pool);m.wi(actor+0x158,len(c.get('effects',[])))
    m.wq(effect,77);m.wq(effect+0x48,ints);u.mem_write(effect+8,struct.pack('<HH',c.get('type',28),c.get('durationType',2)));m.wi(effect+0x108,c.get('bypass',0));m.wi(ints,c.get('amount',50))
    for i,e in enumerate(c.get('effects',[])):
        ptr=effect if e.get('samePointer') else storage+i*0x200
        if ptr!=effect:m.wq(ptr,e.get('id',10+i));m.wq(ptr+0x48,ptr+0x100);u.mem_write(ptr+8,struct.pack('<H',e['type']));m.wi(ptr+0x100,e.get('amount',0))
        m.wq(pool+i*8,ptr)
    rsp=m.stack+0x1fe08;u.mem_write(rsp-0x300,bytes(0x400));m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
    if c['mode']=='setter':entry=0x1403a3670;regs=[actor,0,0,0];u.reg_write(UC_X86_REG_XMM1,int.from_bytes(struct.pack('<f',c['value']),'little'))
    elif c['mode']=='apply':entry={28:0x14042f320,29:0x14042f110,59:0x14042ee20}[c['type']];regs=[app,actor,effect,c.get('loading',0)]
    else:entry={28:0x140437aa0,29:0x140437980,59:0x140437820}[c['type']];regs=[app,actor,effect,0]
    for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],regs):u.reg_write(reg,value)
    copy_fixture.prepare(effect);u.emu_start(entry,m.stop,count=15000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
    return dict(case=c,calls=calls,result=u.reg_read(UC_X86_REG_RAX)&0xffffffff if c['mode']!='setter' else None,amount=m.si(ints),field76c=m.si(actor+0x76c),factor=m.rf(actor+0x8e8))
rows=[]
for type,amount,loading,dead,duration in itertools.product([28,29,59],[-2147483648,-101,-1,0,50,99,100,150,2147483647],[0,1],[0,1],[2,3,4]):rows.append(run(dict(mode='apply',type=type,amount=amount,loading=loading,dead=dead,durationType=duration)))
for type,plot,immune,bypass in itertools.product([28,29,59],[0,1],[0,1],[0,1]):rows.append(run(dict(mode='apply',type=type,plot=plot,immune=immune,bypass=bypass)))
for type,sameID,samePointer in itertools.product([28,29,59],[False,True],[False,True]):rows.append(run(dict(mode='remove',type=type,effects=[dict(type=28,amount=150,id=77 if sameID else 11),dict(type=29,amount=50),dict(type=type,amount=10,samePointer=samePointer),dict(type=59,amount=0)])))
for type,amount in itertools.product([28,29],[0,50,150]):rows.append(run(dict(mode='apply',type=type,amount=amount,effects=[dict(type=28,amount=110),dict(type=28,amount=120),dict(type=29,amount=33),dict(type=30,amount=0)])))
for classes,value in itertools.product([[],[[5,0]],[[5,10]],[[0,1],[5,10],[5,0]]],[-1,0,.125,1,1.5,2,3,5]):rows.append(run(dict(mode='setter',classes=classes,value=value)))
rows.append(run(dict(mode='setter',classes=[],value=4,rulesOverrides={'MOVEMENT_SPEED_BONUS_DEFAULT_CAP':5,'MOVEMENT_SPEED_BONUS_MONK_CAP':6})))
out=m.root/'backups/animations/native-speed-effect-observations-v2.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,copyConstructorExecutions=copy_fixture.executions,rows=rows),indent=2)+'\n');print(json.dumps(dict(rows=len(rows),copies=copy_fixture.executions,output=str(out))))
