"""Complete unchanged ChunkyParticle constructor/initialize/destructor and
PartEmitter::RenderNothing. Base particle initialization, model allocation,
scene/scale/animation, normalization, sin/cos, vector multiply and virtual pose
setters are explicit captured lower providers; no asset/GPU parity claim.
"""
import importlib,itertools,json,math,struct,sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
particle,emitter,node,chunk,vt,active,source,sourceinstance,instance=[m.heap+n*0x1000 for n in range(1,10)]
bodies={'construct':(0x1400602b0,0x140060373),'initialize':(0x1400663d0,0x14006644c),'destroy':(0x1400608a0,0x1400608dd),'render':(0x140064190,0x1400643ab)}
def f(value):return struct.unpack('<f',struct.pack('<f',value))[0]
def vector(address):return [m.rf(address+n*4) for n in range(3)]
def put(address,values):
    for n,value in enumerate(values):m.wf(address+n*4,value)
def string(address):return bytes(u.mem_read(address,32)).split(b'\0')[0].decode()
def hook(u,address,size,data):
    if address==m.stop:u.emu_stop();return
    x,y,z,w=[u.reg_read(reg)for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
    if address==0x140066450:
        calls.append(['baseInitialize',m.xmm(UC_X86_REG_XMM1),m.xmm(UC_X86_REG_XMM2)]);m.wf(x+0x74,0);m.finish()
    elif address==0x1400931f0:calls.append(['create',string(x),string(y),z]);m.finish(chunk if case['model']else 0)
    elif address==0x14018de80:raise AssertionError('Unexpected resref assignment')
    elif address==m.stop+0x10:calls.append(['scene',bool(y)]);m.finish()
    elif address==m.stop+0x20:calls.append(['scale',m.xmm(UC_X86_REG_XMM1),z]);m.finish()
    elif address==m.stop+0x30:calls.append(['play',string(y),m.xmm(UC_X86_REG_XMM2),w,m.rf(u.reg_read(UC_X86_REG_RSP)+0x28)]);m.finish()
    elif address==m.stop+0x40:calls.append(['delete',y]);m.finish()
    elif address==m.stop+0x50:calls.append(['position',int((x-chunk)//0x100),vector(z)]);m.finish(y)
    elif address==m.stop+0x60:calls.append(['orientation',int((x-chunk)//0x100),[m.rf(z+n*4)for n in range(4)]]);m.finish(y)
    elif address==0x14022db30:
        value=vector(x);s=f(f(f(value[0]*value[0])+f(value[1]*value[1]))+f(value[2]*value[2]));factor=f(math.sqrt(f(1/s)))
        put(x,[f(v*factor)for v in value]);m.finish(x)
    elif address==0x14022b150:put(x,[f(v*m.xmm(UC_X86_REG_XMM1))for v in vector(x)]);m.finish(x)
    elif address in [0x140c7ac70,0x140c7a2b0]:
        angle=m.xmm(UC_X86_REG_XMM0); value=f(math.cos(angle) if address==0x140c7ac70 else math.sin(angle));u.reg_write(UC_X86_REG_XMM0,struct.unpack('<I',struct.pack('<f',value))[0]);m.finish()
    elif not any(lo<=address<=hi for lo,hi in bodies.values()):raise AssertionError(hex(address))
u.hook_add(UC_HOOK_CODE,hook)
def run(value):
    global case,calls
    case=value;calls=[];u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));m.wi(0x1413012e8,0)
    m.wq(particle+8,emitter);m.wq(emitter+8,node);u.mem_write(node+0x158,b'authored_chunk\0');m.wq(0x14140ac50,0x12345678)
    for offset,target in [(0,m.stop+0x40),(0x90,m.stop+0x10),(0x1b0,m.stop+0x20),(0x30,m.stop+0x30),(0xb0,m.stop+0x50),(0xb8,m.stop+0x60)]:m.wq(vt+offset,target)
    m.wq(chunk,vt);m.wq(chunk+0x100,vt);m.wq(particle+0x78,chunk if case.get('model')else 0)
    if case['operation']=='render':
        m.wq(emitter+0x50,source if case['source']else 0);m.wq(source+0x1a8,sourceinstance);m.wf(sourceinstance+0xc8,case['sourceFade']);m.wq(emitter+0x100,instance);m.wf(instance+0xc8,case['fade']);m.wf(emitter+0xbc,case['rotation'])
        m.wq(emitter+0x188,active);m.wi(emitter+0x190,2)
        for index in range(2):
            part=particle+index*0x100;m.wq(active+index*8,part);m.wq(part+0x78,chunk+index*0x100 if case['model']else 0)
            put(part+0x10,[1+index,2-index,3+index]);put(part+0x4c,[3,0,4]if index==0 else[0,0,2]);m.wf(part+0x1c,case['rotation']+index*.25);u.mem_write(part+0x70,bytes([case['stopped']]))
    sp=m.stack+0x1fc08;m.wq(sp,m.stop);u.reg_write(UC_X86_REG_RSP,sp)
    u.reg_write(UC_X86_REG_RCX,emitter if case['operation']=='render'else particle);u.reg_write(UC_X86_REG_RDX,emitter)
    u.reg_write(UC_X86_REG_XMM1,struct.unpack('<I',struct.pack('<f',case.get('delta',0)))[0]);u.reg_write(UC_X86_REG_XMM2,struct.unpack('<I',struct.pack('<f',case.get('factor',1) if case['operation']=='initialize'else case.get('delta',0)))[0])
    u.emu_start(bodies[case['operation']][0],m.stop,count=10000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
    return dict(case={k:(None if isinstance(v,float)and math.isnan(v)else v)for k,v in case.items()},calls=calls,chunk=bool(m.q(particle+0x78)))
rows=[]
for operation,model in itertools.product(['construct','initialize','destroy'],[False,True]):
    for delta,factor in ([(0.0,0.5),(.016,1.0),(.1,2.0)]if operation!='destroy'else[(0.0,1.0)]):rows.append(run(dict(operation=operation,model=model,delta=delta,factor=factor)))
for source_present,source_fade,fade,rotation,stopped,model in itertools.product([False,True],[.5,1.,float('nan')],[.5,1.],[0.,1.5],[0,1],[False,True]):rows.append(run(dict(operation='render',source=source_present,sourceFade=source_fade,fade=fade,rotation=rotation,stopped=stopped,model=model)))
out=m.root/'backups/animations/native-particle-chunks-v1.json';assert not out.exists();out.write_text(json.dumps(dict(binarySha256=m.digest,scope=__doc__,bodies=bodies,rows=rows),indent=2,allow_nan=False)+'\n');print(json.dumps(dict(cases=len(rows),output=str(out))))
