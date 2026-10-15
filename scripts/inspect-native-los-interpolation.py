"""Read-only tile LOS clip/interpolation and LOS kernels with IEEE outputs.
Original clipping, local/world rotations, AABB/box and polygon instructions
execute unchanged. Loaded synthetic geometry and material mask are explicit;
no finite height is invented when native quarter-turn division yields NaN/Inf.
"""
import importlib.util,itertools,json,re,math
from pathlib import Path
spec=importlib.util.spec_from_file_location('coordinator',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle);q,si,wi,wq,wf,rf,finish=[getattr(m,n) for n in ['q','si','wi','wq','wf','rf','finish']]
tile,info,surface,source,target,entryPoint,exitPoint,output,vertices,indices,planes,normals,materials,node=[m.heap+n*0x1000 for n in range(14)];ranges=[]
for file in ['live-native-los-wrappers-asm.txt','live-native-los-clip-rotation-full-asm.txt','live-native-tile-coordinate-owner-asm.txt','live-native-los-helper-asm.txt','live-native-los-aabb-asm.txt','live-native-los-cross-asm.txt']:
    content=(m.root/'backups/animations'/file).read_text().replace(', \n',', ')
    for line in content.splitlines():
        if line.startswith('FUNCTION REQUESTED'):ranges.extend((int(a,16),int(b,16)) for a,b in re.findall(r'([0-9a-f]+):([0-9a-f]+)',line))
def hook(u,a,n,_):
    if a==m.stop:u.emu_stop();return
    x,y,z=[u.reg_read(reg) for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8]]
    if a==0x1402c55a0:wi(y,1);wi(z,2);finish()
    elif a==0x1402beac0:finish(2)
    elif a==0x140047300:u.mem_write(x,bytes(12));finish(x)
    elif a==0x140c10410:finish(u.reg_read(UC_X86_REG_RAX))
    elif not any(lo<=a<hi for lo,hi in ranges):raise RuntimeError(f'Unmapped LOS interpolation dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def vec(pointer,values):
    for n,v in enumerate(values):wf(pointer+n*4,v)
def invoke(address,args,extras=[]):
    rsp=m.stack+0x1fe08;u.mem_write(rsp-0x100,bytes(0x200));wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
    for reg,v in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],args):u.reg_write(reg,v)
    for n,v in enumerate(extras):wq(rsp+0x28+n*8,v)
    try:u.emu_start(address,m.stop,count=100000)
    except Exception:print(json.dumps(dict(case=c,rip=hex(u.reg_read(UC_X86_REG_RIP)))));raise
    assert u.reg_read(UC_X86_REG_RIP)==m.stop;return u.reg_read(UC_X86_REG_RAX)&0xffffffff
def encode(v):return 'NaN' if math.isnan(v) else '+Infinity' if v==math.inf else '-Infinity' if v==-math.inf else v
def run(case):
    global c
    c=case;u.mem_write(m.heap,bytes(0x100000));wq(tile+0x30,info);wq(info+8,surface);wi(tile+0x1c,1);wi(tile+0x20,2);wi(tile+0x24,c['orientation']);wq(surface+0x78,indices)
    vec(source,c['start']);vec(target,c['goal']);vec(entryPoint,[99,99,99]);vec(exitPoint,[99,99,99]);vec(output,[99,99,99])
    status=invoke(0x1404fd620,[tile,source,target,entryPoint],[exitPoint]);entry=[rf(entryPoint+n*4) for n in range(3)];exit=[rf(exitPoint+n*4) for n in range(3)]
    return dict(case=c,status=status,entry=[encode(v) for v in entry],exit=[encode(v) for v in exit])
def kernel(case):
    global c
    c=case;u.mem_write(m.heap,bytes(0x100000));wq(surface+0x78,indices);wq(surface+0xd0,vertices);wq(surface+0xa0,planes);wq(surface+0xa8,normals);wq(surface+0x98,materials);wq(surface+0x128,node)
    for n,p in enumerate([[0,-2,-2],[0,2,-2],[0,0,2]]):vec(vertices+n*12,p);wi(indices+n*4,n)
    vec(normals,[1,0,0]);wf(planes,0);wi(materials,1);vec(node,[-.01,-2.01,-2.01]);vec(node+12,[.01,2.01,2.01]);wi(node+0x18,0);wi(node+0x1c,0)
    vec(source,[decode(v) for v in c['start']]);vec(target,[decode(v) for v in c['goal']]);vec(output,[99,99,99])
    box=invoke(0x14022b400,[source,target,node,node+12]);vec(source,[decode(v) for v in c['start']]);vec(target,[decode(v) for v in c['goal']])
    status=invoke(0x1402bb230,[surface,1,source,target],[output])
    return dict(case=c,box=box,status=status,output=[encode(rf(output+n*4)) for n in range(3)])
def decode(v):return {'NaN':math.nan,'+Infinity':math.inf,'-Infinity':-math.inf}.get(v,v) if isinstance(v,str) else v
rows=[run(dict(orientation=o,start=start,goal=goal)) for o,start,goal in itertools.product(range(4),[[5,25,0],[5,25,1],[15,15,0],[12,22,0]],[[25,25,20],[25,25,1],[15,35,20],[18,28,0]])]
# Only status1 outputs have a defined contract for the caller.
rows=[row for row in rows if row['status']==1]
kernels=[kernel(dict(start=[x,0,z],goal=[xx,0,zz])) for x,xx,z,zz in itertools.product([-1,0,1],[-1,0,1],[0,'NaN','+Infinity','-Infinity'],[0,'NaN','+Infinity','-Infinity'])]
out=m.root/'backups/animations/native-los-interpolation-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows,kernels=kernels),indent=2));print(json.dumps(dict(output=str(out),rows=len(rows),kernels=len(kernels))))
