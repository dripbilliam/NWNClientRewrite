"""Original generic EffectAreaEffect517830, SetCreator4f91f0,
SetShape4f9310 and non-instrumentation AIUpdate4f5de0. Captured lower owners:
VM/string/base allocation, creator lookup, sqrt, clock/difference, anchor/area,
script/subarea/position, event enqueue and common effect update. Native
metadata, shape FLOAT arithmetic and heartbeat/anchor/lifetime branches run.
No full AoE overlap, scripts, destruction or rendering acceptance is claimed.
"""
import importlib.util,itertools,json,struct,math
from pathlib import Path
spec=importlib.util.spec_from_file_location('coordinator',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle);app,aoe,source,vm,effect,ints,vtable,clock,anchor,area=[m.heap+n*0x2000 for n in range(1,11)]
def hook(u,a,n,_):
    global allocation,output,diffReads,stringReads
    if a==m.stop:u.emu_stop();return
    x,y,z,w=[u.reg_read(reg) for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
    if a==0x140286110:m.wi(y,c.get('id',1));m.finish(1)
    elif a==0x1402861b0:
        value=c.get('strings',['','',''])[stringReads];ptr=m.heap+0x30000+stringReads*0x1000;raw=value.encode('ascii');stringReads+=1;u.mem_write(ptr,raw+b'\0');m.wq(y,ptr);m.wi(y+8,len(raw));m.finish(1)
    elif a==0x140c10324:m.finish(effect)
    elif a==0x1404233d0:m.wq(x+0x48,ints);m.finish(x)
    elif a==0x140425110:m.wi(x+0x18,y);m.finish()
    elif a==0x140425310:strings[y]=bytes(u.mem_read(m.q(z),m.si(z+8))).decode('ascii');m.finish()
    elif a==0x140286330:
        output=dict(type=int.from_bytes(u.mem_read(z+8,2),'little'),subtype=int.from_bytes(u.mem_read(z+0xa,2),'little'),creatorId=m.si(z+0x18)&0xffffffff,integers=[m.si(ints+i*4) for i in range(8)],floats=[m.rf(z+0x50+i*4) for i in range(4)],strings=[strings[i] for i in range(3)]);m.finish(1)
    elif a in [0x140423770,0x140c10360,0x140c10370]:m.finish()
    elif a==0x140c10368:allocation+=1;m.finish(m.heap+0x40000+allocation*0x1000)
    elif a==0x14055b3d0:m.finish(source if c.get('sourceExists',True) else 0)
    elif a==m.stop+0x10:m.wi(aoe+0x314,y);m.finish()
    elif a==0x140c7d6d8:u.reg_write(UC_X86_REG_XMM0,int.from_bytes(struct.pack('<f',math.sqrt(m.xmm(UC_X86_REG_XMM0))),'little'));m.finish()
    elif a==0x14016dd30:m.finish(c.get('ticks',1000000))
    elif a==0x14055ba10:m.finish(clock)
    elif a==0x140597180:m.wi(y,c.get('day',7));m.wi(z,c.get('time',10000));m.finish()
    elif a==0x140597a20:
        value=c.get('elapsed',100) if diffReads==0 else c.get('heartbeatElapsed',6000);diffReads+=1;m.wi(m.q(rsp+0x30),0);m.wi(m.q(rsp+0x38),value);m.finish(0)
    elif a==0x1404998a0:calls.append(['script',y&0xffffffff,z&0xffffffff]);m.finish()
    elif a==0x14055b850:m.finish(vm)
    elif a==0x140296470:m.wq(z,anchor if c.get('anchorExists',True) else 0);m.finish(0 if c.get('anchorExists',True) else 1)
    elif a==0x140494e80:m.finish(area if c.get('area',True) else 0)
    elif a==0x1404f94c0:calls.append(['subareas',list(struct.unpack('<3f',u.mem_read(y,12)))]);m.finish()
    elif a==0x14049bb40:
        point=list(struct.unpack('<3f',u.mem_read(y,12)));calls.append(['position',point,z&0xffffffff]);u.mem_write(aoe+0xa4,struct.pack('<3f',*point));m.finish()
    elif a==0x14055b960:m.finish(app)
    elif a==0x1405570b0:calls.append(['event',m.si(rsp+0x30),w&0xffffffff,m.si(rsp+0x28)&0xffffffff]);m.finish()
    elif a==0x1404ac010:calls.append(['effects',y&0xffffffff,z&0xffffffff,w]);m.finish()
    elif not any(lo<=a<hi for lo,hi in [(0x140517830,0x140517a25),(0x140425210,0x14042521c),(0x140425200,0x14042520a),(0x1404f91f0,0x1404f92c8),(0x1404f9310,0x1404f93ec),(0x140047300,0x14004730c),(0x1404f5de0,0x1404f671d)]):raise AssertionError(f'Uncaptured area effect dependency {a:x} case={c}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
    global c,calls,allocation,output,diffReads,stringReads,strings
    c=case;calls=[];allocation=diffReads=stringReads=0;output=None;strings={};u.mem_write(m.heap,bytes(0x100000));m.wq(0x1412df970,app);m.wq(0x1412df8b8,app);m.wq(0x1412df910,vm);m.wq(app+8,app);m.wi(app+0xc,99);m.wq(aoe,vtable);m.wq(vtable+0x180,m.stop+0x10);m.wi(aoe+8,101);m.wi(aoe+0x330,0x7f000000);m.wi(aoe+0x334,c.get('anchor',0x7f000000));m.wi(aoe+0x314,-1);m.wi(aoe+0x340,14);m.wi(aoe+0x344,0);u.mem_write(aoe+0x22c,struct.pack('<H',65535));u.mem_write(aoe+0x23c,struct.pack('<H',65535));m.wi(source+0x820,c.get('override',0));m.wi(source+0x97c,c.get('equipment',0))
    for offset,value in zip([0x9e8,0x9ec,0x9f0],c.get('overrideSpells',[-1,-1,-1])):m.wi(source+offset,value)
    u.mem_write(aoe+0x310,bytes([c.get('shape',0)&255]));m.wf(aoe+0x318,c.get('radius',0));m.wi(aoe+0x388,1);m.wi(aoe+0x38c,c.get('heartbeatTime',1));m.wi(aoe+0x390,c.get('duration',1000));u.mem_write(aoe+0x394,bytes([c.get('durationType',2)]));u.mem_write(anchor+0xa4,struct.pack('<3f',*c.get('position',[1,2,3])));u.mem_write(0x14141e310,b'\0')
    rsp=m.stack+0x1fe08;u.mem_write(rsp-0x400,bytes(0x500));m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
    if c['mode']=='constructor':entry=0x140517830;regs=[app,171,4,0]
    elif c['mode']=='creator':
        entry=0x1404f91f0;regs=[aoe,99,c.get('level',8),c.get('spell',11)]
        for index,value in enumerate([c.get('class',3),c.get('meta',2),c.get('dc',19),c.get('feat',123),c.get('spontaneous',1)]):m.wi(rsp+0x28+index*8,value)
    elif c['mode']=='shape':entry=0x1404f9310;regs=[aoe,c['shape'],0,0];u.reg_write(UC_X86_REG_XMM2,int.from_bytes(struct.pack('<f',c['width']),'little'));u.reg_write(UC_X86_REG_XMM3,int.from_bytes(struct.pack('<f',c['length']),'little'))
    else:entry=0x1404f5de0;regs=[aoe,0,0,0]
    for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],regs):u.reg_write(reg,value&0xffffffffffffffff)
    u.emu_start(entry,m.stop,count=15000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
    state=dict(creator=m.si(aoe+0x330)&0xffffffff,level=m.si(aoe+0x344),spell=m.si(aoe+0x218),effectSpell=m.si(aoe+0x314),dc=m.si(aoe+0x340),classId=u.mem_read(aoe+0x22c,1)[0],meta=u.mem_read(aoe+0x22d,1)[0],feat=int.from_bytes(u.mem_read(aoe+0x23c,2),'little'),spontaneous=m.si(aoe+0x228),shape=u.mem_read(aoe+0x310,1)[0],radius=m.rf(aoe+0x318),width=m.rf(aoe+0x31c),length=m.rf(aoe+0x320),anchor=m.si(aoe+0x334)&0xffffffff,vertices=[list(struct.unpack('<3f',u.mem_read(m.q(aoe+0x328)+i*12,12))) for i in range(4)] if m.q(aoe+0x328) else None,
      previous=dict(day=m.si(aoe+0xbc)&0xffffffff,time=m.si(aoe+0xc0)&0xffffffff),heartbeat=dict(day=m.si(aoe+0x388)&0xffffffff,time=m.si(aoe+0x38c)&0xffffffff),elapsed=m.si(aoe+0xd4)&0xffffffff,duration=m.si(aoe+0x390)&0xffffffff,position=list(struct.unpack('<3f',u.mem_read(aoe+0xa4,12))))
    return dict(case=c,calls=calls,output=output,state=state)
rows=[]
for id,scriptStrings in itertools.product([-1,0,1,65536,2147483647],[['','',''],['enter','pulse','exit'],['a'*40,'','b']]):rows.append(run(dict(mode='constructor',id=id,strings=scriptStrings)))
for sourceExists,override,equipment,spell in itertools.product([False,True],[0,1],[0,1],[-1,11,12]):rows.append(run(dict(mode='creator',sourceExists=sourceExists,override=override,equipment=equipment,spell=spell,overrideSpells=[11,13,14])))
for shape,width,length in itertools.product([0,1,2,256],[-2,0,.1,5,100],[0,.1,5,100]):rows.append(run(dict(mode='shape',shape=shape,width=width,length=length,anchor=99)))
for heartbeat,durationType,duration,elapsed,anchorExists in itertools.product([0,5999,6000,12000],[1,2],[0,100,101],[100],[False,True]):rows.append(run(dict(mode='update',heartbeatElapsed=heartbeat,durationType=durationType,duration=duration,elapsed=elapsed,anchor=99,anchorExists=anchorExists)))
for extra in [dict(heartbeatTime=0),dict(anchor=0x7f000000),dict(shape=1),dict(area=False),dict(elapsed=0),dict(elapsed=0xffffffff)]:rows.append(run(dict(mode='update',anchor=99)|extra))
out=m.root/'backups/animations/native-area-effect-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2)+'\n');print(json.dumps(dict(rows=len(rows),output=str(out))))
