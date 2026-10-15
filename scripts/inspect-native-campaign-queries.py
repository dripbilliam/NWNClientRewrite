"""Read-only original Left, atoi, GetAssociateType, GetSittingCreature and
GetFacing executions for EE89.8193.37-17. VM pops/pushes, canonical lookups,
string allocation and CRT locale setup/teardown are captured boundaries.
atoi's decimal parser and facing's original normalization/atan2f execute.
Bounded creature/waypoint/door orientation import blocks also execute, with
FLOAT GFF reads and the waypoint's unrelated position store captured.
Door sinf/cosf use the original CRT SSE branch.
The locale fixture is the CRT C locale, not a claim about other locales.
"""
import importlib.util,itertools,json,math,struct,random
from pathlib import Path
spec=importlib.util.spec_from_file_location('coordinator',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle);q,si,wi,wq,wf,rf,finish=[getattr(m,n) for n in ['q','si','wi','wq','wf','rf','finish']]
command,vm,actor,app,objects,text,locale,ctype,errno,allocated=[m.heap+n*0x1000 for n in range(10)]
ranges=[(0x14016bcb0,0x14016bd6c),(0x140c81d54,0x140c81d7d),(0x140c8047c,0x140c807b6),
        (0x14051f470,0x14051f4f6),(0x14052ff70,0x14052ffe2),(0x140523a70,0x140523ba4),
        (0x140230920,0x1402309f5),(0x140c8f29c,0x140c8f6ad),
        (0x140360815,0x14036089d),(0x14050a149,0x14050a222),
        (0x140360a85,0x140360ba3),(0x14049b910,0x14049b926),
        (0x14022db30,0x14022dbf2),(0x14022b150,0x14022b176),
        (0x140c7a2b0,0x140c7a9a8),(0x140c7ac70,0x140c7b16f)]

def hook(u,a,n,_):
    global output
    if a==m.stop:u.emu_stop();return
    if c['mode'] in ['creature-orientation','waypoint-orientation','bearing-orientation'] and a==end:
        output=[rf(actor+0xb0+i*4) for i in range(3)];u.emu_stop();return
    x,y,z=[u.reg_read(reg) for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8]]
    if a==0x140286160:wi(y,99);finish(1)
    elif a==0x140286410:output=y&0xffffffff;output=output if output<0x80000000 else output-0x100000000;finish(1)
    elif a==0x140286470:output=y&0xffffffff;finish(1)
    elif a==0x1402863b0:output=m.xmm(UC_X86_REG_XMM1);finish(1)
    elif a in [0x14055b3d0,0x14055b890]:finish(actor if c['exists'] else 0)
    elif a==0x14055b850:finish(objects)
    elif a==0x140296470:wq(z,actor if c['exists'] else 0);finish(int.from_bytes(u.mem_read(0x140dc2a78,1),'little'))
    elif a==0x140c10370:finish()
    elif a==0x14049bb40:finish() # waypoint position owner is separate
    elif a==0x1401a1650:
        name=bytes(u.mem_read(z,32)).split(b'\0')[0].decode('ascii');value=c.get(name,0.)
        u.reg_write(UC_X86_REG_XMM0,int.from_bytes(struct.pack('<f',value),'little'));finish()
    elif a==0x14003d8c0:
        raw=bytes(u.mem_read(y,z));u.mem_write(allocated,raw+b'\0');wq(x,allocated);wi(x+8,z);wi(x+12,z+1);finish(x)
    elif a==0x140c56200:
        wq(x,0);wq(x+8,locale);wq(x+16,0);u.mem_write(x+24,b'\0');finish(x)
    elif a==0x140c847a0:finish(errno)
    elif a==0x140c4ed2c:raise RuntimeError('Unexpected invalid CRT parameter')
    elif a==0x140c7d6d8:
        u.reg_write(UC_X86_REG_XMM0,int.from_bytes(struct.pack('<f',math.sqrt(m.xmm(UC_X86_REG_XMM0))),'little'));finish()
    elif a==0x140cae8e0:finish() # floating status only; original result branches execute
    elif not any(lo<=a<hi for lo,hi in ranges):raise RuntimeError(f'Unmapped campaign query dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)

def run(case):
    global c,output,end
    c=case;output=None;u.mem_write(m.heap,bytes(0x100000));wq(0x1412df910,vm);wq(0x1412df970,app);wq(app+8,app)
    wq(locale,ctype);wi(locale+8,1)
    for value in range(256):u.mem_write(ctype+value*2,struct.pack('<H',8 if value in [9,10,11,12,13,32] else 0))
    mode=c['mode'];args=[command,0,1];end=m.stop
    if mode=='left':
        raw=c['text'].encode('cp1252');u.mem_write(text,raw+b'\0');wq(actor,text);wi(actor+8,len(raw));args=[actor,objects,c['count']&0xffffffff];address=0x14016bcb0
    elif mode=='atoi':u.mem_write(text,c['text'].encode('cp1252')+b'\0');args=[text,0,0];address=0x140c81d54
    elif mode=='associate':wi(actor+0x8fc,c['master']);u.mem_write(actor+0x908,struct.pack('<H',c['associate']&65535));address=0x14051f470
    elif mode=='sitting':wi(actor+0x36c,c['occupant']);address=0x14052ff70
    elif mode=='facing':
        u.mem_write(actor+12,bytes([c['objectType']]));
        for i,v in enumerate(c['orientation']):wf(actor+0xb0+i*4,v)
        address=0x140523a70
    elif mode=='creature-orientation':address=0x140360815;end=0x14036089d
    elif mode=='waypoint-orientation':address=0x14050a149;end=0x14050a222
    elif mode=='bearing-orientation':address=0x140360a85;end=0x140360ba3
    rsp=m.stack+0x1fe08;u.mem_write(rsp-0x600,bytes(0x700));wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
    for reg,v in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8],args):u.reg_write(reg,v)
    u.reg_write(UC_X86_REG_RBP,rsp+0x180);u.reg_write(UC_X86_REG_RBX,actor);u.reg_write(UC_X86_REG_R14,actor)
    if mode.endswith('-orientation'):
        for reg,v in [(UC_X86_REG_XMM9,0.),(UC_X86_REG_XMM6,0.),(UC_X86_REG_XMM10,1.),(UC_X86_REG_XMM11,.5),(UC_X86_REG_XMM12,1e-8)]:u.reg_write(reg,int.from_bytes(struct.pack('<f',v),'little'))
    u.mem_write(0x1415d8224,bytes(4))
    u.emu_start(address,m.stop,count=100000);assert u.reg_read(UC_X86_REG_RIP)==end
    if mode=='left':output=bytes(u.mem_read(q(objects),si(objects+8))).decode('cp1252') if q(objects) else ''
    if mode=='atoi':output=u.reg_read(UC_X86_REG_RAX)&0xffffffff;output=output if output<0x80000000 else output-0x100000000
    return dict(case=case,result=output)

