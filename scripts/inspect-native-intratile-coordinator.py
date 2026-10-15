"""Read-only PlotIntraTilePath1402c3830 coordinator. Physical base-face scans,
distance estimate, timer arithmetic, retry/ownership and waypoint append execute
unchanged. Already independently verified subdivision/search are captured helper
boundaries here; synthetic DFS responses do not prove full area path parity.
"""
from pathlib import Path
import sys,struct,hashlib,json,itertools,re,math
root=Path(__file__).resolve().parents[1];sys.path.insert(0,str(root/'backups/research-python'))
import pefile
from unicorn import Uc,UC_ARCH_X86,UC_MODE_64,UC_HOOK_CODE
from unicorn.x86_const import *
data=(root.parent/'FullDecomp/NwnRootInstall/bin/win32/nwmain.exe').read_bytes();digest=hashlib.sha256(data).hexdigest();assert digest=='3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a'
pe=pefile.PE(data=data);base=pe.OPTIONAL_HEADER.ImageBase
u=Uc(UC_ARCH_X86,UC_MODE_64);u.mem_map(base,(pe.OPTIONAL_HEADER.SizeOfImage+4095)&~4095);u.mem_write(base,pe.get_memory_mapped_image())
heap,stack,stop=0x200000000,0x300000000,0x400000000
u.mem_map(heap,0x100000);u.mem_map(stack,0x20000);u.mem_map(stop,0x1000)
surface,tile,area,path,vertices,faces,oldWaypoints,oldCache=[heap+n*0x1000 for n in range(8)]
ranges=[(0x1402c3830,0x1402c41e2),(0x1402bcc90,0x1402bcd41)]
def q(a):return int.from_bytes(u.mem_read(a,8),'little')
def si(a):return struct.unpack('<i',u.mem_read(a,4))[0]
def wi(a,v):u.mem_write(a,struct.pack('<I',v&0xffffffff))
def wq(a,v):u.mem_write(a,struct.pack('<Q',v))
def wf(a,v):u.mem_write(a,struct.pack('<f',v))
def rf(a):return struct.unpack('<f',u.mem_read(a,4))[0]
def xmm(reg):return struct.unpack('<f',struct.pack('<I',u.reg_read(reg)&0xffffffff))[0]
def finish(v=0):
    rsp=u.reg_read(UC_X86_REG_RSP);u.reg_write(UC_X86_REG_RIP,q(rsp));u.reg_write(UC_X86_REG_RSP,rsp+8);u.reg_write(UC_X86_REG_RAX,v&0xffffffffffffffff)
