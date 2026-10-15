"""Read-only full build89 shape query and associate query bodies.
Synthetic typed canonical objects; VM pop/push, lookup/casts, first X index,
DM checks, normalization/magnitude and LOS captured. lineproject executes
unchanged. Validates geometry arithmetic/filter/order/shared cursor, not VM
copy ownership, native geometry LOS, mutation races or helper libm precision.
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
ctx,vm,app,area,location,vt,ids,self_actor,associate_list=[heap+n*0x1000 for n in range(9)]
def i(a):return int.from_bytes(u.mem_read(a,4),'little')
def si(a):return struct.unpack('<i',u.mem_read(a,4))[0]
def q(a):return int.from_bytes(u.mem_read(a,8),'little')
def wi(a,v):u.mem_write(a,struct.pack('<I',v&0xffffffff))
def wq(a,v):u.mem_write(a,struct.pack('<Q',v))
def f(v):return struct.unpack('<f',struct.pack('<f',v))[0]
def wf(a,v):u.mem_write(a,struct.pack('<f',v))
def rf(a):return struct.unpack('<f',u.mem_read(a,4))[0]
def point(a):return list(struct.unpack('<fff',u.mem_read(a,12)))
def setpoint(a,v):u.mem_write(a,struct.pack('<fff',*v))
def xm(r):return struct.unpack('<f',u.reg_read(r).to_bytes(16,'little')[:4])[0]
def setxm(r,v):u.reg_write(r,int.from_bytes(struct.pack('<f',v),'little'))
def finish(v=0):
    rsp=u.reg_read(UC_X86_REG_RSP);u.reg_write(UC_X86_REG_RIP,q(rsp));u.reg_write(UC_X86_REG_RSP,rsp+8);u.reg_write(UC_X86_REG_RAX,v&0xffffffffffffffff)
def hook(u,a,n,_):
    global intpop,los_index,pushed
    if a==stop:u.emu_stop();return
    x,y,z,w=[u.reg_read(r) for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
    if a==0x14055b850:finish(app)
    elif a==0x140286110:wi(y,ints[intpop]);intpop+=1;finish(1)
    elif a==0x1402860c0:wf(y,c['size']);finish(1)
    elif a==0x140286030:wq(z,location);finish(1)
    elif a==0x140286250:setpoint(y,c['origin']);finish(1)
    elif a==0x140286160:wi(y,10);finish(1)
    elif a==0x140286470:pushed=y&0xffffffff;finish(1)
    elif a==0x140296470:
        obj=area if y&0xffffffff==77 and c.get('hasArea',True) else self_actor if y&0xffffffff==10 and c.get('self',True) else pointers.get(y&0xffffffff,0);wq(z,obj);finish(int(obj==0))
    elif a==0x14055b3d0:
        obj=self_actor if y&0xffffffff==10 and c.get('self',True) else pointers.get(y&0xffffffff,0);finish(obj if obj==self_actor or objects.get(obj,{}).get('kind')==5 else 0)
    elif a==stop+0x100:finish(area if x==area else 0)
    elif a==stop+0x108:finish(x if objects.get(x,{}).get('kind')==5 else 0)
    elif a==0x140402f80:finish(objects[x]['dm'])
    elif a==0x14035e820:
        minimum=xm(UC_X86_REG_XMM2);calls.append(['first',minimum]);index=next((k for k,o in enumerate(c['objects']) if f(o['point'][0])>=minimum),None)
        if index is not None:wi(y,index)
        finish(int(index is not None))
    elif a==0x14035c590:
        calls.append(['los',point(y),point(z),i(rsp+0x30),i(rsp+0x38),i(rsp+0x40)]);finish(c['losResults'][los_index%len(c['losResults'])]);los_index+=1
    elif a in [0x1402303d0,0x140230920]:
        v=point(x if a==0x1402303d0 else y);sq=f(f(f(v[0]*v[0])+f(v[1]*v[1]))+f(v[2]*v[2]))
        if a==0x1402303d0:setxm(UC_X86_REG_XMM0,math.sqrt(sq));finish()
        else:
            out=v if f(.99999)<=sq<=f(1.00001) else [1,0,0] if sq==0 else [f(n*f(math.sqrt(f(1/sq)))) for n in v];setpoint(x,out);finish(x)
    elif a==0x140047300:setpoint(x,[0,0,0]);finish(x)
    elif a in [0x140c10360,0x140c10410]:finish()
    elif a==0x140115890:calls.append(['warning']);finish()
    elif not any(lo<=a<hi for lo,hi in [(0x14052d520,0x14052e26c),(0x140230220,0x140230338),(0x14051f370,0x14051f468),(0x140525bb0,0x140525c6a),(0x1403d4d70,0x1403d4e1a),(0x1403d51a0,0x1403d51c2)]):raise RuntimeError(f'Unmapped query dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case,associate=False):
    global c,calls,intpop,los_index,pushed,pointers,objects,ints
    c=case;calls=[];intpop=los_index=0;pushed=None;pointers={};objects={};u.mem_write(heap,bytes(0x100000));u.mem_write(0x14141e310,bytes(32));wq(0x1412df970,app);wq(app+8,app);wq(0x1412df910,vm);wq(ctx+0x10,vm);wi(ctx+0xc,10);wq(area,vt);wq(vt+0x50,stop+0x100);wq(vt+0x60,stop+0x108);wq(area+0x228,ids);wi(area+0x230,len(c['objects']));wi(area+0x238,c.get('cursor',3));setpoint(location,c.get('center',[1,2,3]));wi(location+0x18,77);setpoint(self_actor+0xa4,c.get('origin',[0,0,0]));wi(self_actor+8,10);wq(self_actor+0xad0,self_actor+0x500);wi(self_actor+0x500+0xb0,c.get('pc',1))
    for k,o in enumerate(c['objects']):
        p=heap+0x20000+k*0x1000;pointers[o['id']]=p;objects[p]=o;wq(p,vt);wi(p+8,o['id']);u.mem_write(p+0xc,bytes([o['kind']]));setpoint(p+0xa4,o['point']);wq(p+0xad0,p);u.mem_write(p+0x908,struct.pack('<H',o.get('associate',0)));wi(ids+k*4,o['id'])
    if associate:
        ints=[c['nth']] if c.get('henchman') else [c['type'],c['nth']];wq(self_actor+0x900,associate_list if c['list'] is not None else 0);wq(associate_list,ids+0x500);wi(associate_list+8,len(c['list'] or []))
        for k,id in enumerate(c['list'] or []):wi(ids+0x500+k*4,id)
    else:ints=[c['shape'],c['los'],c['filter']]
    rsp=stack+0xff08;u.mem_write(rsp-0x1000,bytes(0x1080));wq(rsp,stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,ctx);u.reg_write(UC_X86_REG_RDX,128 if c.get('first',True) else 129);u.reg_write(UC_X86_REG_R8,3)
    if c.get('henchman'):u.reg_write(UC_X86_REG_R8,c['argc'])
    entry=0x140525bb0 if c.get('henchman') else 0x14051f370 if associate else 0x14052d520
    try:u.emu_start(entry,stop,count=30000)
    except Exception:print(json.dumps({'case':c,'rip':hex(u.reg_read(UC_X86_REG_RIP)),'calls':calls}));raise
    assert u.reg_read(UC_X86_REG_RIP)==stop
    return dict(case=c,pushed=pushed,cursor=i(area+0x238),calls=calls)
objects_list=[dict(id=100+k,kind=kind,point=[f((k-7)*.7),f((k%3-1)*.5),f((k%2)*.3)],dm=int(k==8),associate=k%6+1) for k,kind in enumerate([5,6,7,10,11,12,9,14,5,13,5,6,5,5,5])]
default=dict(objects=objects_list,hasArea=True,self=True,center=[1,0,0],origin=[-1,0,0],size=3,los=0,filter=1,first=True,cursor=3,losResults=[1])
shapes=[]
for shape,size,filter_value,first,los_results in itertools.product(range(6),[0,1,3,-1],[1,2,0x7fff,64],[False,True],[[1],[0],[0,1]]):shapes.append(run(default|dict(shape=shape,size=size,filter=filter_value,first=first,los=int(los_results!=[1]),losResults=los_results)))
for shape,center,origin in itertools.product(range(5),[[0,0,0],[10,20,30],[1,2,3]],[[-1,0,0],[0,0,0],[10,20,30]]):shapes.append(run(default|dict(shape=shape,center=center,origin=origin,los=1,losResults=[0,1])))
shapes.append(run(default|dict(shape=4,hasArea=False)))
associates=[]
for self_flag,pc,type_value,nth,list_value in itertools.product([False,True],[0,1,2],[0,1,4,5,6,65537,-1],[-1,0,1,2,20],[None,[],[100,999,100,104,107,108,110,111,112]]):associates.append(run(dict(objects=objects_list,self=self_flag,pc=pc,type=type_value,nth=nth,list=list_value),True))
henchmen=[run(dict(objects=objects_list,self=self_flag,pc=1,type=1,nth=nth,list=list_value,henchman=True,argc=argc),True) for self_flag,argc,nth,list_value in itertools.product([False,True],[0,1,2],[-1,1,2],[None,[],[100,999,100,104,110]])]
out=root/'backups/animations/native-shape-associate-observations.json';out.write_text(json.dumps(dict(binarySha256=digest,limits=__doc__,shapes=shapes,associates=associates,henchmen=henchmen),indent=2));print(json.dumps(dict(output=str(out),shapes=len(shapes),associates=len(associates),henchmen=len(henchmen))))
