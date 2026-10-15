"""Original AoE InAreaOfEffect4f78f0, closest-segment231aa0,
UpdateSubAreas4f94c0, SetAnchor4f93f0 and event-handler noninstrumented tail.
Registry/cast/area-X-index and mutable list operations are captured lower
boundaries; original FLOAT geometry, scan ordering and event decisions run.
The AddToArea rectangle arithmetic and RemoveFromSubAreas scan also run;
their spatial insertion/delivery boundaries remain captured. No game process,
complete destruction or rendering acceptance.
"""
import importlib.util,itertools,json,struct,math
from pathlib import Path
spec=importlib.util.spec_from_file_location('coordinator',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
app,aoe,area,vm,vt,cv,spatial,point,start,end,out,payload=[m.heap+n*0x2000 for n in range(1,13)]
def hook(u,a,n,_):
    global code,lastObject,intReads,output
    if a==m.stop:u.emu_stop();return
    x,y,z,w=[u.reg_read(reg) for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
    if a==0x140494e80:m.finish(area if c.get('area',True) else 0)
    elif a==0x14055b850:m.finish(vm)
    elif a==0x14055b960:m.finish(app)
    elif a==0x140296470:
        obj=aoe if (y&0xffffffff)==101 else objects.get(y&0xffffffff,0);m.wq(z,obj);m.finish(0 if obj else 1)
    elif a in [m.stop+0x10,m.stop+0x20,m.stop+0x50,m.stop+0x60]:m.finish(x if a==m.stop+0x10 or a==m.stop+0x20 and u.mem_read(x+0xc,1)[0]==5 or a==m.stop+0x50 and x==aoe else 0)
    elif a==0x14049ae60:calls.append(['setArea',m.si(y+8) if y else None]);m.finish()
    elif a==0x14035ba90:calls.append(['addObject',y&0xffffffff,z&0xffffffff]);m.finish()
    elif a==0x140364cc0:calls.append(['removeObject',y&0xffffffff]);m.finish()
    elif a==m.stop+0x40:calls.append(['fieldD8',y&0xffffffff]);m.finish()
    elif a==m.stop+0x70:calls.append(['dispatchExit',int.from_bytes(u.mem_read(w,2),'little'),lastObject]);m.finish()
    elif a==0x1404f94c0 and c['mode']=='add':calls.append(['updateSubareas']);m.finish()
    elif a==0x140c7d6d8:u.reg_write(UC_X86_REG_XMM0,int.from_bytes(struct.pack('<f',math.sqrt(m.xmm(UC_X86_REG_XMM0))),'little'));m.finish()
    elif a==0x140286160:m.wi(y,101);m.finish(1)
    elif a==0x140286110:m.wi(y,[c.get('filter',1),c.get('zone',0)][intReads]);intReads+=1;m.finish(1)
    elif a==0x140286470:output=y&0xffffffff;m.finish(1)
    elif a==0x140402f80:m.finish(int(m.si(x+8)==c.get('dm',-1)))
    elif a==0x1404953b0:m.finish(int(m.si(x+8) in c.get('dead',[])))
    elif a==0x14035e820:
        threshold=m.xmm(UC_X86_REG_XMM2);index=next((i for i,obj in enumerate(ordered) if m.rf(obj+0xa4)>=threshold),len(ordered));calls.append(['first',threshold]);m.wi(y,index);m.finish(int(index<len(ordered)))
    elif a in [0x140175070,0x140174af0,0x14008ae10,0x1400b5450]:
        values=lists.setdefault(x,[]);id=y&0xffffffff
        if a==0x140175070:m.finish(int(id in values))
        else:
            calls.append(['append' if a in [0x140174af0,0x14008ae10] else 'remove',listOwners[x],id])
            if a in [0x140174af0,0x14008ae10]:values.append(id)
            elif id in values:values.remove(id)
            m.finish()
    elif a==0x140c10324:m.finish(payload)
    elif a==0x1404c6490:m.finish(x)
    elif a==0x1404c7320:lastObject=z&0xffffffff;m.finish()
    elif a==0x1405570b0:calls.append(['event',w&0xffffffff,m.si(rsp+0x28)&0xffffffff,int.from_bytes(u.mem_read(payload,2),'little'),lastObject]);m.finish()
    elif a==0x1404c6b10:m.finish(c.get('actor',7))
    elif a==0x1404998a0:calls.append(['script',y&0xffffffff,z&0xffffffff]);m.finish()
    elif a in [0x1404c64d0,0x140c10360]:m.finish()
    elif a==0x1404f8bb0:calls.append(['removeFromArea']);m.finish()
    elif a==m.stop+0x30:calls.append(['destroy']);m.finish()
    elif not any(lo<=a<hi for lo,hi in [(0x1404f7b90,0x1404f7e62),(0x140297860,0x140297bbf),(0x1404f6720,0x1404f6b11),(0x140230920,0x1402309f5),(0x1404f8bb0,0x1404f8dfd),(0x1404f92d0,0x1404f92f2),(0x140525fc0,0x1405267df),(0x1404f78f0,0x1404f7a62),(0x14022fba0,0x14022fbfa),(0x140231aa0,0x140231c16),(0x1404f94c0,0x1404f9a2d),(0x1404f7830,0x1404f78ee),(0x1404f93f0,0x1404f94b2),(0x1404f76e1,0x1404f781d)]):raise AssertionError(f'Uncaptured AoE overlap dependency {a:x} {c}')
u.hook_add(UC_HOOK_CODE,hook)
def vec(a,v):u.mem_write(a,struct.pack('<3f',*v))
def run(case):
    global c,calls,objects,ordered,lists,listOwners,lastObject,intReads,output
    c=case;calls=[];objects={};ordered=[];lists={area+0x240:[]};listOwners={area+0x240:77};lastObject=intReads=0;output=None;u.mem_write(m.heap,bytes(0x100000));m.wq(0x1412df970,app);m.wq(0x1412df910,vm);m.wq(app+8,app);m.wq(aoe,vt);m.wq(vt,m.stop+0x30);m.wq(vt+0x100,m.stop+0x40);m.wq(vt+0xc0,m.stop+0x60);m.wq(vt+0x80,m.stop+0x60);m.wq(vt+0xa8,m.stop+0x50);m.wq(vt+0xf8,m.stop+0x70);m.wq(cv+0x20,m.stop+0x10);m.wq(cv+0x60,m.stop+0x20);m.wi(aoe+8,101);m.wi(area+8,77);m.wi(aoe+0x334,c.get('anchor',0x7f000000));u.mem_write(aoe+0x310,bytes([c.get('shape',0)]));m.wf(aoe+0x318,c.get('radius',2));m.wf(aoe+0x31c,c.get('width',4));m.wf(aoe+0x320,c.get('length',6));m.wi(aoe+0x390,1234);m.wi(aoe+0x308,c.get('cursor',0));vec(aoe+0xa4,c.get('center',[0,0,0]));vec(aoe+0xb0,c.get('orientation',[1,0,0]));m.wq(aoe+0x328,m.heap+0x60000)
    vertices=c.get('vertices',[[2,2,0],[2,-2,0],[-2,-2,0],[-2,2,0]])
    for i,v in enumerate(vertices):vec(m.heap+0x60000+i*12,v)
    for i,item in enumerate(c.get('objects',[])):
        obj=m.heap+0x40000+i*0x2000;id=item['id'];objects[id]=obj;ordered.append(obj);m.wq(obj,cv);m.wq(obj+0xad0,obj);m.wi(obj+8,id);u.mem_write(obj+0xc,bytes([item.get('type',5)]));vec(obj+0xa4,item['position']);lists[obj+0x518]=list(item.get('membership',[]));listOwners[obj+0x518]=id;lists[obj+0x508]=list(item.get('following',[]));listOwners[obj+0x508]=id
    ordered.sort(key=lambda o:m.rf(o+0xa4));m.wq(area+0x228,spatial);m.wi(area+0x230,len(ordered))
    for i,obj in enumerate(ordered):m.wi(spatial+i*4,m.si(obj+8))
    rsp=m.stack+0x1f008;u.mem_write(rsp-0x800,bytes(0x1000));m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
    if c['mode']=='contains':entry=0x1404f78f0;vec(point,c['point']);regs=[aoe,point,0,0]
    elif c['mode']=='crossing':entry=0x1404f7b90;vec(start,c['start']);vec(end,c['end']);regs=[aoe,start,end,0]
    elif c['mode']=='closest':entry=0x140231aa0;vec(start,c['start']);vec(end,c['end']);vec(point,c['point']);regs=[out,start,end,point]
    elif c['mode']=='anchor':entry=0x1404f93f0;regs=[aoe,c['newAnchor'],0,0]
    elif c['mode']=='add':
        entry=0x1404f6720;regs=[aoe,area if c.get('area',True) else 0,0,0];position=c.get('point',[3,4,5]);u.reg_write(UC_X86_REG_XMM2,int.from_bytes(struct.pack('<f',position[0]),'little'));u.reg_write(UC_X86_REG_XMM3,int.from_bytes(struct.pack('<f',position[1]),'little'));m.wf(rsp+0x28,position[2]);m.wi(rsp+0x30,1)
    elif c['mode']=='remove':entry=0x1404f8c40;regs=[aoe,c.get('synchronous',1),0,0]
    elif c['mode']=='duration':entry=0x1404f92d0;regs=[aoe,c.get('durationType',1),0,0];u.reg_write(UC_X86_REG_XMM2,int.from_bytes(struct.pack('<f',c['seconds']),'little'))
    elif c['mode']=='query':entry=0x140525fc0;regs=[app,262 if c.get('first',True) else 263,3,0]
    elif c['mode']=='event':
        entry=0x1404f76e1;regs=[0,0,0,0];u.reg_write(UC_X86_REG_RBP,rsp-0x180);u.reg_write(UC_X86_REG_RSI,aoe);u.reg_write(UC_X86_REG_R15,payload);m.wi(rsp-0x180+0x128,c.get('event',10));u.mem_write(payload,struct.pack('<H',c.get('code',12)));m.wi(aoe+0xf0,c.get('destroyable',1));u.mem_write(rsp+0x50,b'\0')
        # Enter through the nonprofiling semantic tail, restoring its own
        # prologue frame/return layout. Instrumentation branches are excluded.
        m.wq(rsp+0x1e0+7*8,m.stop)
    else:entry=0x1404f94c0;regs=[aoe,point if c.get('next') is not None else 0,0,0];vec(point,c.get('next') or [0,0,0])
    for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],regs):u.reg_write(reg,value&0xffffffffffffffff)
    u.emu_start(entry,m.stop,count=30000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
    return dict(case=c,result=(output if c['mode']=='query' else (int(u.reg_read(UC_X86_REG_RAX)&0xffffffff) if c['mode'] in ['contains','crossing'] else list(struct.unpack('<3f',u.mem_read(out,12))) if c['mode']=='closest' else None)),calls=calls,
      position=list(struct.unpack('<3f',u.mem_read(aoe+0xa4,12))),vertices=[list(struct.unpack('<3f',u.mem_read(m.heap+0x60000+i*12,12))) for i in range(4)],duration=m.si(aoe+0x390)&0xffffffff,durationType=u.mem_read(aoe+0x394,1)[0],cursor=int.from_bytes(u.mem_read(aoe+0x308,2),'little'),
      memberships={str(id):lists[obj+0x518] for id,obj in objects.items()},following={str(id):lists[obj+0x508] for id,obj in objects.items()},anchor=m.si(aoe+0x334)&0xffffffff,entering=m.si(aoe+0x338)&0xffffffff,exiting=m.si(aoe+0x33c)&0xffffffff)
rows=[]
for shape,radius,x,y,z in itertools.product([0,1],[0,2,3],[-3,-2,-.1,0,2,3],[-2,0,2],[0,1,3]):rows.append(run(dict(mode='contains',shape=shape,radius=radius,point=[x,y,z])))
for a,b in itertools.product([[0,0,0],[1,2,3],[-3,.1,7]],[[0,0,0],[3,4,5],[-1,-2,-3]]):
    for p in [[0,0,0],[1,2,3],[99,-99,7],[-1,.001,8]]:rows.append(run(dict(mode='closest',start=a,end=b,point=p)))
for shape,center,nextPoint,membership in itertools.product([0,1],[[0,0,0],[3,4,1]],[None,[6,0,0],[-6,0,0]], [[],[101]]):
    rows.append(run(dict(mode='overlap',shape=shape,center=center,next=nextPoint,objects=[dict(id=i+1,type=5 if i%3 else 9,position=[x,0,0],membership=membership) for i,x in enumerate([-9,-3,-2,0,1,2,3,7])])) )
for old,new in itertools.product([0x7f000000,1,2,3],[0x7f000000,1,2,3]):rows.append(run(dict(mode='anchor',anchor=old,newAnchor=new,objects=[dict(id=1,position=[0,0,0],following=[101]),dict(id=2,position=[2,0,0])])))
for event,code,destroyable in itertools.product([10,11],[12,13,2],[0,1]):rows.append(run(dict(mode='event',event=event,code=code,destroyable=destroyable)))
for shape,orientation,width,length in itertools.product([0,1],[[1,0,0],[0,1,0],[3,4,0],[1,2,3],[0,0,0]],[0,4,-2],[0,6]):rows.append(run(dict(mode='add',shape=shape,orientation=orientation,width=width,length=length)))
for synchronous,shape in itertools.product([0,1],[0,1]):rows.append(run(dict(mode='remove',synchronous=synchronous,shape=shape,objects=[dict(id=i+1,position=[x,0,0],membership=[101]) for i,x in enumerate([-3,-2,0,2,3])])))
for durationType,seconds in itertools.product([0,1,2,255,256],[-1,0,.001,1,1.001,1e20]):rows.append(run(dict(mode='duration',durationType=durationType,seconds=seconds)))
for first,cursor,filter,zone,dm,dead in itertools.product([False,True],[0,2,6],[1,64,32767],[0,1],[0,3],[[],[2]]):rows.append(run(dict(mode='query',first=first,cursor=cursor,filter=filter,zone=zone,dm=dm,dead=dead,objects=[dict(id=i+1,type=5 if i%2 else 9,position=[x,0,0]) for i,x in enumerate([-3,-2,0,1,2,3])])))
for shape,center,startPoint,endPoint in itertools.product([0,1],[[0,0,0],[2,3,1]],[[0,0,0],[-3,0,0],[0,-3,5],[3,-3,0]],[[0,0,0],[3,0,0],[0,3,9],[3,3,0]]):rows.append(run(dict(mode='crossing',shape=shape,center=center,start=startPoint,end=endPoint)))
for shape in [0,1]:rows.append(run(dict(mode='overlap',shape=shape,anchor=1,center=[0,0,0],next=[8,0,0],objects=[dict(id=1,position=[4,0,0]),dict(id=2,position=[7,0,0])])))
outpath=m.root/'backups/animations/native-area-effect-overlap-observations-v3.json';outpath.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2)+'\n');print(json.dumps(dict(rows=len(rows),output=str(outpath))))
