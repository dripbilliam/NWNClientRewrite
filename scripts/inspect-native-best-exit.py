"""Read-only GenerateBestIntraTileExit1402bd950. Candidate construction,
FLOAT/DOUBLE corridor arithmetic, score order and original tile rotations
execute unchanged. Clip/denied/area/creature collision responses are captured
boundaries. Defined synthetic outputs are supplied even for failed clipping.
"""
import importlib.util,itertools,json,re,struct
from pathlib import Path
spec=importlib.util.spec_from_file_location('coordinator',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle);q,si,wi,wq,wf,rf,xmm,finish=[getattr(m,n) for n in ['q','si','wi','wq','wf','rf','xmm','finish']]
surface,tile,area,path,node,entrances,route,vtable=[m.heap+n*0x1000 for n in range(8)];virtual=m.stop+0x100;ranges=[]
for file in ['live-native-intratile-coordinators-full-asm.txt','live-native-tile-coordinate-owner-asm.txt']:
    for line in (m.root/'backups/animations'/file).read_text().splitlines():
        if line.startswith('FUNCTION REQUESTED'):ranges.extend((int(a,16),int(b,16)) for a,b in re.findall(r'([0-9a-f]+):([0-9a-f]+)',line))
def result(name):
    index=counts.get(name,0);counts[name]=index+1;values=c[name];return values[index%len(values)]
def hook(u,a,n,_):
    if a==m.stop:u.emu_stop();return
    x,y,z,w=[u.reg_read(reg) for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
    if a==0x1402c55a0:wi(y,c['tile'][0]);wi(z,c['tile'][1]);finish()
    elif a==0x1402ca830:finish(node)
    elif a==0x140c10410:
        saved=u.reg_read(UC_X86_REG_RAX);finish(saved)
    elif a==0x140115890:raise RuntimeError('Invalid native exit-count fixture')
    elif a==0x1402bb580:
        start=[xmm(UC_X86_REG_XMM2),xmm(UC_X86_REG_XMM3)];end=[rf(rsp+0x28),rf(rsp+0x30)];value=result('clip');calls.append(['clip',start,end,value])
        for n,v in enumerate(start+end+[c['low'],c['high']]):wf(q(rsp+0x38+n*8),v)
        finish(value)
    elif a in [0x1402c3010,0x140297bd0]:
        name='denied' if a==0x1402c3010 else 'polygons';value=result(name);calls.append([name,[xmm(UC_X86_REG_XMM1),xmm(UC_X86_REG_XMM2)],[xmm(UC_X86_REG_XMM3),rf(rsp+0x28)],rf(rsp+0x30),rf(rsp+0x38),rf(rsp+0x40),si(rsp+0x48),value]);finish(value)
    elif a==virtual:
        value=result('creatures');calls.append(['creatures',[xmm(UC_X86_REG_XMM1),xmm(UC_X86_REG_XMM2)],[xmm(UC_X86_REG_XMM3),rf(rsp+0x28)],si(rsp+0x38),si(rsp+0x40),q(rsp+0x48),si(rsp+0x50),value]);finish(value)
    elif not any(lo<=a<hi for lo,hi in ranges):raise RuntimeError(f'Unmapped best-exit dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
    global c,calls,counts
    c=case;calls=[];counts={};u.mem_write(m.heap,bytes(0x100000));wq(0x1412df970,m.heap+0x9000);wq(surface+0x78,entrances);wq(area,vtable);wq(vtable+8,virtual)
    wi(tile+0x1c,c['tile'][0]);wi(tile+0x20,c['tile'][1]);wi(tile+0x24,c['orientation']);wf(tile+0x10,c['height']);wi(path+0xe0,c['tileCount']);wq(path+0xf0,entrances);wq(path+0xe8,route);wf(path+4,c['radius']);wf(path+0xc,.5);wi(path+0xc8,90)
    for n,v in enumerate(c['exit']):wf(entrances+n*4,v)
    for n,v in enumerate(c['route']):wi(route+n*4,v)
    entries=c['entrances'];wi(node+4,len(entries));wq(node+0x10,m.heap+0x8000)
    for n,point in enumerate(entries):
        for axis,v in enumerate(point):wf(m.heap+0x8000+n*8+axis*4,v)
    rsp=m.stack+0x1fe08;u.mem_write(rsp-0x100,bytes(0x200));wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
    for reg,v in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],[surface,tile,area,path]):u.reg_write(reg,v)
    for n,v in enumerate(c['start']):wf(rsp+0x28+n*8,v)
    try:u.emu_start(0x1402bd950,m.stop,count=60000)
    except Exception:print(json.dumps(dict(case=c,rip=hex(u.reg_read(UC_X86_REG_RIP)),calls=calls)));raise
    return dict(case=c,result=u.reg_read(UC_X86_REG_RAX)&0xffffffff,calls=calls,goal=[rf(surface+0x130),rf(surface+0x13c)],bounds=[rf(surface+off) for off in [0x134,0x138,0x140,0x144]],target=si(surface+0x148))
default=dict(tile=[7,10],orientation=0,tileCount=2,exit=[5,0],route=[7,10,7,9,8,9],start=[2,4],height=0,radius=.6,low=0,high=0,entrances=[],clip=[1],denied=[1],polygons=[1],creatures=[1])
rows=[]
for exit,count,o,tiles,radius,mode in itertools.product([[5,0],[5,10],[0,5],[10,5]],[1,2,3],range(4),[2,3],[.05,.6,1.2],range(6)):
    entries=[[value,exit[1]] if exit[1] in [0,10] else [exit[0],value] for value in {1:[5],2:[2.5,7.5],3:[1.666667,5,8.333333]}[count]]
    case=default|dict(exit=exit,entrances=entries,orientation=o,tileCount=tiles,radius=radius)
    if mode==1:case|=dict(clip=[0])
    if mode==2:case|=dict(denied=[0])
    if mode==3:case|=dict(polygons=[0,1])
    if mode==4:case|=dict(creatures=[0,1,1])
    if mode==5:case|=dict(clip=[1,0],denied=[1,0,1],polygons=[1,0],creatures=[1,0])
    rows.append(run(case))
rows += [run(default|dict(exit=[3,3])),run(default|dict(exit=[0,0],entrances=[[0,0]])),run(default|dict(height=2,low=-.2,high=.7,entrances=[[5,0]]))]
out=m.root/'backups/animations/native-best-exit-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2));print(json.dumps(dict(output=str(out),rows=len(rows))))
