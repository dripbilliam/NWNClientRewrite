"""Read-only full IntraTileDFSGenerateSuccessors with original subdivision,
encoded getters/searches and magnitude. Tile/area collision responses, FLOAT
sqrt and allocations/frees are captured. Validates physical hierarchy masks,
midpoint/centre/goal candidates, scoring/order and optimisation==1 shortcuts.
"""
from pathlib import Path
import sys,struct,hashlib,json,re,itertools,math
root=Path(__file__).resolve().parents[1];sys.path.insert(0,str(root/'backups/research-python'))
import pefile
from unicorn import Uc,UC_ARCH_X86,UC_MODE_64,UC_HOOK_CODE
from unicorn.x86_const import *
data=(root.parent/'FullDecomp/NwnRootInstall/bin/win32/nwmain.exe').read_bytes();digest=hashlib.sha256(data).hexdigest();assert digest=='3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a'
pe=pefile.PE(data=data);base=pe.OPTIONAL_HEADER.ImageBase
u=Uc(UC_ARCH_X86,UC_MODE_64);u.mem_map(base,(pe.OPTIONAL_HEADER.SizeOfImage+4095)&~4095);u.mem_write(base,pe.get_memory_mapped_image())
heap,stack,stop=0x200000000,0x300000000,0x400000000
u.mem_map(heap,0x80000);u.mem_map(stack,0x20000);u.mem_map(stop,0x1000)
surface,tile,area,path,output=heap,heap+0x1000,heap+0x2000,heap+0x3000,heap+0x4000
levels=[dict(vertices=heap+0x10000+n*0x10000,faces=heap+0x12000+n*0x10000,adjacency=heap+0x14000+n*0x10000) for n in range(3)]
ranges=[(0x1402bfec0,0x1402c0d3d)]
for file in ['live-native-subdivision-full-asm.txt','live-native-subdivision-getters-leaf-asm.txt','live-native-intra-magnitude-asm.txt']:
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
def finish(v=0):
    rsp=u.reg_read(UC_X86_REG_RSP);u.reg_write(UC_X86_REG_RIP,q(rsp));u.reg_write(UC_X86_REG_RSP,rsp+8);u.reg_write(UC_X86_REG_RAX,v&0xffffffffffffffff)
def line_result(a,b,strict,area=False):
    is_goal=b==[struct.unpack('<f',struct.pack('<f',v))[0] for v in c['goal']]
    if c['mode']=='all-clear':return 1
    if c['mode']=='blocked':return 0
    if c['mode']=='goal-area-blocked':return 0 if area and is_goal else 1
    if c['mode']=='goal-tile-blocked':return 0 if not area and strict==0 else 1
    return 0 if is_goal or strict==0 else 1
def hook(u,a,n,_):
    global allocated
    if a==stop:u.emu_stop();return
    rsp=u.reg_read(UC_X86_REG_RSP)
    if a==0x140c10368:
        ptr=heap+0x60000+allocated*0x2000;allocated+=1;finish(ptr)
    elif a==0x140293a50:
        ptr=u.reg_read(UC_X86_REG_RCX);u.mem_write(ptr,bytes(24));finish(ptr)
    elif a==0x140c10370:finish()
    elif a==0x140c7d6d8:
        u.reg_write(UC_X86_REG_XMM0,int.from_bytes(struct.pack('<f',math.sqrt(xmm(UC_X86_REG_XMM0))),'little'));finish()
    elif a==0x1402c5250:
        start=[xmm(UC_X86_REG_XMM1),xmm(UC_X86_REG_XMM2)];end=[xmm(UC_X86_REG_XMM3),rf(rsp+0x28)];strict=i(rsp+0x50);calls.append(['tile',start,end,strict]);wf(q(rsp+0x30),-.1);wf(q(rsp+0x38),.6);finish(line_result(start,end,strict))
    elif a==0x1402c5060:
        start=[xmm(UC_X86_REG_XMM1),xmm(UC_X86_REG_XMM2)];end=[xmm(UC_X86_REG_XMM3),rf(rsp+0x28)];calls.append(['area',start,end,rf(rsp+0x30),rf(rsp+0x38)]);finish(line_result(start,end,1,True))
    elif not any(lo<=a<hi for lo,hi in ranges):raise RuntimeError(f'Unmapped intra successor dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def invoke(entry,args,extras=[]):
    rsp=stack+0x1ff08;u.mem_write(rsp-0x100,bytes(0x180));wq(rsp,stop);u.reg_write(UC_X86_REG_RSP,rsp)
    for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],args):u.reg_write(reg,value&0xffffffffffffffff)
    for n,value in enumerate(extras):wq(rsp+0x28+n*8,value)
    u.emu_start(entry,stop,count=50000);assert u.reg_read(UC_X86_REG_RIP)==stop
