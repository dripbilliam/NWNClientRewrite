"""Original location-effect VM wrapper and point visual broadcast. VM,
area lookup/cast, transform container/allocation/current-channel copy, FLOAT
2DA, area index/client/object lookup and delivery are captured boundaries.
Native duration writes, constant channels, radius+45, early X exit, type/3D
guards and WORD visual IDs execute. No render/network or AoE/beam claim.
"""
import importlib.util,itertools,json,struct
from pathlib import Path
spec=importlib.util.spec_from_file_location('coordinator',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle);app,area,effect,ints,location,head,node,rules,tables,ids,viewers,client=[m.heap+n*0x1000 for n in range(1,13)]
def transform():return dict(scale=m.rf(node+0xb0),translate=[m.rf(node+off) for off in [0x1b0,0x1f0,0x230]],rotate=[m.rf(node+off) for off in [0xf0,0x130,0x170]])
def hook(u,a,n,_):
    global allocation
    if a==m.stop:u.emu_stop();return
    x,y,z,w=[u.reg_read(reg) for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
    if a==0x140286110:m.wi(y,c.get('durationType',0));m.finish(1)
    elif a==0x140286030:m.wq(z,effect if y==0 else location);m.finish(1)
    elif a==0x1402860c0:m.wf(y,c.get('seconds',1));m.finish(1)
    elif a==0x14055b850:m.finish(app)
    elif a==0x140296470:
        if c['mode']=='wrapper':m.wq(z,area);m.finish(0 if c.get('areaExists',True) else 1)
        else:m.wq(z,viewers+((y&0xffffffff)-100)*0x200);m.finish(0)
    elif a==m.stop+0x10:m.finish(area if c.get('areaType',4)==4 else 0)
    elif a==0x14035bdf0:calls.append(['area',int.from_bytes(u.mem_read(effect+0xa,2),'little'),m.rf(effect+0xc),list(struct.unpack('<3f',u.mem_read(z,12))),list(struct.unpack('<3f',u.mem_read(w,12)))]);m.finish()
    elif a==0x140368530:
        m.wq(head,head);m.wq(head+8,head);u.mem_write(head+0x19,bytes([1]));m.wf(node+0xb0,1);m.finish(head)
    elif a==0x140359470:m.finish(node)
    elif a==0x140359b60:m.wq(y,node);m.finish()
    elif a in [0x1402ea110,0x140369860,0x140c10360,0x140c10370,0x140423770]:m.finish()
    elif a==0x140c10368:allocation+=1;m.finish(m.heap+0x20000+allocation*0x100)
    elif a==0x1404246a0:u.mem_write(y,bytes(u.mem_read(effect+0xd0+(z&0xffffffff)*12,12)));m.finish(y)
    elif a==0x1401a6c70:m.wf(w,c.get('radius',0));m.finish(c.get('radiusFound',1))
    elif a==0x14035e820:m.wi(y,c.get('first',0));m.finish(c.get('indexSuccess',1))
    elif a==0x14055b390:m.wi(client+0x48,y);m.finish(client if c.get('clients',True) else 0)
    elif a==0x14055b810:m.finish(app)
    elif a==0x1403591a0:m.wq(x,head);m.wq(x+8,1);m.finish(x)
    elif a==0x1404cea60:calls.append(['send',m.si(y+0x48)&0xffffffff,dict(visualId=z&65535,position=list(struct.unpack('<3f',u.mem_read(w,12))),transform=transform())]);m.finish()
    elif not any(lo<=a<hi for lo,hi in [(0x140510710,0x1405108a5),(0x140364670,0x140364bb5),(0x140423fc0,0x140423fcb),(0x140423fb0,0x140423fba)]):raise AssertionError(f'Uncaptured location dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
    global c,calls,allocation
    c=case;calls=[];allocation=0;u.mem_write(m.heap,bytes(0x100000));m.wq(0x1412df910,app);m.wq(0x1412df970,app);m.wq(app+8,app);m.wq(0x1412df8f8,rules);m.wq(rules+0x130,tables);m.wq(tables+0x280,tables)
    m.wq(effect+0x48,ints);m.wi(ints,c.get('id',1));u.mem_write(effect+0xa,struct.pack('<H',c.get('packed',8)&65535));m.wf(effect+0xc,7);m.wf(effect+0x50,c.get('scale',1));u.mem_write(effect+0xd0,struct.pack('<6f',*c.get('translate',[1,2,3]),*c.get('rotate',[4,5,6])))
    u.mem_write(location,struct.pack('<6fI',*c.get('point',[0,0,0]),1,0,0,99));m.wq(area,m.heap+0xf000);m.wq(m.heap+0xf000+0x50,m.stop+0x10);m.wq(area+0x228,ids);m.wi(area+0x230,3)
    for i,point in enumerate(c.get('viewers',[[-1,0,0],[45,0,0],[46,0,0]])):
        ptr=viewers+i*0x200;m.wi(ids+i*4,100+i);m.wi(ptr+8,100+i);u.mem_write(ptr+0xc,bytes([c.get('viewerTypes',[5,5,5])[i]]));u.mem_write(ptr+0xa4,struct.pack('<3f',*point))
    rsp=m.stack+0x1fe08;u.mem_write(rsp-0x400,bytes(0x500));m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
    entry=0x140510710 if c['mode']=='wrapper' else 0x140364670
    for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8],[app if c['mode']=='wrapper' else area,effect,location]):u.reg_write(reg,value)
    u.emu_start(entry,m.stop,count=10000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
    return dict(case=c,calls=calls)
rows=[]
for duration,packed,seconds,exists,type in itertools.product([0,1,2,-1],[0,1,2,3,8,15],[0,-1,1],[False,True],[4,5]):rows.append(run(dict(mode='wrapper',durationType=duration,packed=packed,seconds=seconds,areaExists=exists,areaType=type)))
for radius,scale,first,clients in itertools.product([-46,-45,-1,0,1,100],[0,1,2],[0,1,3],[False,True]):rows.append(run(dict(mode='visual',radius=radius,scale=scale,first=first,clients=clients)))
for key,values in [('point',[[1,2,3],[100,10,-5]]),('id',[-1,65536]),('viewerTypes',[[3,4,5],[5,3,4]]),('indexSuccess',[0])]:
    for value in values:rows.append(run(dict(mode='visual',**{key:value})))
out=m.root/'backups/animations/native-location-effect-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2)+'\n');print(json.dumps(dict(rows=len(rows),output=str(out))))
