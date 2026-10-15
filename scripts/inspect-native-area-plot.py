"""Read-only CNWSArea::PlotPath14036fc70. Profiling disabled; real loop,
timer budgets, physical route shifts, exclusion append and retry storage run
unchanged. Region/search/tile plot/reset/smoothing are captured boundaries.
This is coordinator evidence, not a complete authored encounter comparison.
"""
import importlib.util,itertools,json
from pathlib import Path
spec=importlib.util.spec_from_file_location('coordinator',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle);q,si,wi,wq,wf,rf,xmm,finish=[getattr(m,n) for n in ['q','si','wi','wq','wf','rf','xmm','finish']]
area,path,aimaster,tiles,route,exits,points,avoidTiles,avoidExits=[m.heap+n*0x1000 for n in range(9)]
def tick():
    global ticks
    value=1000+ticks*c['tickStep'];ticks+=1;return value
def path_array(off,kind):
    pointer=q(path+off);count=si(path+(0xe0 if off in [0xe8,0xf0] else 0xcc))*2
    return [(si if kind=='int' else rf)(pointer+n*4) for n in range(count)] if pointer else []
def hook(u,a,n,_):
    global allocation,generations,plots
    if a==m.stop:u.emu_stop();return
    x,y,z,w=[u.reg_read(reg) for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
    if a==0x14055b960:finish(aimaster)
    elif a==0x14016dd30:finish(tick())
    elif a==0x1404fda30:calls.append(['region',[si(x+0x1c),si(x+0x20)],[xmm(UC_X86_REG_XMM1),xmm(UC_X86_REG_XMM2)]]);finish(0)
    elif a==0x14036be10:finish(tiles+(si_value(y)+si_value(z)*3)*0x68)
    elif a==0x1404fdb30:calls.append(['exitNumber',[si(x+0x1c),si(x+0x20)],[xmm(UC_X86_REG_XMM1),xmm(UC_X86_REG_XMM2)]]);finish(5)
    elif a==0x14036bc90:
        calls.append(['generate',si(y),si_value(z),si_value(w),si(rsp+0x28),path_array(0xd0,'int'),path_array(0xd8,'int')]);wi(y,si(y)+2);generations+=1
        outcome=c['generate'][min(generations-1,len(c['generate'])-1)]
        wi(path+0xe0,len(c['route'])//2)
        for n,v in enumerate(c['route']):wi(q(path+0xe8)+n*4,v)
        for n,v in enumerate(c['exits']):wf(q(path+0xf0)+n*4,v)
        finish(outcome)
    elif a==0x1404fe1b0:
        tile=[si(x+0x1c),si(x+0x20)];start=[xmm(UC_X86_REG_XMM3),rf(rsp+0x28)];end=[rf(rsp+0x30),rf(rsp+0x38)]
        response=c['results'][min(plots,len(c['results'])-1)];plots+=1;calls.append(['tilePlot',tile,start,end,si(rsp+0x40),response])
        if response==2:
            old=si(path+0x88);to=c['goal'] if si(path+0xe0)==1 else [tile[0]*10+rf(q(path+0xf0)),tile[1]*10+rf(q(path+0xf0)+4)]
            pointer=q(path+0x90) or points;wq(path+0x90,pointer)
            for n,v in enumerate([tile[0]*10+start[0],tile[1]*10+start[1]]+to):wf(pointer+(old+n)*4,v)
            wi(path+0x88,old+4)
        finish(response)
    elif a==0x140294a80:
        calls.append(['resetWaypoints']);wi(path+0x88,0);wi(path+0x7c,0);wq(path+0x90,0);wq(path+0x80,0);finish()
    elif a==0x140294980:
        calls.append(['resetInterTile']);wi(path+0xe0,0);wi(path+0xcc,0);wq(path+0xe8,0);wq(path+0xf0,0);wq(path+0xd0,0);wq(path+0xd8,0);finish()
    elif a==0x140371560:
        calls.append(['smooth']);wi(path+0x7c,si(path+0x88));wq(path+0x80,q(path+0x90));finish(1)
    elif a==0x140c10368:
        ptr=m.heap+0x10000+allocation*0x4000;allocation+=1;u.mem_write(ptr,bytes(min(x,0x4000)));finish(ptr)
    elif a==0x140c10370:finish()
    elif a==0x140c417f0:u.mem_write(x,bytes(u.mem_read(y,z)));finish(x)
    elif not 0x14036fc70<=a<0x140370e58:raise RuntimeError(f'Unmapped area plot dependency {a:x}')
def si_value(value):return value if value<0x80000000 else value-0x100000000
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
    global c,calls,allocation,generations,plots,ticks
    c=case;calls=[];allocation=generations=plots=ticks=0;u.mem_write(m.heap,bytes(0x100000));wq(0x1412df970,m.heap+0x9000);wq(0x1412df8b8,m.heap+0xa000);wi(area+0xc,3);wi(area+0x10,3);wq(area+0x1c8,tiles)
    for y in range(3):
        for x in range(3):wi(tiles+(x+y*3)*0x68+0x1c,x);wi(tiles+(x+y*3)*0x68+0x20,y)
    wi(path+0x60,100);wi(path+0x70,c['startArea']);wi(path+0x78,c['complete']);wi(path+0xe0,len(c['route'])//2 if c['resume'] else 0);wq(path+0xe8,route if c['resume'] else 0);wq(path+0xf0,exits if c['resume'] else 0)
    for off,v in zip([0x64,0x68,0x4c,0x50],c['start']+c['goal']):wf(path+off,v)
    for n,v in enumerate(c['route']):wi(route+n*4,v)
    for n,v in enumerate(c['exits']):wf(exits+n*4,v)
    wi(path+0x88,len(c['old']));wq(path+0x90,points if c['old'] else 0)
    for n,v in enumerate(c['old']):wf(points+n*4,v)
    wi(path+0xcc,len(c['avoidTiles'])//2);wq(path+0xd0,avoidTiles if c['avoidTiles'] else 0);wq(path+0xd8,avoidExits if c['avoidTiles'] else 0)
    for n,v in enumerate(c['avoidTiles']):wi(avoidTiles+n*4,v)
    for n,v in enumerate(c['avoidExits']):wi(avoidExits+n*4,v)
    rsp=m.stack+0x1fe08;u.mem_write(rsp-0x100,bytes(0x200));wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
    for reg,v in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8],[area,path,c['budget']]):u.reg_write(reg,v)
    try:u.emu_start(0x14036fc70,m.stop,count=300000)
    except Exception:print(json.dumps(dict(case=c,rip=hex(u.reg_read(UC_X86_REG_RIP)),calls=calls)));raise
    assert u.reg_read(UC_X86_REG_RIP)==m.stop
    length=si(path+0x88);pointer=q(path+0x90);output=q(path+0x80)
    return dict(case=c,result=u.reg_read(UC_X86_REG_RAX)&0xffffffff,calls=calls,route=path_array(0xe8,'int'),exits=path_array(0xf0,'float'),avoidTiles=path_array(0xd0,'int'),avoidExits=path_array(0xd8,'int'),waypoints=[rf(pointer+n*4) for n in range(length)] if pointer else [],output=[rf(output+n*4) for n in range(si(path+0x7c))] if output else [],mark=si(aimaster+0xa8))
default=dict(startArea=100,start=[12,14],goal=[28,29],route=[1,1,2,1,2,2],exits=[10,5,5,10,0,0],complete=0,resume=0,old=[],avoidTiles=[],avoidExits=[],budget=100,tickStep=10,results=[2],generate=[1])
rows=[run(default|dict(resume=resume,old=old,budget=budget,results=results,generate=generate)) for resume,old,budget,results,generate in itertools.product([0,1],[[],[12,14,14,15]],[0,10,25,100],[[2],[1],[3,2],[2,1],[2,3,2]],[[1],[1,0]])]
rows += [run(default|dict(startArea=200)),run(default|dict(goal=[-1,2])),run(default|dict(complete=1)),run(default|dict(generate=[0])),run(default|dict(resume=1,avoidTiles=[0,0],avoidExits=[12,1],results=[3,2]))]
out=m.root/'backups/animations/native-area-plot-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2));print(json.dumps(dict(output=str(out),rows=len(rows))))
