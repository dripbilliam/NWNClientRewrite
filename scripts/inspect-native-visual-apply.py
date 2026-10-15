"""Untouched visual application140434fc0. Constant-transform container,
2DA reads, area index/object/client lookup, miss point, looping append and
message emission are captured lower owners. Native writes to transform
channels, guards, BYTE/WORD narrowing, radius/3D gates and return paths execute.
This does not prove original transform-controller allocation or render playback.
"""
import importlib.util,itertools,json,struct
from pathlib import Path
spec=importlib.util.spec_from_file_location('coordinator',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle);q,si,wi,wq,wf,rf=[getattr(m,n) for n in ['q','si','wi','wq','wf','rf']]
actor,effect,integers,app,rules,tables,area,ids,transform,channel,text,client,viewers=[m.heap+n*0x1000 for n in range(1,14)]
def projection():return dict(scale=rf(channel+0x84),translate=[rf(channel+off) for off in [0x184,0x1c4,0x204]],rotate=[rf(channel+off) for off in [0xc4,0x104,0x144]])
def hook(u,a,n,_):
    global allocation
    if a==m.stop:u.emu_stop();return
    x,y,z,w=[u.reg_read(reg) for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
    if a==0x140368530:wf(channel+0x84,1);wq(x,transform);m.finish(transform)
    elif a==0x140425890:m.finish(channel)
    elif a==0x140425790:m.finish(x)
    elif a==0x1404246a0:u.mem_write(y,bytes(u.mem_read(effect+0xd0+(z&0xffffffff)*12,12)));m.finish(y)
    elif a==0x1404900b0:u.mem_write(y,struct.pack('<3f',*c.get('missPoint',[2,3,1])));m.finish(y)
    elif a==0x140c10370 or a==0x140c10360 or a==0x140369860:m.finish()
    elif a==0x140c10368:
        ptr=m.heap+0x10000+allocation*0x1000;allocation+=1;m.finish(ptr)
    elif a==0x1401a68f0:
        raw=c.get('kind','B').encode('ascii')+b'\0';u.mem_write(text,raw);wq(w,text);wi(w+8,len(raw)-1);m.finish(c.get('found',1))
    elif a==0x1403591a0:wq(x,transform);wq(x+8,0);m.finish(x)
    elif a==0x14048da00:calls.append(['loop',y&65535,z&0xffffffff,w&255,projection()]);m.finish()
    elif a==0x140494e80:m.finish(area if c.get('area',True) else 0)
    elif a==0x14035e820:wi(y,c.get('first',0));m.finish(c.get('indexSuccess',1))
    elif a==0x14055b4c0:m.finish(viewers+((y&0xffffffff)-100)*0x200 if 100<=(y&0xffffffff)<103 else 0)
    elif a==0x14055b390:
        wi(client,(y&0xffffffff));m.finish(client if c.get('clients',True) else 0)
    elif a==0x14055b810:m.finish(app)
    elif a==0x1404d9640:
        calls.append(['send',si(y),dict(visualId=z&65535,targetId=w&0xffffffff,sourceId=si(rsp+0x28)&0xffffffff,flag=si(rsp+0x30)&255,missMode=si(rsp+0x38)&255,
          position=list(struct.unpack('<3f',u.mem_read(q(rsp+0x40),12))),duration=rf(rsp+0x48),transform=projection())]);m.finish()
    elif not any(lo<=a<hi for lo,hi in [(0x140434fc0,0x140435635),(0x140423fc0,0x140423fcb),(0x140423fb0,0x140423fba),(0x140423fd0,0x140423fdb)]):raise AssertionError(f'Uncaptured visual application dependency {a:x} case={c}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
    global c,calls,allocation
    c=case;calls=[];allocation=0;u.mem_write(m.heap,bytes(0x100000));wq(0x1412df970,app);wq(app+8,app);wq(0x1412df8f8,rules);wq(rules+0x130,tables);wq(tables+0x280,tables)
    wi(actor+8,99);wi(actor+0xfc,c.get('plot',0));wi(actor+0xf0,c.get('destroyable',1));wf(actor+0x268,c.get('range',45));u.mem_write(actor+0xa4,struct.pack('<3f',0,0,0))
    wq(effect+0x48,integers);wi(integers,c.get('id',1));wi(integers+4,c.get('flag',0));wi(integers+8,c.get('miss',0));wi(effect+0xc0,c.get('override',0x7f000000));wi(effect+0x18,c.get('creator',88))
    u.mem_write(effect+0xa,struct.pack('<H',c.get('durationType',0)&65535));wf(effect+0xc,c.get('duration',2));wf(effect+0x50,c.get('scale',1));u.mem_write(effect+0xd0,struct.pack('<6f',*c.get('translate',[1,2,3]),*c.get('rotate',[4,5,6])))
    wi(area+0x230,3);wq(area+0x228,ids)
    for i,point in enumerate(c.get('viewers',[[-1,0,0],[46,0,0],[48,0,0]])):wi(ids+i*4,100+i);wi(viewers+i*0x200+8,100+i);u.mem_write(viewers+i*0x200+0xa4,struct.pack('<3f',*point))
    rsp=m.stack+0x1fe08;u.mem_write(rsp-0x600,bytes(0x700));wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
    for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8],[tables,actor if c.get('actor',True) else 0,effect if c.get('effect',True) else 0]):u.reg_write(reg,value)
    u.emu_start(0x140434fc0,m.stop,count=10000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
    return dict(case=c,calls=calls,result=u.reg_read(UC_X86_REG_RAX)&0xffffffff)
rows=[]
for kind,durationType,miss,scale,flag in itertools.product(['F','P','B','FP','BO','F\0suffix','unknown'],[0,1,2],[0,1,2],[0,1],[0,257]):rows.append(run(dict(kind=kind,durationType=durationType,miss=miss,scale=scale,flag=flag)))
for id,plot,destroyable in itertools.product([118,119,120],[0,1,2],[0,1,2]):rows.append(run(dict(id=id,plot=plot,destroyable=destroyable)))
for key,values in [('actor',[False]),('effect',[False]),('area',[False]),('clients',[False]),('indexSuccess',[0]),('first',[1,2,3]),('range',[-3,0,1,45]),('override',[0,123,0xffffffff]),('missPoint',[[2,3,2]]),('found',[0]),('id',[-1,65536])]:
    for value in values:rows.append(run(dict(**{key:value})))
out=m.root/'backups/animations/native-visual-apply-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2)+'\n');print(json.dumps(dict(rows=len(rows),output=str(out))))
