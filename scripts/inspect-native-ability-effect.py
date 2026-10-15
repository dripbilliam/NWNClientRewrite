"""Original ability constructors, admission, six stat getters and ability
branch of GetTotalEffectBonus. Captured lower owners: VM/alloc/copy, immunity,
score getters during admission, bonus/class-gain during individual stat tests,
combat attack-info/item lookup and server caps. Native grouping/sums, INT/BYTE
arithmetic, amount mutation, child icons and attribute/HP transition branches
execute. Attribute cases capture score/modifier/HP/panel/event lower owners;
item-property apply lifecycle remains a separate acceptance gate.
"""
import importlib.util,itertools,json,struct,random
from pathlib import Path
spec=importlib.util.spec_from_file_location('coordinator',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle);app,actor,source,stats,effect,ints,pool,storage,vtable,rules,races,round,attack,items=[m.heap+n*0x2000 for n in range(1,15)]
storage=m.heap+0x70000 # seventy effect records must not overlap fixture owners.
getters=[0x140406930,0x1403fd3e0,0x1403fa0f0,0x140402d10,0x14040b5e0,0x1403fa050]
def snapshot(ptr):return dict(type=int.from_bytes(u.mem_read(ptr+8,2),'little'),subtype=int.from_bytes(u.mem_read(ptr+0xa,2),'little')&~7,creatorId=m.si(ptr+0x18)&0xffffffff,integers=[m.si(m.q(ptr+0x48)+i*4) for i in range(8)])
def hook(u,a,n,_):
    global allocation,output,maxReads
    if a==m.stop:u.emu_stop();return
    x,y,z,w=[u.reg_read(reg) for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
    if a==m.stop+0x10:m.finish(actor if c.get('objectType',5)==5 else 0)
    elif a==m.stop+0x20:maxReads+=1;calls.append(['maximum',maxReads]);m.finish(c.get('oldMaximum',100) if maxReads==1 else c.get('newMaximum',120))
    elif a==m.stop+0x30:calls.append(['baseHP']);m.finish(m.si(actor+0xe0))
    elif a==m.stop+0x40:calls.append(['animation',y&0xffffffff]);m.finish()
    elif a==0x1404953b0:m.finish(int(m.si(actor+0xe0)<(-9 if c.get('pc',True) else 1)) if c['mode']=='attribute' else c.get('dead',0))
    elif a==0x140495620:m.finish(int(c.get('pc',True) and -10<m.si(actor+0xe0)<1) if c['mode']=='attribute' else c.get('dying',0))
    elif a==0x14055b3d0:m.finish(source if c.get('sourceExists',True) else 0)
    elif a==0x140400ab0:calls.append(['immunity',y&255]);m.finish(c.get('immune',0))
    elif a in getters and c['mode']!='score':calls.append(['score',getters.index(a)]);m.finish(c.get('score',10))
    elif a==0x140393340 and c['mode']=='score':m.finish(c.get('bonus',0))
    elif a==0x1403fa6b0:m.finish(c.get('gain',0))
    elif a==0x140375e40:m.finish(attack)
    elif a==0x14055b6c0:
        ids=c.get('items',[]);m.finish(items+ids.index(y)*0x100 if y in ids else 0)
    elif a==0x14055b260:m.finish(c.get('bonusLimit',12))
    elif a==0x14055b280:m.finish(c.get('penaltyLimit',30))
    elif a==0x140c10410:m.finish(u.reg_read(UC_X86_REG_RAX))
    elif a==0x140286110:m.wi(y,args.pop(0));m.finish(1)
    elif a==0x140c10324:allocation+=1;m.finish(m.heap+0x30000+allocation*0x1000)
    elif a==0x1404233d0:m.wq(x+0x48,x+0x200);m.wi(x+0x18,0x7f000000);m.finish(x)
    elif a==0x140423570:u.mem_write(x,bytes(u.mem_read(y,0x110)));m.wq(x+0x48,x+0x200);u.mem_write(x+0x200,bytes(u.mem_read(m.q(y+0x48),32)));m.finish(x)
    elif a==0x140425110:m.wi(x+0x18,y);m.finish()
    elif a==0x14048e350:
        if c['mode']=='attribute':calls.append(['apply',snapshot(y),z&0xffffffff])
        else:calls.append(['icon',m.si(m.q(y+0x48)),z&0xffffffff])
        m.finish(1)
    elif a==0x1403f16c0:calls.append(['modifier',y&255]);m.finish(((y&255)-10)//2)
    elif a==0x1403db1e0:calls.append(['encumbrance',y]);m.finish()
    elif a==0x140382920:calls.append(['closePanels',y]);m.finish()
    elif a==0x14055b6e0:m.finish(m.heap+0x60000)
    elif a==0x14055b960:m.finish(app)
    elif a==0x1404c6490:m.finish(x)
    elif a==0x1405570b0:
        rsp=u.reg_read(UC_X86_REG_RSP);ptr=m.q(rsp+0x38);calls.append(['dying',w&0xffffffff,m.si(rsp+0x28),m.si(rsp+0x30),int.from_bytes(u.mem_read(ptr,2),'little')]);m.finish()
    elif a==0x140286330:output=snapshot(z);m.finish(1)
    elif a in [0x140423770,0x140c10360]:m.finish()
    elif not any(lo<=a<hi for lo,hi in [(0x1403a7030,0x1403a738c),(0x140517510,0x14051774f),(0x140426db0,0x14042729c),(0x140393340,0x140396274),(0x1402ae870,0x1402ae899),(0x140423fc0,0x140423fcb),(0x140425210,0x14042521c),*[(v,v+0x100) for v in getters]]):raise AssertionError(f'Uncaptured ability dependency {a:x} case={c}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
    global c,calls,allocation,output,args,maxReads
    c=case;calls=[];allocation=maxReads=0;output=None;args=[c.get('ability',0),c.get('amount',4)];u.mem_write(m.heap,bytes(0x100000));m.wq(0x1412df910,app);m.wq(0x1412df970,app);m.wq(app+8,app);m.wi(app+0xc,99);m.wq(actor,vtable);m.wq(vtable+0x60,m.stop+0x10);m.wq(actor+0xad0,stats);m.wq(stats+0x30,actor);m.wi(actor+0xfc,c.get('plot',0));m.wq(actor+0x880,round);m.wq(actor+0x150,pool);m.wi(actor+0x158,len(c.get('effects',[])));m.wq(0x1412df8f8,rules);m.wq(rules+0x118,races)
    for off,ptr in [(0x130,m.stop+0x20),(0x138,m.stop+0x30),(0x100,m.stop+0x40)]:m.wq(vtable+off,ptr)
    m.wi(actor+8,99);m.wi(actor+0xe0,c.get('hp',100));m.wi(actor+0xec,1);m.wi(m.heap+0x60030,66);u.mem_write(actor+0x6b4,bytes([c.get('body',0)]))
    for i,id in enumerate(c.get('items',[])):m.wi(items+i*0x100+0x50,id)
    effects=c.get('effects',[])
    for i,e in enumerate(effects):
        ptr=storage+i*0x200;m.wq(pool+i*8,ptr);u.mem_write(ptr+8,struct.pack('<H',e['type']));m.wq(ptr+0x48,ptr+0x100);m.wi(ptr+0x100,e.get('ability',0));m.wi(ptr+0x104,e.get('amount',4));m.wi(ptr+0x18,e.get('creator',98));m.wi(ptr+0x1c,e.get('spell',-1))
    start=next((i for i,e in enumerate(effects) if e['type']>=36),len(effects));u.mem_write(stats+0xda6,struct.pack('<H',start));m.wq(effect+0x48,ints);u.mem_write(effect+8,struct.pack('<HH',c.get('type',36),8|c.get('durationType',2)));m.wi(effect+0x18,98);m.wi(effect+0x108,c.get('bypass',0));m.wi(ints,c.get('ability',0));m.wi(ints+4,c.get('amount',4))
    rsp=m.stack+0x1fe08;u.mem_write(rsp-0x600,bytes(0x700));m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
    if c['mode']=='constructor':entry=0x140517630 if c['type']==36 else 0x140517510;regs=[app,0,2,0]
    elif c['mode']=='apply':entry=0x140427140 if c['type']==36 else 0x140426db0;regs=[app,actor,effect,c.get('loading',0)]
    elif c['mode']=='bonus':entry=0x140393340;regs=[actor,4,0,0];m.wi(rsp+0x48,c.get('ability',0));m.wi(rsp+0x40,255)
    elif c['mode']=='attribute':entry=0x1403a7030;regs=[actor,effect,c.get('loading',0),0]
    else:
        ability=c['ability'];entry=getters[ability];regs=[stats,0,0,0];u.mem_write(stats+0xd38+ability*2,bytes([c.get('base',10)&255]));u.mem_write(races+[0x18,0x19,0x1d,0x1a,0x1c,0x1b][ability],bytes([c.get('race',0)&255]));u.mem_write(actor+0x8d4,struct.pack('<H',c.get('state',65535)&65535));u.mem_write(actor+0x6ef,bytes([c.get('combatMode',0)&255]))
    for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],regs):u.reg_write(reg,value)
    u.emu_start(entry,m.stop,count=100000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
    result=u.reg_read(UC_X86_REG_RAX)&0xffffffff
    if c['mode']=='bonus' and result>=0x80000000:result-=0x100000000
    if c['mode']=='score':result&=255
    return dict(case=c,calls=calls,result=result if c['mode']!='attribute' else None,amount=m.si(ints+4),output=output,
      attributes=dict(hp=m.si(actor+0xe0),body=u.mem_read(actor+0x6b4,1)[0],commandable=m.si(actor+0xec),dirty=m.si(actor+0x53c),field544=m.si(actor+0x544),modifiers=[u.mem_read(stats+0xd39+i*2,1)[0] for i in range(6)]))
rows=[]
for type,ability,amount in itertools.product([36,37],[-1,0,1,5,6,256],[-1,0,1,4,2147483647]):rows.append(run(dict(mode='constructor',type=type,ability=ability,amount=amount)))
for type,ability,amount,score in itertools.product([36,37],[-1,0,1,5,6],[0,1,4,300],[0,3,4,10,255]):rows.append(run(dict(mode='apply',type=type,ability=ability,amount=amount,score=score)))
for type,loading,dead,dying,duration in itertools.product([36,37],[0,1],[0,1],[0,1],[2,3,4]):rows.append(run(dict(mode='apply',type=type,loading=loading,dead=dead,dying=dying,durationType=duration)))
for ability,base,race,gain,bonus in itertools.product(range(6),[0,3,10,255],[-128,0,127],[-128,0,127],[-128,0,12,127,128,255]):rows.append(run(dict(mode='score',ability=ability,base=base,race=race,gain=gain,bonus=bonus)))
for state,mode in itertools.product([0,1,2,6,65535],[0,11]):rows.append(run(dict(mode='score',ability=1,state=state,combatMode=mode)))
rng=random.Random(20261014)
for case in range(150):
    effects=[dict(type=rng.choice([36,37]),ability=rng.randrange(6),amount=rng.choice([-2,-1,0,1,4,20,2147483647]),creator=rng.choice([98,100,101]),spell=rng.choice([-1,0,3])) for _ in range(rng.randrange(70))];effects.sort(key=lambda e:e['type']);rows.append(run(dict(mode='bonus',effects=effects,items=[100,101],ability=rng.randrange(6),bonusLimit=rng.choice([0,12,300]),penaltyLimit=rng.choice([0,30,300]))))
for ability,loading,hp,newMaximum in itertools.product(range(6),[0,1],[-11,-3,1,100],[80,100,120]):rows.append(run(dict(mode='attribute',ability=ability,loading=loading,hp=hp,oldMaximum=100,newMaximum=newMaximum,score=18)))
for hp,body,pc in itertools.product([1,5,10,15],[0,3,4],[False,True]):rows.append(run(dict(mode='attribute',ability=2,hp=hp,body=body,pc=pc,oldMaximum=100,newMaximum=80)))
out=m.root/'backups/animations/native-ability-effect-observations-v2.json'
out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2)+'\n');print(json.dumps(dict(rows=len(rows),output=str(out))))
