"""Read-only build89 full safe/nonvisible placement and player visibility
counter bodies, including original area iteration. Synthetic height/safety,
walk/LOS/polygon/client/lookup providers captured. Validates candidate and
dependency order/output mutation, not installed geometry or native spawning.
"""
from pathlib import Path
import sys,struct,hashlib,json,itertools
root=Path(__file__).resolve().parents[1];sys.path.insert(0,str(root/'backups/research-python'))
import pefile
from unicorn import Uc,UC_ARCH_X86,UC_MODE_64,UC_HOOK_CODE
from unicorn.x86_const import *
data=(root.parent/'FullDecomp/NwnRootInstall/bin/win32/nwmain.exe').read_bytes();digest=hashlib.sha256(data).hexdigest()
assert digest=='3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a'
pe=pefile.PE(data=data);base=pe.OPTIONAL_HEADER.ImageBase
u=Uc(UC_ARCH_X86,UC_MODE_64);u.mem_map(base,(pe.OPTIONAL_HEADER.SizeOfImage+4095)&~4095);u.mem_write(base,pe.get_memory_mapped_image())
heap,stack,stop=0x200000000,0x300000000,0x400000000
u.mem_map(heap,0x20000);u.mem_map(stack,0x10000);u.mem_map(stop,0x1000)
area,origin,path,out,app,spatial,vt=[heap+n*0x1000 for n in range(7)]
def i(a):return int.from_bytes(u.mem_read(a,4),'little')
def q(a):return int.from_bytes(u.mem_read(a,8),'little')
def wi(a,v):u.mem_write(a,struct.pack('<I',v&0xffffffff))
def wq(a,v):u.mem_write(a,struct.pack('<Q',v))
def wf(a,v):u.mem_write(a,struct.pack('<f',v))
def f(v):return struct.unpack('<f',struct.pack('<f',v))[0]
def point(a):return list(struct.unpack('<fff',u.mem_read(a,12)))
def xm(r):return struct.unpack('<f',u.reg_read(r).to_bytes(16,'little')[:4])[0]
def rf(a):return struct.unpack('<f',u.mem_read(a,4))[0]
def finish(v=0):
    rsp=u.reg_read(UC_X86_REG_RSP);u.reg_write(UC_X86_REG_RIP,q(rsp));u.reg_write(UC_X86_REG_RSP,rsp+8);u.reg_write(UC_X86_REG_RAX,v)
