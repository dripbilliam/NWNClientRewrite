"""Read-only GenerateInterTilePath/InterTileDFS owners. Successor geometry,
tile exits, allocations and frees are explicit captured helpers. Real search
instructions determine iterative depth, region BYTE pruning, route writes,
avoidance and success. Does not prove tile/door successors or intra-tile routing.
"""
from pathlib import Path
import sys,struct,hashlib,json,itertools
root=Path(__file__).resolve().parents[1];sys.path.insert(0,str(root/'backups/research-python'))
import pefile
from unicorn import Uc,UC_ARCH_X86,UC_MODE_64,UC_HOOK_CODE
from unicorn.x86_const import *
data=(root.parent/'FullDecomp/NwnRootInstall/bin/win32/nwmain.exe').read_bytes();digest=hashlib.sha256(data).hexdigest();assert digest=='3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a'
pe=pefile.PE(data=data);base=pe.OPTIONAL_HEADER.ImageBase
u=Uc(UC_ARCH_X86,UC_MODE_64);u.mem_map(base,(pe.OPTIONAL_HEADER.SizeOfImage+4095)&~4095);u.mem_write(base,pe.get_memory_mapped_image())
heap,stack,stop=0x200000000,0x300000000,0x400000000
u.mem_map(heap,0x80000);u.mem_map(stack,0x20000);u.mem_map(stop,0x1000)
area,path,tiles,points,visited,successors,scratch,threshold,avoidTiles,avoidExits=[heap+n*0x5000 for n in range(10)]
def i(a):return int.from_bytes(u.mem_read(a,4),'little')
def si(a):return struct.unpack('<i',u.mem_read(a,4))[0]
def q(a):return int.from_bytes(u.mem_read(a,8),'little')
def wi(a,v):u.mem_write(a,struct.pack('<I',v&0xffffffff))
def wq(a,v):u.mem_write(a,struct.pack('<Q',v))
def wf(a,v):u.mem_write(a,struct.pack('<f',v))
def rf(a):return struct.unpack('<f',u.mem_read(a,4))[0]
def xmm(reg):return struct.unpack('<f',struct.pack('<I',u.reg_read(reg)&0xffffffff))[0]
def finish(v=0):
    rsp=u.reg_read(UC_X86_REG_RSP);u.reg_write(UC_X86_REG_RIP,q(rsp));u.reg_write(UC_X86_REG_RSP,rsp+8);u.reg_write(UC_X86_REG_RAX,v&0xffffffffffffffff)