rows=[run(dict(mode='left',text=text,count=count)) for text,count in itertools.product(['','abcde','aé€','a\0bc'],[-2147483648,-1,0,1,2,5,6,2147483647])]
strings=['','0','-0','+0','0123','0x10','12.3','1e9','  \t\r\n\v\f-123suffix','+ 2','--3','foo','é12','\u00a012','12\0'+'34']
strings += [str(n) for n in [-4294967297,-2147483649,-2147483648,-2147483647,2147483646,2147483647,2147483648,4294967295,4294967296,10**80,-10**80]]
rows += [run(dict(mode='atoi',text=text)) for text in strings]
rows += [run(dict(mode='associate',exists=e,master=master,associate=associate)) for e,master,associate in itertools.product([False,True],[0x7f000000,0,0x80000001],[0,1,3,7,8,65535,65539])]
rows += [run(dict(mode='sitting',exists=e,occupant=occupant)) for e,occupant in itertools.product([False,True],[0,0x7f000000,0x80000001,0xffffffff])]
vectors=[[0.,0.,0.],[1.,0.,0.],[-1.,0.,0.],[1.,-0.,0.],[-1.,-0.,0.],[0.,1.,0.],[0.,-1.,0.],[0.,0.,1.]]
vectors += [[math.cos(math.radians(angle))*scale,math.sin(math.radians(angle))*scale,0.] for angle,scale in itertools.product([n*.5+delta for n in range(720) for delta in [-.00001,0.,.00001]],[1.])]
rng=random.Random(173);vectors += [[rng.uniform(-100,100) for _ in range(3)] for n in range(64)]
rows += [run(dict(mode='facing',exists=True,objectType=5,orientation=vector)) for vector in vectors]
rows += [run(dict(mode='facing',exists=e,objectType=t,orientation=[1.,1.,0.])) for e,t in itertools.product([False,True],[3,4,5,9,10,14])]
for mode in ['creature-orientation','waypoint-orientation']:
    rows += [run(dict(mode=mode,XOrientation=vector[0],YOrientation=vector[1],ZOrientation=vector[2])) for vector in vectors[:8]+vectors[-64:]]
rows += [run(dict(mode='bearing-orientation',Bearing=angle)) for angle in [0.,-0.,.00001,*[n*.125 for n in range(-64,65)]]]
out=m.root/'backups/animations/native-campaign-query-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2));print(json.dumps(dict(output=str(out),rows=len(rows))))
