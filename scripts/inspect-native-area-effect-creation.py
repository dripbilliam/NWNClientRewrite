"""Original area ApplyEffect35bdf0 AoE31 branch and attached OnApply427410.
VM effect-value readers/writers execute. Base construction, creator/DC,
load, anchor, orientation and AddToArea are captured lower boundaries.
Admission, metadata snapshot/reuse, source distinctions, callback override
and instance-ID writes execute original code. Not full-world acceptance.
"""
import importlib.util,itertools,json,struct
from pathlib import Path
spec=importlib.util.spec_from_file_location('coordinator',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle);app,area,actor,source,aoe,effect,ints,point,orientation,vt,svt,strings=[m.heap+n*0x2000 for n in range(1,13)]
def hook(u,a,n,_):
    global allocation
    if a==m.stop:u.emu_stop();return
    x,y,z,w=[u.reg_read(reg) for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
    if a==m.stop+0x10:m.finish(actor if c.get('targetType',5)==5 else 0)
    elif a==m.stop+0x20:m.finish(source if c.get('sourceType',5)==5 else 0)
    elif a==m.stop+0x30:m.finish(source if 5<=c.get('sourceType',5)<=14 else 0)
    elif a==0x1404953b0:m.finish(c.get('dead',0))
    elif a==0x14055b2f0:m.finish(aoe if c.get('existing',False) else 0)
    elif a==0x140c10324:m.finish(aoe)
    elif a==0x1404f59d0:calls.append(['construct']);m.finish(aoe)
    elif a==0x14055b4c0:m.finish(source if c.get('sourceExists',True) else 0)
    elif a==0x1403861c0:calls.append(['saveDC',y&0xffffffff]);m.finish(19)
    elif a==0x1404f91f0:
        calls.append(['creator',y&0xffffffff,z&0xffffffff,w&0xffffffff,u.mem_read(rsp+0x28,1)[0],u.mem_read(rsp+0x30,1)[0],m.si(rsp+0x38),int.from_bytes(u.mem_read(rsp+0x40,2),'little'),m.si(rsp+0x48)]);m.finish()
    elif a==0x140175070:m.finish(int(c.get('owned',False)))
    elif a==0x14008ae10:calls.append(['own',y&0xffffffff]);m.finish()
    elif a==0x1404f7e70:calls.append(['load',y&0xffffffff]);m.finish()
    elif a==0x1404f92d0:calls.append(['duration',y&255,m.xmm(UC_X86_REG_XMM2)]);m.finish()
    elif a==0x14049b910:calls.append(['orientation',list(struct.unpack('<3f',u.mem_read(y,12)))]);m.finish()
    elif a==0x140424690:m.finish(strings+(y&0xffffffff)*0x20)
    elif a==0x14003d8c0:
        index={0x368:0,0x348:1,0x378:2}[x-aoe];overrides[index]=bytes(u.mem_read(y,z&0xffffffff)).decode('ascii');m.finish()
    elif a==0x140494e80:m.finish(area if c.get('area',True) else 0)
    elif a==0x1404f93f0:calls.append(['anchor',y&0xffffffff]);m.finish()
    elif a==0x1404f6720:calls.append(['add',bool(y),[m.xmm(UC_X86_REG_XMM2),m.xmm(UC_X86_REG_XMM3),m.rf(rsp+0x28)],m.si(rsp+0x30)]);m.finish()
    elif a in [0x140423770,0x140c10360]:m.finish()
    elif not any(lo<=a<hi for lo,hi in [(0x14035bdf0,0x14035c241),(0x140427410,0x1404277d0),(0x140423fd0,0x140423fdb),(0x140423fc0,0x140423fcb),(0x140425210,0x14042521c),(0x140425300,0x14042530c)]):raise AssertionError(f'Uncaptured AoE creation dependency {a:x} {c}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
    global c,calls,overrides
    c=case;calls=[];overrides={};u.mem_write(m.heap,bytes(0x100000));m.wq(0x1412df970,app);m.wq(app+8,app);m.wq(actor,vt);m.wq(source,svt);m.wq(vt+0x60,m.stop+0x10);m.wq(svt+0x60,m.stop+0x20);m.wq(svt+0x20,m.stop+0x30);m.wi(actor+8,77);m.wi(aoe+8,101);u.mem_write(actor+0xa4,struct.pack('<3f',4,5,6));m.wi(source+0x22c,0x0203);m.wi(source+0x23c,123);m.wi(source+0x228,1)
    m.wq(effect+0x48,ints);m.wi(effect+0x40,8);u.mem_write(effect+8,struct.pack('<HH',31,(c.get('durationType',1)&7)|(c.get('subtype',8)&0x38)));m.wi(effect+0x18,99);m.wi(effect+0x1c,11);m.wi(effect+0x28,8);m.wf(effect+0xc,3.5);m.wi(effect+0xc0,0x7f000000)
    for i,value in enumerate(c.get('integers',[5,0,0,0,0,0,0,0])):m.wi(ints+i*4,value)
    for i,value in enumerate(c.get('strings',['','',''])):
        ptr=m.heap+0x30000+i*0x1000;raw=value.encode('ascii');u.mem_write(ptr,raw+b'\0');m.wq(strings+i*0x20,ptr);m.wi(strings+i*0x20+8,len(raw))
    u.mem_write(point,struct.pack('<3f',1,2,3));u.mem_write(orientation,struct.pack('<3f',0,1,0));rsp=m.stack+0x1fe08;u.mem_write(rsp-0x400,bytes(0x500));m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
    regs=[app,actor,effect,c.get('loading',0)] if c.get('attached',False) else [area,effect,point,orientation]
    for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],regs):u.reg_write(reg,value&0xffffffffffffffff)
    u.emu_start(0x140427410 if c.get('attached',False) else 0x14035bdf0,m.stop,count=10000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
    return dict(case=c,result=u.reg_read(UC_X86_REG_RAX)&0xffffffff if c.get('attached',False) else None,calls=calls,integers=[m.si(ints+i*4) for i in range(8)],instance=m.si(effect+0xc0)&0xffffffff,overrides=overrides)
rows=[]
for attached,sourceExists,sourceType,saved,subtype in itertools.product([False,True],[False,True],[3,5,9,11],[False,True],[8,16,24]):rows.append(run(dict(attached=attached,sourceExists=sourceExists,sourceType=sourceType,integers=[5,1 if saved else 0,7,8,21,456,3,0],subtype=subtype,strings=['enter_override','pulse_override','exit_override'])))
for targetType,loading,dead,durationType,existing in itertools.product([5,9],[0,1],[0,1],[0,1,2,3,4],[False,True]):rows.append(run(dict(attached=True,targetType=targetType,loading=loading,dead=dead,durationType=durationType,existing=existing)))
for attached in [False,True]:rows.append(run(dict(attached=attached,sourceExists=False,area=False)))
out=m.root/'backups/animations/native-area-effect-creation-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2)+'\n');print(json.dumps(dict(rows=len(rows),output=str(out))))
