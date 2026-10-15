"""Untouched AddCastSpellActions, ComputeSpellRange and WaitForEndOfRound.
Captured boundaries: registry/visibility, spell eligibility, area lookup,
string/CRT allocation, object queue append and movement helper. Queue captures
are raw native calls, not packet serialization or a complete timed cast.
"""
import importlib.util,itertools,json,struct
from pathlib import Path
spec=importlib.util.spec_from_file_location('coordinator',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle);q,si,wi,wq,wf,rf,finish=[getattr(m,n) for n in ['q','si','wi','wq','wf','rf','finish']]
actor,target,stats,area,otherArea,rules,spells,app,point,visibility,vtable,spell,roundState,space,targetSpace,string,allocated=[m.heap+n*0x1000 for n in range(1,18)]
ranges=[(0x14037d540,0x14037e460),(0x140388d20,0x140388f2e),(0x1403cf7e0,0x1403cff24),
        (0x1403b0510,0x1403b0d6a),(0x1403b0d70,0x1403b1537),(0x140230920,0x1402309f5)]
def floatfinish(value):u.reg_write(UC_X86_REG_XMM0,int.from_bytes(struct.pack('<f',value),'little'));finish()
def hook(u,a,n,_):
    if a==m.stop:u.emu_stop();return
    x,y,z,w=[u.reg_read(reg) for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
    if a==0x1403a2480:calls.append(['feedback',y&0xffffffff]);finish()
    elif a==0x140403340:calls.append(['ability']);finish(c.get('ability',1))
    elif a==0x140409160:calls.append(['uses',y&0xffffffff,z&255,w&255,si(rsp+0x28)&255]);finish(c.get('uses',1))
    elif a==0x14055b4c0:finish(target if (y&0xffffffff)==100 and c.get('targetExists',True) else 0)
    elif a==0x14055b3d0:finish(target if (y&0xffffffff)==100 and c.get('targetType',5)==5 and c.get('targetExists',True) else 0)
    elif a==0x140402f80:finish(c.get('dm',0))
    elif a==m.stop+0x10:finish(target if c.get('targetType',5)==5 else 0)
    elif a==m.stop+0x20:finish(target if c.get('targetType',5)==6 else 0)
    elif a==m.stop+0x30:calls.append(['lock',y&0xffffffff]);finish()
    elif a==m.stop+0x40:finish(target)
    elif a==0x14055b850:finish(app)
    elif a==0x140296470:
        if c.get('targetExists',True):wq(z,target);finish(0)
        else:finish(1)
    elif a==0x140230920:
        vector=list(struct.unpack('<3f',u.mem_read(y,12)));calls.append(['normalize',*vector])
    elif a==0x140c7d6d8:
        value=struct.unpack('<f',struct.pack('<I',u.reg_read(UC_X86_REG_XMM0)&0xffffffff))[0];floatfinish(value**.5)
    elif a==0x14049b910:calls.append(['orientation',*struct.unpack('<3f',u.mem_read(y,12))]);finish()
    elif a==0x140501780:u.mem_write(y,struct.pack('<3f',*c.get('triggerPoint',[3,4,5])));finish(y)
    elif a==0x1403d5850:finish(visibility if c.get('visible',True) else 0)
    elif a==0x140494e80:finish((area if c.get('actorArea',True) else 0) if x==actor else area if c.get('sameArea',True) else otherArea if c.get('targetArea',True) else 0)
    elif a==0x1402af4a0:finish(spell if c.get('spellExists',True) else 0)
    elif a==0x14019e620:u.mem_write(x,bytes(u.mem_read(y,16)));finish(x)
    elif a==0x140388d20 and c['mode']=='queue':calls.append(['range',z&0xffffffff]);floatfinish(c.get('range',3))
    elif a in [0x14048cb80,0x14048d3f0]:
        params=[]
        for index in range(12):
            type=(w&0xffffffff) if index==0 else si(rsp+0x30+16*(index-1))&0xffffffff
            if not type:break
            ptr=q(rsp+0x28+16*index);params.append([type,si(ptr)&0xffffffff])
        calls.append(['queue','front' if a==0x14048d3f0 else 'tail',y&0xffffffff,z&65535,params]);finish(1)
    elif a==0x14037f940:
        calls.append(['move',y&65535,*struct.unpack('<3f',u.mem_read(z,12)),w&0xffffffff,si(rsp+0x28)&0xffffffff,si(rsp+0x30),rf(rsp+0x38),rf(rsp+0x40),*[si(rsp+off) for off in [0x48,0x50,0x58,0x60,0x68,0x70]]]);finish(1)
    elif a in [0x140c10370,0x140c10360]:finish()
    elif a==0x140c10368:finish(allocated)
    elif a==0x1404953b0:calls.append(['dead']);finish(c.get('dead',0))
    elif a==0x140495620:calls.append(['dying']);finish(c.get('dying',0))
    elif a==0x1403766e0:calls.append(['pending']);finish(c.get('pending',0))
    elif not any(lo<=a<hi for lo,hi in ranges):raise AssertionError(f'Uncaptured spell queue dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
    global c,calls
    c=case;calls=[];u.mem_write(m.heap,bytes(0x100000));wq(0x1412df8f8,rules);wq(rules+0xd0,spells);wq(0x1412df970,app);wq(app+8,app)
    wq(actor+0xad0,stats);wi(actor+8,99);wi(target+8,100);u.mem_write(target+12,bytes([c.get('targetType',5)]));wi(actor+0xec,c.get('commandable',1));u.mem_write(actor+0x771,bytes([c.get('activity',0)]));wi(actor+0x97c,c.get('override',0));wi(actor+0x9e8,c.get('overrideId',1));wi(actor+0x9ec,2);wi(actor+0x9f0,3);wi(actor+0x73c,123);wi(actor+0x740,456);wi(target+0x3c8,c.get('possessor',99));wi(area+0x140,88)
    wq(target,vtable);wq(actor,vtable);wq(vtable+0x60,m.stop+0x10);wq(vtable+0x70,m.stop+0x20);wq(vtable+0x188,m.stop+0x30);wq(vtable+0x20,m.stop+0x40);wq(vtable+0x80,m.stop+0x40);u.mem_write(visibility+4,bytes([c.get('visibilityFlags',3)]))
    position=c.get('position',[0,0,0]);targetPosition=c.get('targetPosition',[2,0,0]);requestPoint=c.get('point',[2,0,0])
    u.mem_write(actor+0xa4,struct.pack('<3f',*position));u.mem_write(target+0xa4,struct.pack('<3f',*targetPosition));u.mem_write(point,struct.pack('<3f',*requestPoint));wq(actor+0x880,roundState);wi(roundState+0x2f04,c.get('started',0))
    for addr in [0x14141e310,0x14141e311]:u.mem_write(addr,b'\0')
    mode=c['mode'];rsp=m.stack+0x1fe08;u.mem_write(rsp-0x400,bytes(0x500));wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
    if mode=='queue':
        address=0x14037d540;args=[actor,1,c.get('class',0),c.get('domain',0)]
        for off,value in [(0x28,c.get('meta',0)),(0x30,c.get('spontaneous',0)),(0x40,c.get('target',100)),(0x48,c.get('location',0)),(0x50,c.get('front',0)),(0x58,c.get('cheat',0)),(0x60,c.get('path',0)),(0x68,c.get('instant',0)),(0x70,0),(0x78,c.get('feat',-1)),(0x80,c.get('casterLevel',255))]:wi(rsp+off,value)
        wq(rsp+0x38,point)
    elif mode=='range':
        address=0x140388d20;args=[actor,string,c.get('target',100),0];raw=(c.get('text') or '').encode('ascii')+b'\0';u.mem_write(point,raw);wq(string,point if c.get('text') is not None else 0);wi(string+8,len(raw)-1);wi(string+12,len(raw))
        for index,value in enumerate(c.get('ranges',[1,2,3,4,5])):wf(rules+8+index*4,value)
        wq(actor+0x530,space);wf(space+8,c.get('space',.5));wq(target+0x530,targetSpace);wf(targetSpace+8,c.get('targetSpace',.5))
    elif mode in ['faceObject','facePoint']:
        address=0x1403b0510 if mode=='faceObject' else 0x1403b0d70;args=[actor,point,0,0]
        if mode=='faceObject':wi(point+0x38,100)
        else:
            for i,value in enumerate(requestPoint):wf(point+0x38+i*8,value)
    else:address=0x1403cf7e0;args=[actor,point,0,0]
    for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],args):u.reg_write(reg,value)
    u.emu_start(address,m.stop,count=20000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
    result=u.reg_read(UC_X86_REG_RAX)&0xffffffff
    if mode=='range':result=struct.unpack('<f',struct.pack('<I',u.reg_read(UC_X86_REG_XMM0)&0xffffffff))[0]
    return dict(case=c,result=result,calls=calls,target73c=si(actor+0x73c)&0xffffffff,target740=si(actor+0x740)&0xffffffff,point=list(struct.unpack('<3f',u.mem_read(point,12))) if mode=='queue' else None)
rows=[]
for front,instant,location,carry,distance in itertools.product([0,1],[0,1,2],[0,1],[False,True],[1,3,10]):
    rows.append(run(dict(mode='queue',front=front,instant=instant,location=location,target=0x7f000000 if location else 100,sameArea=not carry,targetType=6 if carry else 5,targetPosition=[distance,0,0],point=[distance,0,0])))
for cls,uses,ability,cheat,spontaneous in itertools.product([0,254,255,256],[0,1],[0,1],[0,1],[0,1]):rows.append(run(dict(mode='queue',**{'class':cls},uses=uses,ability=ability,cheat=cheat,spontaneous=spontaneous)))
for key,values in [('activity',[0,5]),('visibilityFlags',[0,3,4,12,16,17,255]),('visible',[False]),('commandable',[0]),('actorArea',[False]),('sameArea',[False]),('targetType',[0,4,6]),('targetExists',[False]),('spellExists',[False]),('possessor',[0]),('override',[1]),('dm',[1])]:
    for value in values:rows.append(run(dict(mode='queue',**{key:value})))
for dead,dying,started,pending in itertools.product([0,1,2],[0,1,2],[0,1,2],[0,1]):rows.append(run(dict(mode='wait',dead=dead,dying=dying,started=started,pending=pending)))
for text,exists,spaceValue in itertools.product([None,'','P','T','S','M','L','p','P ','TT','S\0extra'],[False,True],[.1,.5,2]):rows.append(run(dict(mode='range',text=text,targetExists=exists,space=spaceValue)))
for mode,positionValue,dead,dying in itertools.product(['faceObject','facePoint'],[[0,0,0],[.005,0,0],[.01,0,0],[2,3,7]], [0,1,2],[0,1,2]):rows.append(run(dict(mode=mode,targetPosition=positionValue,point=positionValue,dead=dead,dying=dying)))
for targetType,sameArea,targetExists in itertools.product([0,4,5,7,9],[False,True],[False,True]):rows.append(run(dict(mode='faceObject',targetType=targetType,sameArea=sameArea,targetExists=targetExists)))
out=m.root/'backups/animations/native-spell-queue-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2)+'\n');print(json.dumps(dict(rows=len(rows),queue=sum(row['case']['mode']=='queue' for row in rows),wait=sum(row['case']['mode']=='wait' for row in rows),range=sum(row['case']['mode']=='range' for row in rows),output=str(out))))
