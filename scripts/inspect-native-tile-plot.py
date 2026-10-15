"""Read-only CNWSTile::PlotIntraTilePath1404fe1b0. Original local/world
rotations execute unchanged. The surface coordinator is a captured boundary;
verify goal/exit restoration, appended-only rotation and far-NPC optimisation.
"""
import importlib.util,itertools,json,re
from pathlib import Path
spec=importlib.util.spec_from_file_location('coordinator',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle);q,si,wi,wq,wf,rf,xmm,finish=[getattr(m,n) for n in ['q','si','wi','wq','wf','rf','xmm','finish']]
tile,area,path,info,mesh,actor,exits,waypoints=[m.heap+n*0x1000 for n in range(8)];ranges=[]
for file in ['live-native-intratile-coordinators-full-asm.txt','live-native-path-getter-rotation-asm.txt','live-native-tile-coordinate-owner-asm.txt']:
    for line in (m.root/'backups/animations'/file).read_text().splitlines():
        if line.startswith('FUNCTION REQUESTED'):ranges.extend((int(a,16),int(b,16)) for a,b in re.findall(r'([0-9a-f]+):([0-9a-f]+)',line))
def hook(u,a,n,_):
    if a==m.stop:u.emu_stop();return
    x,y,z,w=[u.reg_read(reg) for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
    if a==0x1402c55a0:wi(y,c['tile'][0]);wi(z,c['tile'][1]);finish()
    elif a==0x14055b3d0:calls.append(['creature',y]);finish(actor)
    elif a==0x1403d54d0:calls.append(['possessed']);finish(c['possessed'])
    elif a==0x1402c3830:
        count=si(path+0xe0);calls.append(['surface',[rf(rsp+0x28),rf(rsp+0x30)],[rf(rsp+0x38),rf(rsp+0x40)],si(rsp+0x48),si(rsp+0x50),[rf(path+0x4c),rf(path+0x50)],[rf(exits+n*4) for n in range(max(0,count-1)*2)]])
        for n,v in enumerate(c['append']):wf(waypoints+(len(c['old'])+n)*4,v)
        wi(path+0x88,len(c['old'])+len(c['append']));finish(c['result'])
    elif not any(lo<=a<hi for lo,hi in ranges):raise RuntimeError(f'Unmapped tile plot dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
    global c,calls
    c=case;calls=[];u.mem_write(m.heap,bytes(0x100000));wq(0x1412df970,m.heap+0x9000);wq(tile+0x30,info if c['loaded'] else 0);wq(info+8,mesh);wi(tile+0x1c,c['tile'][0]);wi(tile+0x20,c['tile'][1]);wi(tile+0x24,c['orientation']);wi(actor+0x89c,c['pc'])
    wi(path+0x24,77);wi(path+0xe0,c['tileCount']);wq(path+0xf0,exits);wq(path+0x90,waypoints);wi(path+0x88,len(c['old']))
    for off,v in zip([0x4c,0x50,0x64,0x68],c['goal']+c['originalStart']):wf(path+off,v)
    for n,v in enumerate(c['exits']):wf(exits+n*4,v)
    for n,v in enumerate(c['old']):wf(waypoints+n*4,v)
    rsp=m.stack+0x1fe08;u.mem_write(rsp-0x100,bytes(0x200));wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
    for reg,v in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8],[tile,area,path]):u.reg_write(reg,v)
    u.reg_write(UC_X86_REG_XMM3,int.from_bytes(m.struct.pack('<f',c['start'][0]),'little'))
    for n,v in enumerate([c['start'][1]]+c['end']):wf(rsp+0x28+n*8,v)
    wi(rsp+0x40,12000)
    try:u.emu_start(0x1404fe1b0,m.stop,count=50000)
    except Exception:print(json.dumps(dict(case=c,rip=hex(u.reg_read(UC_X86_REG_RIP)),calls=calls)));raise
    return dict(case=c,result=u.reg_read(UC_X86_REG_RAX)&0xffffffff,calls=calls,goal=[rf(path+0x4c),rf(path+0x50)],exits=[rf(exits+n*4) for n in range(len(c['exits']))],waypoints=[rf(waypoints+n*4) for n in range(si(path+0x88))])
default=dict(tile=[7,10],orientation=0,tileCount=1,goal=[78,109],originalStart=[72,104],start=[2,4],end=[8,9],exits=[10,5,5,0,5,10],old=[72,104],append=[72,104,74,105,78,109],loaded=1,pc=1,possessed=0,result=2)
rows=[run(default|dict(orientation=o,tileCount=count,originalStart=start,pc=pc,possessed=possessed,old=old,append=append)) for o,count,start,pc,possessed,old,append in itertools.product(range(4),[1,2,4],[[72,104],[45,105],[60,105]],[0,1],[0,1],[[],[72,104]],[[],[72,104,74,105,78,109]])]
rows += [run(default|dict(loaded=0))]
out=m.root/'backups/animations/native-tile-plot-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2));print(json.dumps(dict(output=str(out),rows=len(rows))))
