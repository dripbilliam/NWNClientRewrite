"""Read-only build89 original random-walk command/action, GetLocked,
location area accessor and AI removal bodies. Synthetic canonical pointers;
VM pop/push, object lookup/casts, action allocation/disposal, CRT draws,
height/direct line/movement and vector math are explicit captured helpers.
Does not prove native geometry, allocator, VM copies or libm parity.
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
actor,node,area,app,path,queued,vm,location,vt,master,ids=[heap+n*0x2000 for n in range(11)]
def i(a):return int.from_bytes(u.mem_read(a,4),'little')
def si(a):return struct.unpack('<i',u.mem_read(a,4))[0]
def q(a):return int.from_bytes(u.mem_read(a,8),'little')
def wi(a,v):u.mem_write(a,struct.pack('<I',v&0xffffffff))
def wq(a,v):u.mem_write(a,struct.pack('<Q',v))
def f(v):return struct.unpack('<f',struct.pack('<f',v))[0]
def rf(a):return struct.unpack('<f',u.mem_read(a,4))[0]
def point(p):return list(struct.unpack('<fff',u.mem_read(p,12)))
def setpoint(p,v):u.mem_write(p,struct.pack('<fff',*v))
def xm(r):return struct.unpack('<f',u.reg_read(r).to_bytes(16,'little')[:4])[0]
def setxm(r,v):u.reg_write(r,int.from_bytes(struct.pack('<f',v),'little'))
def finish(v=0):
    rsp=u.reg_read(UC_X86_REG_RSP);u.reg_write(UC_X86_REG_RIP,q(rsp));u.reg_write(UC_X86_REG_RSP,rsp+8);u.reg_write(UC_X86_REG_RAX,v&0xffffffffffffffff)
def hook(u,a,n,_):
    global disposed,draws,lines,pushed
    if a==stop:u.emu_stop();return
    x,y,z,w=[u.reg_read(r) for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
    if a in [0x14055b2e0,0x140494e80]:finish(area if c.get('hasArea',True) else 0)
    elif a==0x14055b850:finish(app)
    elif a==0x14055b6c0:finish(actor if c.get('found') and c.get('kind')=='item' else 0)
    elif a==0x140296470:wq(z,actor);finish(int(not c.get('found',True)))
    elif a==0x140286160:wi(y,123);finish(1)
    elif a==0x140286030:wq(z,location);finish(1)
    elif a in [0x140286410,0x140286470]:pushed=y&0xffffffff;finish(1)
    elif a==stop+0x100:finish(actor if c.get('kind')=='door' else 0)
    elif a==stop+0x108:finish(actor if c.get('kind')=='placeable' else 0)
    elif a==0x1401692a0:
        disposed+=1;calls.append(['dispose',disposed]);wq(queued,1 if disposed<c['queued'] else 0);finish(node+disposed*0x100)
    elif a in [0x14048c470,0x140c10360]:finish()
    elif a in [0x14048cb80,0x14048d3f0]:
        params=[]
        if w:
            params.append([w&0xffffffff,si(q(rsp+0x28))])
            for k in range(11):
                t=i(rsp+0x30+k*16)
                if not t:break
                params.append([t,si(q(rsp+0x38+k*16))])
        calls.append(['action',y&0xffffffff,z&0xffff,params]);finish()
    elif a==0x140c7ed00:calls.append(['rand',c['draws'][draws]]);finish(c['draws'][draws]);draws+=1
    elif a==0x14036a210:calls.append(['height',point(y)]);setxm(UC_X86_REG_XMM0,c['height']);finish()
    elif a in [0x1402303d0,0x140230920]:
        v=point(x if a==0x1402303d0 else y);sq=f(f(f(v[0]*v[0])+f(v[1]*v[1]))+f(v[2]*v[2]))
        if a==0x1402303d0:setxm(UC_X86_REG_XMM0,math.sqrt(sq));finish()
        else:
            out=v if f(.99999)<=sq<=f(1.00001) else [1,0,0] if sq==0 else [f(n*f(math.sqrt(f(1/sq)))) for n in v]
            setpoint(x,out);finish(x)
    elif a==0x140371d30:
        calls.append(['line',[xm(UC_X86_REG_XMM1),xm(UC_X86_REG_XMM2)],[xm(UC_X86_REG_XMM3),rf(rsp+0x28)],rf(rsp+0x30),rf(rsp+0x38),i(rsp+0x40)])
        finish(int(lines>=c['blocked']));lines+=1
    elif a==0x14037fae0:
        calls.append(['move',y&0xffff,point(z),w&0xffffffff]+[i(rsp+0x28),i(rsp+0x30),rf(rsp+0x38),rf(rsp+0x40)]+[i(rsp+off) for off in [0x48,0x50,0x58,0x60,0x68,0x70]]);finish()
    elif a==0x140c417f0:u.mem_write(x,bytes(u.mem_read(y,z)));finish(x)
    elif not any(lo<=a<hi for lo,hi in [(0x1403c77b0,0x1403c844f),(0x14050e880,0x14050e9f1),(0x14052b4c0,0x14052b583),(0x14051f910,0x14051f97f),(0x140535600,0x140535711),(0x1405595b0,0x1405596ae)]):raise RuntimeError(f'Unmapped wandering dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case,entry):
    global c,calls,disposed,draws,lines,pushed
    c=case;calls=[];disposed=draws=lines=0;pushed=None
    u.mem_write(heap,bytes(0x100000));wq(0x1412df970,app);wq(app+8,app);wq(0x1412df910,vm)
    u.mem_write(0x14141e310,bytes(32));wq(actor,vt);wq(vt+0x30,stop+0x100);wq(vt+0x98,stop+0x108)
    wi(actor+8,123);wi(actor+0x7c,c.get('level',1));wi(actor+0x80,1);wi(actor+0xec,c.get('commandable',1));wi(vm+8,c.get('selfValid',1));wi(vm+0xc,123)
    wq(actor+0x530,path if c.get('hasPath',True) else 0);wq(actor+0x100,queued);wq(queued,int(c.get('queued',0)>0));u.mem_write(path+4,struct.pack('<f',.5));u.mem_write(path+0xc,struct.pack('<f',1.7))
    setpoint(actor+0xa4,c.get('position',[1,2,3]));setpoint(location,[1,2,3]);wi(location+0x18,c.get('areaId',77));wi(area+0x140,77)
    wi(actor+0x424,c.get('locked',0));wi(actor+0x378,c.get('locked',0))
    wi(actor+0x40,c.get('baseItem',0))
    origin=c.get('origin',[3,4,5])
    for k,v in enumerate(origin):u.mem_write(node+0x38+k*8,struct.pack('<f',v))
    wi(node+0x50,77);u.mem_write(node+0x98,struct.pack('<H',9))
    for level in range(5):wq(master+level*24+8,ids+level*0x200);wi(master+level*24+0x10,len(c.get('ids',[])));wi(master+level*24+0x14,7)
    for level in range(5):
        for k,value in enumerate(c.get('ids',[])):wi(ids+level*0x200+k*4,value)
    rsp=stack+0xff08;u.mem_write(rsp-0x3000,bytes(0x3080));wq(rsp,stop);u.reg_write(UC_X86_REG_RSP,rsp)
    u.reg_write(UC_X86_REG_RCX,master if entry==0x1405595b0 else vm if entry!=0x1403c77b0 else actor)
    u.reg_write(UC_X86_REG_RDX,actor if entry==0x1405595b0 else node if entry==0x1403c77b0 else 224)
    try:u.emu_start(entry,stop,count=30000)
    except Exception:print(json.dumps({'case':c,'rip':hex(u.reg_read(UC_X86_REG_RIP)),'calls':calls}));raise
    assert u.reg_read(UC_X86_REG_RIP)==stop
    out={'case':c,'result':u.reg_read(UC_X86_REG_RAX)&0xffffffff,'calls':calls}
    if entry in [0x14052b4c0,0x140535600,0x14051f910]:out['pushed']=pushed
    if entry==0x1405595b0:
        level=c['level']
        out.update(level=si(actor+0x7c),lock=i(actor+0x80),lists=[[i(ids+n*0x200+k*4) for k in range(i(master+n*24+0x10))] for n in range(5)],cursors=[i(master+n*24+0x14) for n in range(5)])
    return out
default=dict(hasArea=True,hasPath=True,queued=2,level=1,position=[1,2,3],origin=[3,4,5],draws=[0,14],height=4,blocked=0)
walk=[]
for level,queued_count,draw_values,blocked,position in itertools.product([-1,0,1,4],[0,2],[[0,14],[7,7],[32767,0]],[0,1,5,100],[[1,2,3],[3,4,4]]):walk.append(run(default|dict(level=level,queued=queued_count,draws=draw_values,blocked=blocked,position=position),0x1403c77b0))
for area_flag,path_flag in [(False,True),(True,False)]:walk.append(run(default|dict(hasArea=area_flag,hasPath=path_flag),0x1403c77b0))
commands=[run(dict(selfValid=valid,found=found,hasArea=area_flag,commandable=commandable),0x14050e880) for valid,found,area_flag,commandable in itertools.product([0,1],[False,True],[False,True],[0,1,2])]
locks=[run(dict(found=found,kind=kind,locked=value),0x14052b4c0) for found,kind,value in itertools.product([False,True],['door','placeable','creature'],[-1,0,1,2,2147483647])]
locations=[run(dict(areaId=value),0x140535600) for value in [0,77,0x7f000000,0x80000001,0xffffffff]]
removals=[]
for level,count,placement in itertools.product([-1,0,1,4,5],[0,1,16,17,24],['none','first','last','both']):
    values=list(range(1000,1000+count))
    if count and placement in ['first','both']:values[0]=123
    if count and placement in ['last','both']:values[-1]=123
    removals.append(run(dict(level=level,ids=values),0x1405595b0))
baseitems=[run(dict(found=found,kind=kind,baseItem=value),0x14051f910) for found,kind,value in itertools.product([False,True],['item','creature'],[0,24,256,-1,0x80000001])]
out=root/'backups/animations/native-wandering-observations.json';out.write_text(json.dumps(dict(binarySha256=digest,limits=__doc__,walk=walk,commands=commands,locks=locks,locations=locations,removals=removals,baseitems=baseitems),indent=2));print(json.dumps(dict(output=str(out),counts=[len(x) for x in [walk,commands,locks,locations,removals,baseitems]])))
