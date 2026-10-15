"""Read-only build89 full SpawnEncounterCreatures body. Synthetic prepared
lists and placements; list preparation, allocation/ctor/template/destructor,
safe/nonvisible/height/trigonometry/normalization, area and AI helpers captured.
Validates branch/order/count/pool and placement latch, not transitive import,
geometry, heap failure, model rendering or packet behavior.
"""
from pathlib import Path
import sys,struct,hashlib,json,itertools,math
root=Path(__file__).resolve().parents[1];sys.path.insert(0,str(root/'backups/research-python'))
import pefile
from unicorn import Uc,UC_ARCH_X86,UC_MODE_64,UC_HOOK_CODE
from unicorn.x86_const import *
data=(root.parent/'FullDecomp/NwnRootInstall/bin/win32/nwmain.exe').read_bytes();digest=hashlib.sha256(data).hexdigest()
assert digest=='3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a'
pe=pefile.PE(data=data);base=pe.OPTIONAL_HEADER.ImageBase
u=Uc(UC_ARCH_X86,UC_MODE_64);u.mem_map(base,(pe.OPTIONAL_HEADER.SizeOfImage+4095)&~4095);u.mem_write(base,pe.get_memory_mapped_image())
heap,stack,stop=0x200000000,0x300000000,0x400000000
u.mem_map(heap,0x100000);u.mem_map(stack,0x10000);u.mem_map(stop,0x1000)
enc,area,app,vt,spawnpoints,entered=[heap+n*0x2000 for n in range(6)]
def i(a):return int.from_bytes(u.mem_read(a,4),'little')
def q(a):return int.from_bytes(u.mem_read(a,8),'little')
def wi(a,v):u.mem_write(a,struct.pack('<I',v&0xffffffff))
def wq(a,v):u.mem_write(a,struct.pack('<Q',v))
def wf(a,v):u.mem_write(a,struct.pack('<f',v))
def rf(a):return struct.unpack('<f',u.mem_read(a,4))[0]
def f(v):return struct.unpack('<f',struct.pack('<f',v))[0]
def point(p):return list(struct.unpack('<fff',u.mem_read(p,12)))
def setpoint(p,v):u.mem_write(p,struct.pack('<fff',*v))
def xm(r):return struct.unpack('<f',u.reg_read(r).to_bytes(16,'little')[:4])[0]
def setxm(r,v):u.reg_write(r,int.from_bytes(struct.pack('<f',v),'little'))
def finish(v=0):
    rsp=u.reg_read(UC_X86_REG_RSP);u.reg_write(UC_X86_REG_RIP,q(rsp));u.reg_write(UC_X86_REG_RSP,rsp+8);u.reg_write(UC_X86_REG_RAX,v)