def hook(u,a,n,_):
    global allocation,ticks,steps
    if a==stop:u.emu_stop();return
    x,y,z,w=[u.reg_read(reg) for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
    if a==0x14016dd30:finish(c['timers'][min(ticks,1)]);ticks+=1
    elif a==0x1402c55a0:
        wi(y,c['tile'][0]);wi(z,c['tile'][1]);finish()
    elif a==0x1402c4e00:finish()
    elif a==0x1402bd610:
        point=[xmm(UC_X86_REG_XMM3),rf(rsp+0x28)];calls.append(['triangle',y,z,point,si(rsp+0x30)]);finish(c['triangle'])
    elif a==0x1402bd950:
        calls.append(['exit',rf(rsp+0x28),rf(rsp+0x30)])
        for off,v in zip([0x130,0x13c,0x134,0x138,0x140,0x144],c['exitGoal']+c['exitBounds']):wf(surface+off,v)
        wi(surface+0x148,c['triangle']);finish(c['exitResult'])
    elif a==0x140c7d6d8:
        u.reg_write(UC_X86_REG_XMM0,int.from_bytes(struct.pack('<f',math.sqrt(xmm(UC_X86_REG_XMM0))),'little'));finish()
    elif a==0x1402bf970:
        calls.append(['dfs',rf(surface+0x14c),si(surface+0x170),si(surface+0x174),si(rsp+0x28),rf(rsp+0x30),si(rsp+0x38),rf(rsp+0x40),rf(rsp+0x48),rf(rsp+0x50),rf(rsp+0x58),rf(rsp+0x60),si(rsp+0x68)])
        response=c['responses'][min(steps,len(c['responses'])-1)];steps+=1
        wi(surface+0x170,si(surface+0x170)+response['work']);wi(surface+0x150,len(response['route'])//2-1)
        for n,v in enumerate(response['route']):wf(q(surface+0x158)+n*4,v)
        finish(response['result'])
    elif a==0x140294090:
        calls.append(['deleteAlternatives']);wi(path+0x104,0);wq(path+0x118,0);finish()
    elif a==0x1402ba7a0:
        wi(x,-1);wi(x+4,-1);wf(x+8,-1);wf(x+12,-1);finish(x)
    elif a==0x140c10368:
        ptr=heap+0x10000+allocation*0x10000;allocation+=1;names[ptr]=f'new{allocation}';calls.append(['allocate',x]);u.mem_write(ptr,bytes([0xa5])*min(x,0x10000));finish(ptr)
    elif a==0x140c10370:calls.append(['free',names.get(x,'null' if x==0 else hex(x))]);finish()
    elif not any(lo<=a<hi for lo,hi in ranges):raise RuntimeError(f'Unmapped coordinator dependency {a:x}')
hook_handle=u.hook_add(UC_HOOK_CODE,hook)
def run(case):
    global c,calls,allocation,ticks,steps,names
    c=case;calls=[];allocation=ticks=steps=0;names={oldWaypoints:'oldWaypoints',oldCache:'oldCache'};u.mem_write(heap,bytes(0x100000))
    # g_pExoBase address is taken from the coordinator's RIP-relative timer load.
    wq(0x1412df8b8,heap+0x9000)
    wq(surface+0x78,faces);wq(surface+0xd0,vertices);wi(surface+0x64,2);wi(surface+0x70,128)
    for n,point in enumerate([[0,0,0],[10,0,0],[10,10,0],[0,10,0]]):
        for axis,v in enumerate(point):wf(vertices+n*12+axis*4,v)
    for n,indices in enumerate([[0,1,2],[0,2,3]]):
        for axis,v in enumerate(indices):wi(faces+n*12+axis*4,v)
    for off,v in zip([0x4c,0x50],c['goal']):wf(path+off,v)
    wi(path+0xe0,c['tileCount']);wi(path+0xf8,c['resume']);wf(path+0xfc,c['bound']);wq(path+0x120,oldCache if c['resume'] else 0);wf(path+4,.6)
    wi(path+0x88,len(c['old']));wq(path+0x90,oldWaypoints if c['old'] else 0)
    for n,v in enumerate(c['old']):wf(oldWaypoints+n*4,v)
    rsp=stack+0x1fe08;u.mem_write(rsp-0x100,bytes(0x200));wq(rsp,stop);u.reg_write(UC_X86_REG_RSP,rsp)
    for reg,v in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],[surface,tile,area,path]):u.reg_write(reg,v)
    for n,v in enumerate(c['start']+c['end']):wf(rsp+0x28+n*8,v)
    wi(rsp+0x48,c['budget']);wi(rsp+0x50,c['optimisation'])
    try:u.emu_start(0x1402c3830,stop,count=50000)
    except Exception:print(json.dumps(dict(case=c,rip=hex(u.reg_read(UC_X86_REG_RIP)),calls=calls)));raise
    assert u.reg_read(UC_X86_REG_RIP)==stop
    count=si(path+0x88);ptr=q(path+0x90)
    return dict(case=c,result=u.reg_read(UC_X86_REG_RAX)&0xffffffff,calls=calls,resume=si(path+0xf8),bound=rf(path+0xfc),saved=si(path+0x100),cache=names.get(q(path+0x120)),waypoints=[rf(ptr+n*4) for n in range(count)] if ptr else [],goal=[rf(surface+0x130),rf(surface+0x13c)],bounds=[rf(surface+off) for off in [0x134,0x138,0x140,0x144]],target=si(surface+0x148))
response=lambda result,work=12:dict(result=result,work=work,route=[1,1,3,3,5,5])
default=dict(tile=[7,10],tileCount=1,goal=[75,105],start=[1,1],end=[5,5],triangle=7,exitGoal=[10,5],exitBounds=[9.9999,10.0001,4.9,5.1],exitResult=1,timers=[1000,1050],budget=1000,optimisation=0,resume=0,bound=16,old=[],responses=[response(2)])
if __name__=='__main__':
    rows=[run(default|dict(tileCount=tiles,start=start,resume=resume,budget=budget,old=old,responses=responses)) for tiles,start,resume,budget,old,responses in itertools.product([1,3],[[1,1],[-1,-1]],[0,1],[0,500,1000],[[],[70,100],[70,100,71,101,72,102]],[[response(2)],[response(1,600)],[response(3,600)],[response(3),response(2)],[response(3)]])]
    rows += [run(default|dict(triangle=-1)),run(default|dict(tileCount=3,exitResult=0)),run(default|dict(timers=[0xffffffff,0],budget=600)),run(default|dict(resume=1,bound=40,responses=[response(3)]))]
    out=root/'backups/animations/native-intratile-coordinator-observations.json';out.write_text(json.dumps(dict(binarySha256=digest,limits=__doc__,rows=rows),indent=2));print(json.dumps(dict(output=str(out),rows=len(rows))))
