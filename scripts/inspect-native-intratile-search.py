"""Read-only IntraTileDFS1402bf970 core. Triangle successor generation and
correctly rounded FLOAT sqrt are captured. Native saved-alternative owners
execute unchanged with captured allocations/free; compares hash/route/budget,
goal/stop bounds and resume state, not triangle/area collision providers.
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
u.mem_map(heap,0x80000);u.mem_map(stack,0x20000);u.mem_map(stop,0x1000)
surface,tile,area,path,route,triangles,cache,oldNodes,oldStarts,oldCounts=[heap+n*0x1000 for n in range(10)]
ranges=[(0x1402bf970,0x1402bfebe)]
for file in ['live-native-path-alternatives-full-asm.txt','live-native-path-alternatives-leaf-asm.txt']:
    for line in (root/'backups/animations'/file).read_text().splitlines():
        if line.startswith('FUNCTION REQUESTED'):ranges.extend((int(a,16),int(b,16)) for a,b in re.findall(r'([0-9a-f]+):([0-9a-f]+)',line))
def q(a):return int.from_bytes(u.mem_read(a,8),'little')
def i(a):return int.from_bytes(u.mem_read(a,4),'little')
def si(a):return struct.unpack('<i',u.mem_read(a,4))[0]
def wi(a,v):u.mem_write(a,struct.pack('<I',v&0xffffffff))
def wq(a,v):u.mem_write(a,struct.pack('<Q',v))
def wf(a,v):u.mem_write(a,struct.pack('<f',v))
def rf(a):return struct.unpack('<f',u.mem_read(a,4))[0]
def xmm(reg):return struct.unpack('<f',struct.pack('<I',u.reg_read(reg)&0xffffffff))[0]
def write_nodes(ptr,rows):
    for n,row in enumerate(rows):
        for off,value in zip([0,4,8,12,16],row['via']+row['point']+[row['cost']]):wf(ptr+n*24+off,value)
        wi(ptr+n*24+20,row['triangle'])
def finish(v=0):
    rsp=u.reg_read(UC_X86_REG_RSP);u.reg_write(UC_X86_REG_RIP,q(rsp));u.reg_write(UC_X86_REG_RSP,rsp+8);u.reg_write(UC_X86_REG_RAX,v&0xffffffffffffffff)
def hook(u,a,n,_):
    global allocation
    if a==stop:u.emu_stop();return
    x,y,z,w=[u.reg_read(reg) for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
    if a==0x140c7d6d8:
        u.reg_write(UC_X86_REG_XMM0,int.from_bytes(struct.pack('<f',math.sqrt(xmm(UC_X86_REG_XMM0))),'little'));finish()
    elif a==0x1402bfec0:
        code=si(rsp+0x38);depth=i(surface+0x150)//2;rows=c['graph'].get(str(code),[]);ptr=heap+0x30000+depth*0x1000
        calls.append(['successors',rf(rsp+0x28),rf(rsp+0x30),code]);wi(surface+0x170,i(surface+0x170)+300);write_nodes(ptr,rows);wq(q(rsp+0x48),ptr);node_rows[ptr]=rows;finish(len(rows))
    elif a==0x140c10368:
        ptr=heap+0x60000+allocation*0x1000;allocation+=1;u.mem_write(ptr,bytes([0xa5])*0x1000);finish(ptr)
    elif a==0x140c10370:
        if x in node_rows:calls.append(['dispose',node_rows[x]])
        finish()
    elif not any(lo<=a<hi for lo,hi in ranges):raise RuntimeError(f'Unmapped intra-tile dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
    global c,calls,allocation,node_rows
    c=case;calls=[];allocation=0;node_rows={};u.mem_write(heap,bytes(0x80000));wq(surface+0x78,triangles);wq(surface+0x158,route);wq(surface+0x168,triangles);wq(surface+0x180,cache)
    for off,value in zip([0x130,0x13c],c['goal']):wf(surface+off,value)
    for off,value in zip([0x134,0x138,0x140,0x144],c['bounds']):wf(surface+off,value)
    wf(surface+0x14c,c['limit']);wf(surface+0x178,99);wi(surface+0x170,c['work']);wi(surface+0x174,c['workLimit']);wf(path+0x58,c['stop']);wi(path+0x100,c['saved']);wi(path+0x104,c['oldCount'])
    for n in range(128):wi(cache+n*16,-1);wi(cache+n*16+4,-1);wf(cache+n*16+8,-1);wf(cache+n*16+12,-1)
    for seed in c['cache']:
        ptr=cache+seed['index']*16
        for n,v in enumerate(seed['keys']):wi(ptr+n*4,v)
        for n,v in enumerate(seed['budgets']):wf(ptr+8+n*4,v)
    if c['oldCount']:
        wq(path+0x118,oldNodes);wq(path+0x108,oldStarts);wq(path+0x110,oldCounts)
        for n in range(c['oldCount']):
            ptr=heap+0x50000+n*0x100;rows=c['graph'].get(str(n),[]);write_nodes(ptr,rows);node_rows[ptr]=rows;wq(oldNodes+n*8,ptr);wi(oldStarts+n*4,c['savedStart']);wi(oldCounts+n*4,len(rows))
    rsp=stack+0x1ff08;u.mem_write(rsp-0x100,bytes(0x180));wq(rsp,stop);u.reg_write(UC_X86_REG_RSP,rsp)
    for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],[surface,tile,area,path]):u.reg_write(reg,value)
    wi(rsp+0x28,c['depth']);wf(rsp+0x30,c['cost']);wi(rsp+0x38,c['triangle']);wf(rsp+0x40,c['point'][0]);wf(rsp+0x48,c['point'][1]);wf(rsp+0x50,0);wf(rsp+0x58,0);wf(rsp+0x60,.6);wi(rsp+0x68,0)
    try:u.emu_start(0x1402bf970,stop,count=50000)
    except Exception:print(json.dumps(dict(case=c,rip=hex(u.reg_read(UC_X86_REG_RIP)),calls=calls)));raise
    assert u.reg_read(UC_X86_REG_RIP)==stop;count=si(path+0x104);nodes=q(path+0x118);starts=q(path+0x108);sizes=q(path+0x110)
    alternatives=[]
    if nodes:
        for n in range(max(0,count)):
            pointer=q(nodes+n*8);alternatives.append(dict(start=si(starts+n*4),count=si(sizes+n*4),nodes=node_rows.get(pointer) if pointer else None))
    return dict(case=c,result=u.reg_read(UC_X86_REG_RAX)&0xffffffff,calls=calls,work=si(surface+0x170),routeCount=si(surface+0x150),route=[rf(route+n*4) for n in range(24)],triangles=[si(triangles+n*4) for n in range(6)],bestMiss=rf(surface+0x178),cache=[dict(keys=[si(cache+n*16),si(cache+n*16+4)],budgets=[rf(cache+n*16+8),rf(cache+n*16+12)]) for n in range(128)],alternativeCount=count,alternatives=alternatives)
candidate=lambda x,y,tri,cost=1:dict(via=[x,y],point=[x,y],triangle=tri,cost=cost)
graphs=[{}, {'0':[candidate(5,5,1)]},{'0':[candidate(2,2,128),candidate(5,5,1)],'128':[candidate(5,5,2)]},{'0':[candidate(2,2,1)],'1':[candidate(0,0,0)]}]
default=dict(depth=0,cost=0,triangle=0,point=[0,0],goal=[5,5],bounds=[4.9999,5.0001,4.9999,5.0001],limit=12,work=0,workLimit=500,stop=0,graph=graphs[1],cache=[],oldCount=0,saved=0,savedStart=0)
rows=[run(default|dict(point=point,limit=limit,workLimit=work,graph=graph,oldCount=count,saved=saved)) for point,limit,work,graph,count,saved in itertools.product([[0,0],[5,5],[5.5,5]],[3,12],[0,350,1000],graphs,[0,1],[0,1])]
rows += [run(default|dict(depth=depth,point=point,stop=stop,cache=cache)) for depth,point,stop,cache in itertools.product([0,1],[[5.5,5],[0,0]],[.01,.6],[[],[dict(index=0,keys=[0,-1],budgets=[15,-1])],[dict(index=0,keys=[128,0],budgets=[15,15])]])]
out=root/'backups/animations/native-intratile-search-observations.json';out.write_text(json.dumps(dict(binarySha256=digest,limits=__doc__,rows=rows),indent=2));print(json.dumps(dict(output=str(out),rows=len(rows))))