def write_entry(p,e):wi(p,e['resRef']);wf(p+0x14,e['cr']);wf(p+0x18,e['points'])
def hook(u,a,n,_):
    global allocation,created,safe_index,hidden_index
    if a==stop:u.emu_stop();return
    x,y,z,w=[u.reg_read(r) for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
    if a==0x140494e80:finish(area if c['hasArea'] else 0)
    elif a in [0x140c10368,0x140c10324]:allocation+=0x2000;finish(allocation)
    elif a in [0x140c11414,0x140c10434,0x140c10528]:finish()
    elif a==0x14043cc00:
        calls.append(['make']);wi(z,len(c['list']))
        for k,e in enumerate(c['list']):write_entry(y+k*0x28,e)
        finish()
    elif a==0x14043adf0:calls.append(['split',w&0xffffffff,i(q(rsp+0x28))]);finish()
    elif a==0x14043cf90:
        calls.append(['pad']);count=i(z)
        while count<c['recommended']-c['spawned']:write_entry(y+count*0x28,dict(resRef=9,cr=1,points=1));count+=1
        wi(z,count);finish()
    elif a==0x14055b3d0:finish(entered if c['entered'] else 0)
    elif a in [0x140c7a2b0,0x140c7ac70]:setxm(UC_X86_REG_XMM0,math.sin(xm(UC_X86_REG_XMM0)) if a==0x140c7a2b0 else math.cos(xm(UC_X86_REG_XMM0)));finish()
    elif a==0x140230920:
        v=point(y);length=f(math.sqrt(f(f(f(v[0]*v[0])+f(v[1]*v[1]))+f(v[2]*v[2]))));setpoint(x,[f(n/length) for n in v]);finish(x)
    elif a==0x14037a300:
        created+=1;wi(x+8,100+created);wq(x,vt);wq(x+0x530,x+0x1000);calls.append(['construct',i(x+8)]);actor_ptrs.append(x);finish(x)
    elif a==0x140397dd0:calls.append(['load',i(x+8),i(y)]);finish(c['loaded'])
    elif a==stop+0x100:calls.append(['destroy',i(x+8)]);finish()
    elif a==0x140115890:calls.append(['warning']);finish()
    elif a==0x14036aa90:
        calls.append(['safe',point(y),xm(UC_X86_REG_XMM2),i(rsp+0x28)]);setpoint(q(rsp+0x30),[1,2,3]);finish(c['safe'][safe_index%len(c['safe'])]);safe_index+=1
    elif a==0x14036a370:
        calls.append(['hidden',point(y),w&0xffffffff,rf(rsp+0x30)]);row=c['hidden'][hidden_index%len(c['hidden'])];hidden_index+=1;setpoint(q(rsp+0x28),row['point']);finish(row['result'])
    elif a==0x14036a210:calls.append(['height',point(y)]);setxm(UC_X86_REG_XMM0,c['height']);finish()
    elif a==0x140380470:calls.append(['area',i(x+8),[xm(UC_X86_REG_XMM2),xm(UC_X86_REG_XMM3),rf(rsp+0x28)],i(rsp+0x30),i(rsp+0x38)]);finish()
    elif a==0x14055b960:finish(app)
    elif a==0x140559cb0:calls.append(['ai',i(y+8),z&0xffffffff]);finish()
    elif a==0x14049b910:calls.append(['orientation',i(x+8),point(y)]);finish()
    elif not(0x14043f000<=a<0x14043f756):raise RuntimeError(f'Unmapped encounter spawn dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
    global c,calls,allocation,created,actor_ptrs,safe_index,hidden_index
    c=case;calls=[];allocation=heap+0x20000;created=0;actor_ptrs=[];safe_index=0;hidden_index=0;u.mem_write(heap,bytes(0x100000));wq(0x1412df970,app);wq(app+8,app);wq(vt,stop+0x100)
    wi(enc+8,77);wi(enc+0x33c,4);wi(enc+0x338,c['recommended']);wi(enc+0x340,c['spawned']);wf(enc+0x3c4,c['pool']);wf(enc+0x3c8,c['activePool']);wf(enc+0x3bc,c['minimum']);wi(enc+0x3cc,11);setpoint(enc+0xa4,[10,20,3]);setpoint(entered+0xa4,[5,6,7]);wi(area+0x150,c['players']);wi(enc+0x3a8,len(c['spawnPoints']));wq(enc+0x3a0,spawnpoints)
    for k,row in enumerate(c['spawnPoints']):setpoint(spawnpoints+k*16,row['point']);wf(spawnpoints+k*16+12,row['orientation'])
    rsp=stack+0xff08;u.mem_write(rsp-0x2000,bytes(0x2080));wq(rsp,stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,enc)
    try:u.emu_start(0x14043f000,stop,count=20000)
    except Exception:print(json.dumps({'case':c,'rip':hex(u.reg_read(UC_X86_REG_RIP)),'calls':calls}));raise
    assert u.reg_read(UC_X86_REG_RIP)==stop
    return {'case':c,'spawned':i(enc+0x340),'pool':rf(enc+0x3c4),'activePool':rf(enc+0x3c8),'creatures':[[i(p+8),i(p+0x948),i(p+0x89c)] for p in actor_ptrs],'calls':calls}
entry=dict(resRef=1,cr=1,points=1);default=dict(hasArea=True,list=[entry],recommended=0,spawned=0,pool=5,activePool=1,minimum=1,spawnPoints=[],entered=True,loaded=1,players=1,safe=[1],hidden=[dict(result=1,point=[7,8,9])],height=4)
cases=[]
for points,entered_flag,loaded,players,safe,hidden in itertools.product([[],[dict(point=[1,2,3],orientation=0),dict(point=[50,60,70],orientation=1)]],[False,True],[0,1],[0,1],[[0],[1],[0,1],[1,0]],[[dict(result=1,point=[7,8,9])],[dict(result=0,point=[-1,-1,-1])],[dict(result=0,point=[7,8,9])]]):cases.append(default|dict(spawnPoints=points,entered=entered_flag,loaded=loaded,players=players,safe=safe,hidden=hidden,list=[entry,entry|dict(resRef=2,points=2)]))
for hasArea,list_value,recommended,pool,minimum in itertools.product([False,True],[[],[entry]],[0,2],[0,.5,5],[0,1]):cases.append(default|dict(hasArea=hasArea,list=list_value,recommended=recommended,pool=pool,minimum=minimum))
observations=[run(c) for c in cases];output=root/'backups/animations/native-encounter-spawn-observations.json';output.write_text(json.dumps({'binarySha256':digest,'limits':__doc__,'observations':observations},indent=2));print(json.dumps({'output':str(output),'observations':len(observations)}))