def hook(u,a,n,_):
    global height_index,safe_index
    if a==stop:u.emu_stop();return
    x,y,z,w=[u.reg_read(r) for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
    if a==0x14036a210:
        calls.append(['height',point(y)]);value=f(case['height']+height_index*.01);height_index+=1;u.reg_write(UC_X86_REG_XMM0,int.from_bytes(struct.pack('<f',value),'little'));finish()
    elif a==0x140372470:
        calls.append(['safe',point(y)]);result=int(case['safeAfter']>=0 and safe_index>=case['safeAfter']);safe_index+=1;finish(result)
    elif a==0x140372220:
        calls.append(['walk',[xm(UC_X86_REG_XMM1),xm(UC_X86_REG_XMM2)],[xm(UC_X86_REG_XMM3),rf(rsp+0x28)]]);finish(case['walk'])
    elif a==0x140298700:
        calls.append(['polygons',[xm(UC_X86_REG_XMM1),xm(UC_X86_REG_XMM2)],[xm(UC_X86_REG_XMM3),rf(rsp+0x28)],rf(rsp+0x30),rf(rsp+0x38),rf(rsp+0x40)]);finish(case['polygons'])
    elif a==0x14035c590:calls.append(['los',point(y),point(z)]);finish(case['los'])
    elif a==0x14036b870 and case['mode']!='count':calls.append(['count',point(y),z&0xffffffff]);finish(min(case['visible'],z&0xffffffff))
    elif a==0x140115890:calls.append(['warning']);finish()
    elif a==0x14055b850:finish(app)
    elif a==0x140296470:wq(z,actors.get(y&0xffffffff,0));finish(0 if y&0xffffffff in actors else 1)
    elif a==stop+0x100:finish(x if case['actorTypes'][i(x+8)-11]==5 else 0)
    elif a==0x14055b390:calls.append(['client',y&0xffffffff]);finish(int(case['client']))
    elif not any(start<=a<end for start,end in [(0x14036aa90,0x14036b04c),(0x14036a370,0x14036a9d6),(0x14036b870,0x14036ba68),(0x14035e7f0,0x14035e817),(0x14035ea40,0x14035ea70)]):raise RuntimeError(f'Unmapped placement dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(c):
    global case,calls,height_index,safe_index,actors
    case=c;calls=[];height_index=0;safe_index=0;actors={};u.mem_write(heap,bytes(0x20000))
    wq(0x1412df970,app);wq(app+8,app);u.mem_write(origin,struct.pack('<fff',*c['origin']));u.mem_write(out,struct.pack('<fff',88,99,77));wf(path+4,c['radius']);wf(path+0xc,c['bodyHeight']);wq(area+0x228,spatial);wi(area+0x230,len(c['actorTypes']));wi(area+0x140,77);wi(area+0x238,99);wq(vt+0x60,stop+0x100)
    for n,kind in enumerate(c['actorTypes']):actor=heap+0x8000+n*0x1000;actors[n+11]=actor;wq(actor,vt);wi(actor+8,n+11);wi(spatial+n*4,n+11);u.mem_write(actor+0xa4,struct.pack('<fff',*c['actorPoints'][n]))
    rsp=stack+0xff08;u.mem_write(rsp-0x2000,bytes(0x2080));wq(rsp,stop);u.reg_write(UC_X86_REG_RSP,rsp)
    args=[area,origin,path if c['hasPath'] else 0,c['straight']]
    if c['mode']=='safe':args=[area,origin,0,path if c['hasPath'] else 0];wi(rsp+0x28,c['straight']);wq(rsp+0x30,out);u.reg_write(UC_X86_REG_XMM2,int.from_bytes(struct.pack('<f',c['range']),'little'))
    elif c['mode']=='nonvisible':wq(rsp+0x28,out);wf(rsp+0x30,c['range'])
    else:args=[area,origin,c['limit'],0]
    for r,v in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],args):u.reg_write(r,v)
    u.emu_start({'safe':0x14036aa90,'nonvisible':0x14036a370,'count':0x14036b870}[c['mode']],stop,count=200000);assert u.reg_read(UC_X86_REG_RIP)==stop
    return {'case':c,'result':u.reg_read(UC_X86_REG_RAX)&0xffffffff,'out':point(out),'origin':point(origin),'cursor':i(area+0x238),'calls':calls}
default=dict(origin=[10.25,11.75,4],height=2,bodyHeight=.5,radius=.6,range=2,hasPath=True,straight=0,safeAfter=0,walk=1,polygons=1,los=1,visible=0,actorTypes=[],actorPoints=[],client=False,limit=255)
cases=[]
for mode,radius,hasPath,straight,safeAfter,walk,polygons in itertools.product(['safe'],[0,.05,.6,2],[False,True],[0,1],[-1,0,1,8],[0,1],[0,1,2]):cases.append(default|dict(mode=mode,radius=radius,hasPath=hasPath,straight=straight,safeAfter=safeAfter,walk=walk,polygons=polygons))
for mode,hasPath,straight,safeAfter,visible,los in itertools.product(['nonvisible'],[False,True],[0,1],[-1,0,1,8],[0,1],[0,1]):cases.append(default|dict(mode=mode,hasPath=hasPath,straight=straight,safeAfter=safeAfter,visible=visible,los=los))
for kinds,client,limit,los in itertools.product([[],[5],[5,5,6,5],[6,5]],[False,True],[0,1,2,255],[0,1]):cases.append(default|dict(mode='count',actorTypes=kinds,actorPoints=[[10,11,0],[10,11,0],[100,100,0],[10,11,0]][:len(kinds)],client=client,limit=limit,los=los))
observations=[run(c) for c in cases];output=root/'backups/animations/native-spawn-placement-observations.json';output.write_text(json.dumps({'binarySha256':digest,'limits':__doc__,'observations':observations},indent=2));print(json.dumps({'output':str(output),'observations':len(observations)}))
