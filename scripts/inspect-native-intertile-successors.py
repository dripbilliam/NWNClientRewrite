"""Read-only InterTileDFSGenerateSuccessors14036d560. Region centres, exits,
entrance queries and correctly rounded sqrt FLOAT are captured dependencies.
The full area-segment intersection body executes unchanged. Compares physical
exclusion/order/score outputs, not walkmesh/door path-node getter parity.
"""
from pathlib import Path
import sys,struct,hashlib,json,itertools,math
root=Path(__file__).resolve().parents[1];sys.path.insert(0,str(root/'backups/research-python'))
import pefile
from unicorn import Uc,UC_ARCH_X86,UC_MODE_64,UC_HOOK_CODE
from unicorn.x86_const import *
data=(root.parent/'FullDecomp/NwnRootInstall/bin/win32/nwmain.exe').read_bytes();digest=hashlib.sha256(data).hexdigest();assert digest=='3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a'
pe=pefile.PE(data=data);base=pe.OPTIONAL_HEADER.ImageBase
u=Uc(UC_ARCH_X86,UC_MODE_64);u.mem_map(base,(pe.OPTIONAL_HEADER.SizeOfImage+4095)&~4095);u.mem_write(base,pe.get_memory_mapped_image())
heap,stack,stop=0x200000000,0x300000000,0x400000000
u.mem_map(heap,0x80000);u.mem_map(stack,0x20000);u.mem_map(stop,0x1000)
area,path,tiles,points,successors,scratch,avoidTiles,avoidExits,tileStorage=[heap+n*0x5000 for n in range(9)]
def i(a):return int.from_bytes(u.mem_read(a,4),'little')
def si(a):return struct.unpack('<i',u.mem_read(a,4))[0]
def q(a):return int.from_bytes(u.mem_read(a,8),'little')
def wi(a,v):u.mem_write(a,struct.pack('<I',v&0xffffffff))
def wq(a,v):u.mem_write(a,struct.pack('<Q',v))
def wf(a,v):u.mem_write(a,struct.pack('<f',v))
def rf(a):return struct.unpack('<f',u.mem_read(a,4))[0]
def xmm(reg):return struct.unpack('<f',struct.pack('<I',u.reg_read(reg)&0xffffffff))[0]
def xy(ptr):n=(ptr-tileStorage)//0x68;return[n%c['width'],n//c['width']]
def finish(v=0):
    rsp=u.reg_read(UC_X86_REG_RSP);u.reg_write(UC_X86_REG_RIP,q(rsp));u.reg_write(UC_X86_REG_RSP,rsp+8);u.reg_write(UC_X86_REG_RAX,v&0xffffffffffffffff)
def hook(u,a,n,_):
    if a==stop:u.emu_stop();return
    x,y,z,w=[u.reg_read(reg) for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
    if a==0x1404fdb90:calls.append(['centre',*xy(x),y&0xffffffff]);wf(z,c['centre'][0]);wf(w,c['centre'][1]);finish(1)
    elif a==0x1404fdd30:calls.append(['total',*xy(x)]);finish(len(c['exits']))
    elif a==0x1404fdaa0:
        index=y&0xffffffff;calls.append(['exit',*xy(x),index]);row=c['exits'][index];wf(z,row['point'][0]);wf(w,row['point'][1]);wi(q(rsp+0x28),row['region']);finish(1)
    elif a==0x1404fdc30:calls.append(['entrance',*xy(x),xmm(UC_X86_REG_XMM1),xmm(UC_X86_REG_XMM2)]);finish(c['enter'])
    elif a==0x140c7d6d8:
        value=xmm(UC_X86_REG_XMM0);u.reg_write(UC_X86_REG_XMM0,int.from_bytes(struct.pack('<f',math.sqrt(value)),'little'));finish()
    elif not (0x14036d560<=a<0x14036e25f or 0x140297860<=a<0x140297bbf):raise RuntimeError(f'Unmapped successor dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
    global c,calls
    c=case;calls=[];u.mem_write(heap,bytes(0x80000));wq(area+0x280,path);wi(area+0xc,c['width']);wi(area+0x10,c['height']);wq(area+0x1c8,tileStorage);wq(area+0x2c8,successors);wq(area+0x2d0,scratch)
    for off,value in zip([0x26c,0x270,0x274],c['goal']):wi(area+off,value)
    wf(area+0x278,c['goalPoint'][0]);wf(area+0x27c,c['goalPoint'][1]);wq(path+0xe8,tiles);wq(path+0xf0,points);wq(path+0xd0,avoidTiles);wq(path+0xd8,avoidExits);wi(path+0xcc,len(c['avoid']))
    wi(tiles,c['previous'][0]);wi(tiles+4,c['previous'][1]);wf(points,c['previous'][2]);wf(points+4,c['previous'][3])
    for n,row in enumerate(c['avoid']):
        for off,value in zip([0,4],row['tile']):wi(avoidTiles+n*8+off,value)
        for off,value in zip([0,4],row['exits']):wi(avoidExits+n*8+off,value)
    rsp=stack+0x1ff08;u.mem_write(rsp-0x300,bytes(0x380));wq(rsp,stop);u.reg_write(UC_X86_REG_RSP,rsp);wi(rsp+0x28,c['start'][2])
    for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],[area,c['depth'],*c['start'][:2]]):u.reg_write(reg,value&0xffffffffffffffff)
    try:u.emu_start(0x14036d560,stop,count=50000)
    except Exception:print(json.dumps(dict(case=c,rip=hex(u.reg_read(UC_X86_REG_RIP)),calls=calls)));raise
    assert u.reg_read(UC_X86_REG_RIP)==stop;count=u.reg_read(UC_X86_REG_RAX)&0xffffffff;offset=c['depth']*8*24
    rows=[]
    for n in range(count):
        ptr=successors+offset+n*24;rows.append(dict(tile=[si(ptr),si(ptr+4)],region=si(ptr+8),exit=[rf(ptr+12),rf(ptr+16)],score=rf(ptr+20)))
    return dict(case=c,calls=calls,rows=rows,cache=[si(scratch+n*4) for n in range(13)])
edge=lambda x,y,r=0:dict(point=[x,y],region=r)
exits=[edge(5,0),edge(10,5),edge(5,10),edge(0,5)]
default=dict(width=3,height=3,start=[1,1,0],goal=[2,2,0],goalPoint=[25,25],centre=[5,5],depth=0,previous=[1,0,5,10],enter=0,exits=exits,avoid=[])
rows=[run(default|dict(goalPoint=goal,centre=centre,depth=depth,enter=enter,exits=exits,avoid=avoid,start=start)) for goal,centre,depth,enter,exits,avoid,start in itertools.product([[25,25],[15,15],[5,15],[15,5],[30,20],[19.99,15.01]],[[5,5],[.0001,.0001]],[0,1],[0,-1],[exits,[*exits,edge(10,5),edge(5,10)],[edge(5,5),edge(10,5,1),edge(10,10)],list(reversed(exits))],[[],[dict(tile=[1,1],exits=[0,2])],[dict(tile=[1,1],exits=[0,12])] ],[[1,1,0],[0,0,0]])]
out=root/'backups/animations/native-intertile-successor-observations.json';out.write_text(json.dumps(dict(binarySha256=digest,limits=__doc__,rows=rows),indent=2));print(json.dumps(dict(output=str(out),rows=len(rows))))
