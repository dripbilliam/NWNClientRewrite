"""Original control support owners: GetIsImmune5271d0, ambient39db40,
floaty broadcast439ae0. VM/object/dead/dying/immunity, spatial/client and
message delivery are captured lower owners. Branches, native field widths,
3D FLOAT recipient arithmetic and ambient body selection execute unchanged.
"""
import importlib.util,itertools,json,struct
from pathlib import Path
spec=importlib.util.spec_from_file_location('coordinator',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle);app,actor,source,stats,vtable,area,pool,viewers,clients=[m.heap+n*0x1000 for n in range(1,10)]
def hook(u,a,n,_):
    global output
    if a==m.stop:u.emu_stop();return
    x,y,z,w=[u.reg_read(reg) for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
    if a in [0x140286110,0x140286160]:m.wi(y,args.pop(0));m.finish(1)
    elif a==0x140286410:output=y&0xffffffff;m.finish(1)
    elif a==0x14055b3d0:m.finish(source if y==98 and c.get('sourceExists',True) else 0)
    elif a==0x14055b850:m.finish(app)
    elif a==0x140296470:
        ptr=actor if y==99 else viewers+(y-100)*0x200
        exists=c.get('exists',True) if y==99 else c['viewers'][y-100].get('exists',True)
        m.wq(z,ptr);m.finish(0 if exists else 1)
    elif a==m.stop+0x10:m.finish(actor if c.get('objectType',5)==5 else 0)
    elif a==m.stop+0x20:calls.append(['animation',y,m.si(actor+0x6b4)&255]);m.finish()
    elif a==0x140400ab0:calls.append(['immunity',y&255, bool(z),w&0xffffffff]);m.finish(c.get('immune',1))
    elif a==0x1404953b0:m.finish(c.get('dead',0))
    elif a==0x140495620:m.finish(c.get('dying',0))
    elif a==0x140494e80:m.finish(area if c.get('area',True) else 0)
    elif a==0x14035e820:
        first=c.get('first',0)
        if first is None:m.finish(0)
        else:m.wi(y,first);m.finish(1)
    elif a==0x14055b390:
        index=y-100;m.finish(clients+index*0x100 if c['viewers'][index].get('client',True) else 0)
    elif a==0x14055b810:m.finish(app)
    elif a==0x1404d95a0:calls.append(['floaty',m.si(y+0x48)&0xffffffff,z&0xffffffff,w&0xffffffff]);m.finish()
    elif not any(lo<=a<hi for lo,hi in [(0x1405271d0,0x140527305),(0x14039db40,0x14039dbbf),(0x140439ae0,0x140439d24)]):raise AssertionError(f'Uncaptured control support dependency {a:x} case={c}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
    global c,calls,args,output
    c=case;calls=[];args=[];output=None;u.mem_write(m.heap,bytes(0x100000));m.wq(0x1412df910,app);m.wq(0x1412df970,app);m.wq(app+8,app);m.wq(actor,vtable);m.wq(vtable+0x60,m.stop+0x10);m.wq(vtable+0x100,m.stop+0x20);m.wq(actor+0xad0,stats);u.mem_write(actor+0xc,bytes([c.get('objectType',5)]));m.wi(actor+8,99)
    u.mem_write(actor+0x771,bytes([c.get('state',0)&255]));u.mem_write(actor+0x6b4,bytes([c.get('body',0)&255]));m.wi(actor+0x82c,c.get('chair',0x7f000000));u.mem_write(actor+0x268,struct.pack('<f',c.get('radius',45)));u.mem_write(actor+0xa4,struct.pack('<3f',*c.get('position',[0,0,0])));m.wq(area+0x228,pool);m.wi(area+0x230,len(c.get('viewers',[])))
    for i,v in enumerate(c.get('viewers',[])):
        ptr=viewers+i*0x200;m.wi(pool+i*4,100+i);m.wi(ptr+8,100+i);u.mem_write(ptr+0xc,bytes([v.get('type',5)]));u.mem_write(ptr+0xa4,struct.pack('<3f',*v.get('position',[0,0,0])));m.wi(clients+i*0x100+0x48,100+i);m.wi(clients+i*0x100+0x38,1)
    rsp=m.stack+0x1fe08;u.mem_write(rsp-0x200,bytes(0x300));m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
    if c['mode']=='immune':args=[99,c.get('category',13)]+([98] if c.get('argc',3)>=3 else []);entry=0x1405271d0;regs=[app,274,c.get('argc',3)]
    elif c['mode']=='ambient':entry=0x14039db40;regs=[actor,0,0]
    else:entry=0x140439ae0;regs=[app,c.get('strref',2242),99]
    for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8],regs):u.reg_write(reg,value)
    u.emu_start(entry,m.stop,count=15000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
    return dict(case=c,calls=calls,result=output,body=u.mem_read(actor+0x6b4,1)[0])
rows=[]
for category,type,sourceExists in itertools.product([-2147483648,-1,0,1,13,32,33,256,2147483647],[4,5,6],[False,True]):rows.append(run(dict(mode='immune',category=category,objectType=type,sourceExists=sourceExists)))
for argc,immune in itertools.product([2,3],[0,1,2]):rows.append(run(dict(mode='immune',argc=argc,immune=immune)))
for state,body,dead,dying,chair in itertools.product([0,5,6,9,21],[0,3,4,5],[0,1],[0,1],[0,0x7f000000]):rows.append(run(dict(mode='ambient',state=state,body=body,dead=dead,dying=dying,chair=chair)))
for point,type,client in itertools.product([[0,0,0],[45,0,0],[45.001,0,0],[0,0,45],[27,36,0],[27,36,.1]],[4,5,6],[False,True]):rows.append(run(dict(mode='floaty',viewers=[dict(position=point,type=type,client=client)])))
for extra in [dict(area=False),dict(first=None),dict(viewers=[dict(position=[46,0,0]),dict(position=[0,0,0])]),dict(radius=0),dict(position=[1,2,3])]:rows.append(run(dict(mode='floaty',**extra)))
out=m.root/'backups/animations/native-control-support-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2)+'\n');print(json.dumps(dict(rows=len(rows),output=str(out))))
