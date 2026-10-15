"""Original spell defense constructors, registered apply/remove cache
handlers and effect icons. VM, allocation/copy, object casts, immunity/total
resistance, full stat recomputation and nested icon apply are captured lower
owners. Native guards, cache widths/writes, sorted scans, raw budgets, icon
pool growth/state/removal and duration flags execute. No full refresh claim.
"""
import importlib.util,itertools,json,struct
from pathlib import Path
spec=importlib.util.spec_from_file_location('coordinator',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle);app,actor,stats,effect,ints,copy,pool,storage,icons,iconStorage,vtable,rules=[m.heap+n*0x1000 for n in range(1,13)]
def project(ptr):return dict(type=int.from_bytes(u.mem_read(ptr+8,2),'little'),subtype=int.from_bytes(u.mem_read(ptr+0xa,2),'little')&~7,
  durationType=int.from_bytes(u.mem_read(ptr+0xa,2),'little')&7,integers=[m.si(m.q(ptr+0x48)+i*4) for i in range(8)],creatorId=m.si(ptr+0x18)&0xffffffff)
def hook(u,a,n,_):
    global allocation,output
    if a==m.stop:u.emu_stop();return
    x,y,z,w=[u.reg_read(reg) for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
    if a==0x140286110:m.wi(y,args.pop(0));m.finish(1)
    elif a==0x140286330:output=project(z);m.finish(1)
    elif a==0x140c10324:allocation+=1;m.finish(copy+allocation*0x300)
    elif a==0x140c10360 or a==0x140423770:m.finish()
    elif a==0x1404233d0:
        m.wq(x+0x48,x+0x200);m.wi(x+0x18,0x7f000000);m.wi(x+0x20,1);m.wi(x+0x24,1);m.finish(x)
    elif a==0x140423570:u.mem_write(x,bytes(u.mem_read(y,0x110)));m.wq(x+0x48,x+0x200);u.mem_write(x+0x200,bytes(u.mem_read(m.q(y+0x48),32)));m.wi(x+0x20,0);m.finish(x)
    elif a==0x140425110:m.wi(x+0x18,y);m.finish()
    elif a==0x1404953b0:m.finish(c.get('dead',0))
    elif a==m.stop+0x10:m.finish(actor if c.get('objectType',5)==5 else 0)
    elif a==0x14055b3d0:m.finish(actor if c.get('sourceExists',True) else 0)
    elif a==0x140400ab0:calls.append(['immunity',y&255]);m.finish(c.get('immune',0))
    elif a==0x140408dd0:calls.append(['resistance']);m.finish(c.get('totalResistance',0))
    elif a in [0x140416b90,0x140416ba0]:
        calls.append(['cache',a==0x140416ba0,y&255]);u.mem_write(stats+(0xd84 if a==0x140416b90 else 0xd85),bytes([y&255]));m.finish()
    elif a==0x14048e350:calls.append(['icon',project(y),z&0xffffffff]);m.finish(1)
    elif a==0x140c4f038:m.finish(icons)
    elif a==0x140c417f0:u.mem_write(x,bytes(u.mem_read(y,z)));m.finish(x)
    elif not any(lo<=a<hi for lo,hi in [(0x14051bb40,0x14051bf7e),(0x1404338f0,0x140433d6b),(0x140438aa0,0x140438c9d),(0x14042d010,0x14042d200),(0x140436940,0x140436b45),(0x140423fc0,0x140423fcb),(0x140425210,0x14042521c)]):raise AssertionError(f'Uncaptured defense effect dependency {a:x} case={c}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
    global c,calls,allocation,args,output
    c=case;calls=[];allocation=0;args=list(c.get('args',[]));output=None;u.mem_write(m.heap,bytes(0x100000));m.wq(0x1412df970,app);m.wq(app+8,app);m.wq(0x1412df910,app);m.wq(0x1412df8f8,rules);m.wq(rules+0xd0,rules);m.wi(rules,840)
    m.wq(actor,vtable);m.wq(vtable+0x60,m.stop+0x10);m.wq(actor+0xad0,stats);m.wi(actor+0xfc,c.get('plot',0));m.wi(app+0xc,99)
    m.wq(effect+0x48,ints);m.wq(effect,c.get('id',1));u.mem_write(effect+8,struct.pack('<HH',c.get('type',33),c.get('durationType',2)));m.wi(effect+0x24,c.get('showIcon',1));m.wi(effect+0x108,c.get('bypass',0));m.wi(effect+0x18,99)
    for i,value in enumerate(c.get('integers',[c.get('amount',1),0,0,c.get('kind',0)])):m.wi(ints+i*4,value)
    u.mem_write(stats+0xd84,bytes([c.get('increase',0)&255,c.get('decrease',0)&255]));m.wq(actor+0x150,pool);m.wi(actor+0x158,len(c.get('effects',[])))
    for i,e in enumerate(c.get('effects',[])):
        ptr=effect if e.get('samePointer') else storage+i*0x200
        if ptr!=effect:
            m.wq(ptr,e.get('id',i+2));u.mem_write(ptr+8,struct.pack('<HH',e['type'],e.get('durationType',2)));m.wq(ptr+0x48,ptr+0x100)
            for j,value in enumerate(e['integers']):m.wi(ptr+0x100+j*4,value)
        m.wq(pool+i*8,ptr)
    m.wq(actor+0x778,icons);m.wi(actor+0x780,len(c.get('icons',[])));m.wi(actor+0x784,c.get('capacity',16))
    for i,values in enumerate(c.get('icons',[])):
        ptr=iconStorage+i*0x20;m.wq(icons+i*8,ptr);m.wi(ptr,values[0]&65535);m.wi(ptr+4,values[1]);m.wi(ptr+8,values[2])
    rsp=m.stack+0x1fe08;u.mem_write(rsp-0x300,bytes(0x400));m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
    if c['mode']=='constructor':entry={33:0x14051bea0,34:0x14051bdc0,50:0x14051bb40,65:0x14051bc50}[c['type']];regs=[app,0,len(args),0]
    elif c['mode']=='apply':entry={33:0x140433c20,34:0x140433aa0,50:0x1404338f0,65:0x1404339c0}[c['type']];regs=[app,actor,effect,c.get('loading',0)]
    elif c['mode']=='remove':entry=0x140438ba0 if c['type']==33 else 0x140438aa0;regs=[app,actor,effect,0]
    else:entry=0x14042d010 if c['mode']=='iconApply' else 0x140436940;regs=[app,actor,effect,0]
    for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],regs):u.reg_write(reg,value)
    u.emu_start(entry,m.stop,count=10000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
    return dict(case=c,result=u.reg_read(UC_X86_REG_RAX)&0xffffffff,output=output,calls=calls,increase=u.mem_read(stats+0xd84,1)[0],decrease=u.mem_read(stats+0xd85,1)[0],dirty=m.si(actor+0x53c),integer1=m.si(ints+4),capacity=m.si(actor+0x784),icons=[[int.from_bytes(u.mem_read(m.q(icons+i*8),2),'little'),m.si(m.q(icons+i*8)+4),m.si(m.q(icons+i*8)+8)] for i in range(m.si(actor+0x780))],flag20=m.si(actor+0x8b0),flag21=m.si(actor+0x8b4))
rows=[]
for type,amount,loading,dead,duration in itertools.product([33,34],[-1,0,1,127,128,129,256],[0,1],[0,1],[0,2,3,4]):rows.append(run(dict(mode='apply',type=type,amount=amount,loading=loading,dead=dead,durationType=duration,totalResistance=10,decrease=20)))
for type,kind in itertools.product([50,65],[0,1,2]):rows.append(run(dict(mode='apply',type=type,kind=kind)))
for type,field,value in itertools.product([33,34],['plot','immune','bypass','objectType'],[0,1,2,5,6]):rows.append(run(dict(mode='apply',type=type,**{field:value})))
for type,amount in itertools.product([33,34],[-2147483648,-1,0,128,2147483647]):rows.append(run(dict(mode='constructor',type=type,args=[amount])))
for id in [-2,-1,0,839,840,841]:rows.append(run(dict(mode='constructor',type=50,args=[id])))
for level,budget,school in itertools.product([-2,-1,0,9,10],[-1,0,20],[-1,0,8,9]):rows.append(run(dict(mode='constructor',type=65,args=[level,budget,school])))
for type,amount,sameID in itertools.product([33,34],[0,1,128,129,256],[False,True]):rows.append(run(dict(mode='remove',type=type,effects=[dict(type=type,id=1 if sameID else 2,integers=[amount]),dict(type=type,samePointer=True,integers=[])])))
for id,duration,show,existing in itertools.product([-1,0,20,21,106,65536],[0,1,2,3,4],[0,1],[False,True]):rows.append(run(dict(mode='iconApply',type=67,integers=[id,7],durationType=duration,showIcon=show,icons=[[id&65535,1,0]] if existing else [],capacity=1)))
for id,remaining in itertools.product([20,21,106], [[],[dict(type=67,integers=[20,0],durationType=1)],[dict(type=67,integers=[20,1],durationType=3)],[dict(type=67,integers=[20,3],durationType=3),dict(type=67,integers=[20,2],durationType=1)]]):rows.append(run(dict(mode='iconRemove',type=67,integers=[id,0],icons=[[id,0,1]],effects=remaining)))
out=m.root/'backups/animations/native-defense-effect-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2)+'\n');print(json.dumps(dict(rows=len(rows),output=str(out))))