def hook(u,a,n,_):
    if a==stop:u.emu_stop();return
    x,y,z,w=[u.reg_read(reg) for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
    if a==0x140c10368:
        pointer=[visited,successors,scratch][len(allocations)];allocations.append(x);finish(pointer)
    elif a==0x140c42060:u.mem_write(x,bytes(z));finish(x)
    elif a==0x140c10370:finish()
    elif a==0x14036d560:
        depth=y&0xffffffff;key=f'{z&0xffffffff},{w&0xffffffff},{i(rsp+0x28)}';rows=c['graph'].get(key,[]);calls.append(['successors',depth,key])
        for n,row in enumerate(rows):
            ptr=successors+(depth*8+n)*24
            for off,v in zip([0,4,8],row['tile']+[row['region']]):wi(ptr+off,v)
            wf(ptr+12,row['exit'][0]);wf(ptr+16,row['exit'][1])
        finish(len(rows))
    elif a==0x1404fdb30:calls.append(['exit',xmm(UC_X86_REG_XMM1),xmm(UC_X86_REG_XMM2)]);finish(c['exitNumber'])
    elif not (0x14036bc90<=a<0x14036be09 or 0x14036cba0<=a<0x14036ce5b):raise RuntimeError(f'Unmapped inter-tile dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
    global c,calls,allocations
    c=case;calls=[];allocations=[];u.mem_write(heap,bytes(0x80000));wq(area+0x280,path);wi(area+0xc,4);wi(area+0x10,4);wq(area+0x1c8,heap+0x70000)
    for off,value in zip([0x26c,0x270,0x274],c['goal']):wi(area+off,value)
    for off,value in [(0x260,visited),(0x2c8,successors),(0x2d0,scratch)]:wq(area+off,value)
    wq(path+0xe8,tiles);wq(path+0xf0,points);wq(path+0xd0,avoidTiles);wq(path+0xd8,avoidExits);wi(path+0xcc,len(c['avoid']))
    for n,row in enumerate(c['avoid']):
        for off,value in zip([0,4],row['tile']):wi(avoidTiles+n*8+off,value)
        for off,value in zip([0,4],row['exits']):wi(avoidExits+n*8+off,value)
    if c['depth']>0:wi(tiles,c['previous'][0]);wi(tiles+4,c['previous'][1]);wf(points,c['previous'][2]);wf(points+4,c['previous'][3])
    wi(threshold,c['budget']);u.mem_write(visited+c['visitIndex'],bytes([c['visitValue']]))
    rsp=stack+0x1ff08;u.mem_write(rsp-0x200,bytes(0x280));wq(rsp,stop);u.reg_write(UC_X86_REG_RSP,rsp)
    if c['mode']=='generate':entry=0x14036bc90;args=[area,threshold,*c['start'][:2]];wi(rsp+0x28,c['start'][2])
    else:entry=0x14036cba0;args=[area,c['depth'],c['budget'],c['start'][0]];wi(rsp+0x28,c['start'][1]);wi(rsp+0x30,c['start'][2])
    for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],args):u.reg_write(reg,value&0xffffffffffffffff)
    try:u.emu_start(entry,stop,count=50000)
    except Exception:print(json.dumps(dict(case=c,rip=hex(u.reg_read(UC_X86_REG_RIP)),calls=calls)));raise
    assert u.reg_read(UC_X86_REG_RIP)==stop;count=i(path+0xe0)
    return dict(case=c,result=u.reg_read(UC_X86_REG_RAX)&0xffffffff,calls=calls,count=count,threshold=si(threshold),tiles=[si(tiles+n*4) for n in range(12)],points=[rf(points+n*4) for n in range(12)],visited=list(u.mem_read(visited,32*32*6)),temporary=[q(area+off)!=0 for off in [0x260,0x2c8,0x2d0]])
edge=lambda x,y,r=0:dict(tile=[x,y],region=r,exit=[1.25,9.5])
graphs=[{}, {'0,0,0':[edge(1,0)],'1,0,0':[edge(1,1)]},{'0,0,0':[edge(0,1),edge(1,0)],'0,1,0':[edge(0,0)],'1,0,0':[edge(1,1)]}]
default=dict(mode='dfs',depth=0,budget=2,start=[0,0,0],goal=[1,1,0],previous=[0,0,1.25,9.5],graph=graphs[1],avoid=[],exitNumber=2,visitIndex=0,visitValue=0)
rows=[run(default|dict(mode=mode,budget=budget,graph=graph,goal=goal,visitValue=value,avoid=avoid)) for mode,budget,graph,goal,value,avoid in itertools.product(['dfs','generate'],[0,1,2,4,7],graphs,[[0,0,0],[1,1,0],[1,1,1]],[0,2],[[],[dict(tile=[1,1],exits=[2,12])]])]
rows += [run(default|dict(depth=1,start=[1,1,0],previous=previous,exitNumber=exitNumber,avoid=avoid)) for previous,exitNumber,avoid in itertools.product([[0,0,1.25,9.5],[1,0,.1,2.75]],[2,3],[[],[dict(tile=[1,1],exits=[2,12])]])]
out=root/'backups/animations/native-intertile-search-observations.json';out.write_text(json.dumps(dict(binarySha256=digest,limits=__doc__,rows=rows),indent=2));print(json.dumps(dict(output=str(out),rows=len(rows))))