meshes=json.loads((root/'backups/animations/native-subdivision-observations.json').read_text())['rows']
def run(case):
    global c,calls,allocated
    c=case;calls=[];allocated=0;u.mem_write(heap,bytes(0x80000));mesh=meshes[c['mesh']]['mesh'];counts=[len(mesh['faces'])*4**n for n in range(3)];vcounts=[len(mesh['vertices']),len(mesh['vertices'])+3*counts[0],len(mesh['vertices'])+15*counts[0]]
    for n,point in enumerate(mesh['vertices']):
        for axis,value in enumerate(point):wf(levels[0]['vertices']+n*12+axis*4,value)
    for name in ['faces','adjacency']:
        for n,row in enumerate(mesh[name]):
            for axis,value in enumerate(row):wi(levels[0][name]+n*12+axis*4,value)
    for n in range(3):
        for off,name in zip([[0xd0,0x78,0xb0],[0xd8,0x80,0xb8],[0xe0,0x88,0xc0]][n],['vertices','faces','adjacency']):wq(surface+off,levels[n][name])
        wi(surface+[0x64,0x68,0x6c][n],counts[n]);wi(surface+[0x54,0x58,0x5c][n],vcounts[n])
    for n in [1,2]:
        before,after=levels[n-1],levels[n];invoke(0x1402c4600,[surface,after['faces'],counts[n],after['vertices']],[vcounts[n],after['adjacency'],before['faces'],counts[n-1],before['vertices'],vcounts[n-1],before['adjacency']])
    for off,value in zip([0x130,0x13c],c['goal']):wf(surface+off,value)
    for off,value in zip([0x134,0x138,0x140,0x144],c['bounds']):wf(surface+off,value)
    wi(surface+0x148,c['target']);wi(surface+0x170,0)
    for n in range(9):wi(surface+0x188+n*4,-7)
    rsp=stack+0x1ff08;u.mem_write(rsp-0x100,bytes(0x180));wq(rsp,stop);u.reg_write(UC_X86_REG_RSP,rsp)
    for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],[surface,c['optimisation'],tile,area]):u.reg_write(reg,value)
    wf(rsp+0x28,c['point'][0]);wf(rsp+0x30,c['point'][1]);wi(rsp+0x38,c['triangle']);wq(rsp+0x40,path);wq(rsp+0x48,output)
    try:u.emu_start(0x1402bfec0,stop,count=50000)
    except Exception:print(json.dumps(dict(case=c,rip=hex(u.reg_read(UC_X86_REG_RIP)),calls=calls)));raise
    assert u.reg_read(UC_X86_REG_RIP)==stop;count=u.reg_read(UC_X86_REG_RAX)&0xffffffff;ptr=q(output);rows=[]
    for n in range(count):rows.append(dict(via=[rf(ptr+n*24),rf(ptr+n*24+4)],point=[rf(ptr+n*24+8),rf(ptr+n*24+12)],cost=rf(ptr+n*24+16),triangle=si(ptr+n*24+20)))
    return dict(case=c,calls=calls,rows=rows,work=si(surface+0x170),masks=[[si(surface+0x188+n*12+j*4) for j in range(3)] for n in range(3)])
default=dict(mesh=1,optimisation=0,point=[1,1],goal=[8,8],bounds=[7.9999,8.0001,7.9999,8.0001],target=-1,triangle=0,mode='edge-only')
rows=[run(default|dict(mesh=mesh,optimisation=opt,point=point,triangle=triangle,target=target,mode=mode)) for mesh,opt,point,triangle,target,mode in itertools.product([0,1,2,4],[0,1],[[1,1],[2.5,2.5]],[0,2,5,10],[ -1,0,16],['all-clear','blocked','goal-area-blocked','goal-tile-blocked','edge-only'])]
out=root/'backups/animations/native-intratile-successor-observations.json';out.write_text(json.dumps(dict(binarySha256=digest,limits=__doc__,rows=rows),indent=2));print(json.dumps(dict(output=str(out),rows=len(rows))))
