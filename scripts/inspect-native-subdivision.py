"""Read-only original RunSubdivision twice, FindTriangle and triangle getters.
No geometry helper is replaced: all arithmetic, child/adjacency order and
encoded search instructions execute unchanged. Loaded storage is synthetic;
allocation/load failure, negative indexing and undefined output are excluded.
"""
from pathlib import Path
import sys,struct,hashlib,json,re
root=Path(__file__).resolve().parents[1];sys.path.insert(0,str(root/'backups/research-python'))
import pefile
from unicorn import Uc,UC_ARCH_X86,UC_MODE_64,UC_HOOK_CODE
from unicorn.x86_const import *
data=(root.parent/'FullDecomp/NwnRootInstall/bin/win32/nwmain.exe').read_bytes();digest=hashlib.sha256(data).hexdigest();assert digest=='3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a'
pe=pefile.PE(data=data);base=pe.OPTIONAL_HEADER.ImageBase
u=Uc(UC_ARCH_X86,UC_MODE_64);u.mem_map(base,(pe.OPTIONAL_HEADER.SizeOfImage+4095)&~4095);u.mem_write(base,pe.get_memory_mapped_image())
heap,stack,stop=0x200000000,0x300000000,0x400000000
u.mem_map(heap,0x60000);u.mem_map(stack,0x10000);u.mem_map(stop,0x1000)
surface,output=heap,heap+0x1000
levels=[dict(vertices=heap+0x10000+n*0x10000,faces=heap+0x12000+n*0x10000,adjacency=heap+0x14000+n*0x10000) for n in range(3)]
ranges=[]
for file in ['live-native-subdivision-full-asm.txt','live-native-subdivision-getters-leaf-asm.txt']:
    for line in (root/'backups/animations'/file).read_text().splitlines():
        if line.startswith('FUNCTION REQUESTED'):ranges.extend((int(a,16),int(b,16)) for a,b in re.findall(r'([0-9a-f]+):([0-9a-f]+)',line))
def wi(a,v):u.mem_write(a,struct.pack('<I',v&0xffffffff))
def wq(a,v):u.mem_write(a,struct.pack('<Q',v))
def wf(a,v):u.mem_write(a,struct.pack('<f',v))
def rf(a):return struct.unpack('<f',u.mem_read(a,4))[0]
def si(a):return struct.unpack('<i',u.mem_read(a,4))[0]
def hook(u,a,n,_):
    if a==stop:u.emu_stop();return
    if not any(lo<=a<hi for lo,hi in ranges):raise RuntimeError(f'Unmapped subdivision dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def invoke(entry,args,extras=[]):
    rsp=stack+0xff08;u.mem_write(rsp-0x100,bytes(0x180));wq(rsp,stop);u.reg_write(UC_X86_REG_RSP,rsp)
    for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],args):u.reg_write(reg,value&0xffffffffffffffff)
    for n,value in enumerate(extras):wq(rsp+0x28+n*8,value)
    u.emu_start(entry,stop,count=50000);assert u.reg_read(UC_X86_REG_RIP)==stop
def run(mesh):
    u.mem_write(heap,bytes(0x60000));counts=[len(mesh['faces'])*4**n for n in range(3)];vcounts=[len(mesh['vertices']),len(mesh['vertices'])+3*counts[0],len(mesh['vertices'])+3*counts[0]+3*counts[1]]
    for n,point in enumerate(mesh['vertices']):
        for axis,value in enumerate(point):wf(levels[0]['vertices']+n*12+axis*4,value)
    for name in ['faces','adjacency']:
        for n,row in enumerate(mesh[name]):
            for axis,value in enumerate(row):wi(levels[0][name]+n*12+axis*4,value)
    for n in range(3):
        for off,name in zip([[0xd0,0x78,0xb0],[0xd8,0x80,0xb8],[0xe0,0x88,0xc0]][n],['vertices','faces','adjacency']):wq(surface+off,levels[n][name])
        wi(surface+[0x64,0x68,0x6c][n],counts[n]);wi(surface+[0x54,0x58,0x5c][n],vcounts[n])
    captures=[]
    for n in [1,2]:
        before,after=levels[n-1],levels[n]
        invoke(0x1402c4600,[surface,after['faces'],counts[n],after['vertices']],[vcounts[n],after['adjacency'],before['faces'],counts[n-1],before['vertices'],vcounts[n-1],before['adjacency']])
        captures.append({name:[[rf(after[name]+k*12+axis*4) if name=='vertices' else si(after[name]+k*12+axis*4) for axis in range(3)] for k in range(vcounts[n] if name=='vertices' else counts[n])] for name in ['vertices','faces','adjacency']})
    queries=[]
    for level in range(3):
        for remaining in range(3-level):
            seeds=[-1]+([0] if level>0 and counts[level-1]>0 else [])
            for seed in seeds:
                for point in [[0,0],[1,1],[5,5],[10,0],[0,10],[10,10],[7.5,2.5],[2.5,7.5],[3.333333,3.333333],[-1,-1],[10.0001,5]]:
                    rsp=stack+0xff08;u.mem_write(rsp-0x100,bytes(0x180));wq(rsp,stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,surface);u.reg_write(UC_X86_REG_RDX,level);u.reg_write(UC_X86_REG_R8,remaining);u.reg_write(UC_X86_REG_XMM3,int.from_bytes(struct.pack('<f',point[0]),'little'));wf(rsp+0x28,point[1]);wi(rsp+0x30,seed)
                    u.emu_start(0x1402bd610,stop,count=10000);assert u.reg_read(UC_X86_REG_RIP)==stop
                    queries.append(dict(level=level,remaining=remaining,seed=seed,point=point,result=u.reg_read(UC_X86_REG_RAX)&0xffffffff))
    getters=[]
    for level in [-1,0,1,2,3]:
        selected=1 if level==1 else 2 if level>=2 else 0
        for index in range(counts[selected]):
            invoke(0x1402bf390,[surface,level,index,output],[output+4,output+8]);vertices=[si(output+n*4) for n in range(3)]
            invoke(0x1402bf1c0,[surface,level,index,output],[output+4,output+8]);getters.append(dict(level=level,index=index,vertices=vertices,adjacency=[si(output+n*4) for n in range(3)]))
    return dict(mesh=mesh,levels=captures,queries=queries,getters=getters)
square=dict(vertices=[[0,0,0],[10,0,0],[10,10,0],[0,10,0]],faces=[[0,1,2],[0,2,3]],adjacency=[[-2,-2,1],[0,-2,-2]])
meshes=[dict(vertices=[[0,0,0],[10,0,0],[0,10,0]],faces=[[0,1,2]],adjacency=[[-2,-3,-2]]),square,
  dict(vertices=[[0,0,0],[10,0,0],[0,10,0],[10,10,0]],faces=[[0,1,2],[2,1,3]],adjacency=[[-2,1,-3],[0,-2,-3]]),square|dict(adjacency=[[1,-3,-2],[-2,0,-3]]),
  dict(vertices=[[.1,.2,.3],[9.8,.001,1.4],[.1,9.7,.3]],faces=[[0,1,2]],adjacency=[[-2,-3,-2]])]
rows=[run(mesh) for mesh in meshes]
out=root/'backups/animations/native-subdivision-observations.json';out.write_text(json.dumps(dict(binarySha256=digest,limits=__doc__,rows=rows),indent=2));print(json.dumps(dict(output=str(out),meshes=len(rows),queries=sum(len(r['queries']) for r in rows),getters=sum(len(r['getters']) for r in rows))))
