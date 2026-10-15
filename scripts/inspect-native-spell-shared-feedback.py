"""Original Reflex damage, FloatingText STRREF and location-distance
wrappers, plus original creature floaty broadcast. VM/object/feat/save/RNG,
allocation/message containers, faction/client and evasion visual apply are
captured lower owners. Vector length executes original SSE arithmetic; only
its CRT sqrt boundary is captured. Legacy four-arg DC scratch is evidence,
never an invented live default. Native branches/order/INT division execute.
"""
import importlib.util,itertools,json,struct,math
from pathlib import Path
spec=importlib.util.spec_from_file_location('coordinator',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle);app,actor,stats,vtable,message,loc1,loc2,faction,ids,client,viewer=[m.heap+n*0x1000 for n in range(1,12)]
def data(ptr):return messages.setdefault(ptr,dict(objectIds=[],integers=[]))
def hook(u,a,n,_):
    global output,allocation
    if a==m.stop:u.emu_stop();return
    x,y,z,w=[u.reg_read(reg) for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
    if a in [0x140286110,0x140286160]:m.wi(y,args.pop(0));m.finish(1)
    elif a==0x140286030:m.wq(z,loc1 if not locations else loc2);locations.append(1);m.finish(1)
    elif a==0x140286410:output=y&0xffffffff;m.finish(1)
    elif a==0x1402863b0:output=u.reg_read(UC_X86_REG_XMM1)&0xffffffff;m.finish(1)
    elif a in [0x14055b3d0,0x14055b4c0]:m.finish(actor if c.get('exists',True) and (a==0x14055b4c0 or c.get('objectType',5)==5) else 0)
    elif a==m.stop+0x10:m.finish(actor if c.get('world',True) else 0)
    elif a==m.stop+0x20:calls.append(['broadcast',data(y)]);m.finish()
    elif a==0x14040b900:calls.append(['feat',y&65535]);m.finish(c.get('featResult',1) if (y&65535) in c.get('feats',[]) else 0)
    elif a==0x1403ec600:calls.append(['save',y&255,z&65535,w&255,m.si(rsp+0x28)&0xffffffff,m.si(rsp+0x30),m.si(rsp+0x38)&65535,m.si(rsp+0x40)]);m.finish(c.get('save',1))
    elif a==0x140c10324:allocation+=1;m.finish(message+allocation*0x300)
    elif a==0x1404233d0:m.wq(x+0x48,x+0x200);m.finish(x)
    elif a==0x140425110:m.wi(x+0x18,y);m.finish()
    elif a==0x14048e350:calls.append(['visual',m.si(m.q(y+0x48)),m.si(y+0x18)&0xffffffff]);m.finish(1)
    elif a in [0x1402da730,0x1402da770]:
        key='integers' if a==0x1402da730 else 'objectIds';values=data(x)[key];index=y&0xffffffff
        while len(values)<=index:values.append(0)
        values[index]=z&0xffffffff if key=='objectIds' else z if z<0x80000000 else z-0x100000000;m.finish()
    elif a in [0x140c10360,0x140c10370,0x14050c920]:m.finish()
    elif a==0x14055b390:m.wi(client+0x48,y);m.finish(client if c.get('client',True) else 0)
    elif a==0x14055b810:m.finish(app)
    elif a==0x1404cf090:calls.append(['send',y&0xffffffff,z&255,data(w)]);m.finish()
    elif a==0x140c7d6d8:u.reg_write(UC_X86_REG_XMM0,int.from_bytes(struct.pack('<f',math.sqrt(m.xmm(UC_X86_REG_XMM0))),'little'));m.finish()
    elif a==0x1403d51d0:m.finish(faction if c.get('faction',True) else 0)
    elif a==0x1404ae600:m.wq(y,ids);m.finish()
    elif a==0x1404ba840:m.finish(viewer if c.get('viewer',True) else 0)
    elif not any(lo<=a<hi for lo,hi in [(0x14052f790,0x14052f9f9),(0x14051d9d0,0x14051dc61),(0x140522750,0x140522838),(0x1402303d0,0x14023040d),(0x140425210,0x14042521c),(0x140383e60,0x140384000)]):raise AssertionError(f'Uncaptured shared feedback dependency {a:x} case={c}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
    global c,calls,args,locations,output,allocation,messages
    c=case;calls=[];locations=[];allocation=0;messages={};output=None;u.mem_write(m.heap,bytes(0x100000));m.wq(0x1412df910,app);m.wq(0x1412df970,app);m.wq(app+8,app);m.wq(actor+0xad0,stats);m.wq(actor,vtable);m.wq(vtable+0x20,m.stop+0x10);m.wq(vtable+0x1b8,m.stop+0x20);u.mem_write(actor+0xc,bytes([c.get('objectType',5)]))
    u.mem_write(loc1,struct.pack('<3f',*c.get('from',[1,2,3])));u.mem_write(loc2,struct.pack('<3f',*c.get('to',[4,6,7])));m.wi(loc1+0x18,c.get('area1',99));m.wi(loc2+0x18,c.get('area2',99))
    m.wi(actor+0xa0,99);u.mem_write(actor+0xa4,struct.pack('<3f',0,0,0));m.wi(viewer+0xa0,c.get('viewerArea',99));u.mem_write(viewer+0xa4,struct.pack('<3f',*c.get('point',[30,0,0])));m.wi(faction+8,2);m.wi(ids,100);m.wi(ids+4,100)
    rsp=m.stack+0x1fe08;u.mem_write(rsp-0x300,bytes(0x400));m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
    mode=c['mode'];argc=c.get('argc',5)
    if mode=='reflex':args=[99,c.get('damage',11),c.get('category',15),101] if argc==4 else [c.get('damage',11),99,c.get('dc',10),c.get('category',15),101];m.wi(rsp-0x30,c.get('dcScratch',99));entry=0x14052f790;x,y,z=app,179,argc
    elif mode=='floating':args=[c.get('strRef',123),99]+([c.get('display',1)] if argc>=3 else [])+([c.get('sound',1)] if argc>=4 else []);entry=0x14051d9d0;x,y,z=app,525,argc
    elif mode=='distance':args=[];entry=0x140522750;x,y,z=app,0,2
    else:args=[];messages[message]=dict(objectIds=[99],integers=[123,1]+[0]*7+[93]);entry=0x140383e60;x,y,z=actor,message,0
    for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8],[x,y,z]):u.reg_write(reg,value)
    u.emu_start(entry,m.stop,count=15000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
    if mode=='reflex' and output>=0x80000000:output-=0x100000000
    return dict(case=c,result=output,calls=calls)
rows=[]
for feats,save,damage,argc in itertools.product([[],[206],[212],[206,212]],[0,1,2,255],[-2147483648,-11,-1,0,1,11,2147483647],[4,5]):rows.append(run(dict(mode='reflex',feats=feats,save=save,damage=damage,argc=argc)))
for key,values in [('exists',[False]),('objectType',[4,6]),('dc',[-1,65536]),('category',[-1,256]),('featResult',[2])]:
    for value in values:rows.append(run(dict(mode='reflex',feats=[212],**{key:value})))
for argc,display,sound,type in itertools.product([2,3,4],[-1,0,1,2],[-1,0,1,2],[4,5,6]):rows.append(run(dict(mode='floating',argc=argc,display=display,sound=sound,objectType=type)))
for area1,area2,point in itertools.product([0,99,0x7f000000],[0,99,0x7f000000],[[0,0,0],[.1,.2,.3],[10000,20000,30000]]):rows.append(run(dict(mode='distance',area1=area1,area2=area2,to=point)))
for key,values in [('faction',[False]),('client',[False]),('viewer',[False]),('viewerArea',[100]),('point',[[29.999,0,0],[30,0,0],[30.001,0,0],[0,0,31]])]:
    for value in values:rows.append(run(dict(mode='broadcast',**{key:value})))
out=m.root/'backups/animations/native-spell-shared-feedback-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2)+'\n');print(json.dumps(dict(rows=len(rows),output=str(out))))
