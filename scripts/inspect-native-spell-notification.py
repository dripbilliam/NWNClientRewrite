"""Untouched creature ScriptEvent2 branch14038f8a7..14038faa2.
Event accessors, object casts, script, combat/reputation owners are captured;
last-spell writes, exact harmful/dead/PC guards and call order execute native.
"""
import importlib.util,itertools,json,struct
from pathlib import Path
spec=importlib.util.spec_from_file_location('coordinator',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle);si,wi,wq=[getattr(m,n) for n in ['si','wi','wq']]
actor,source,creator,app,payload,vtable,nameStruct,nameText,stats=[m.heap+n*0x1000 for n in range(1,10)]
def owner(ptr):return 99 if ptr==actor else 100 if ptr==source else 101
def hook(u,a,n,_):
    if a==0x14038faed:u.emu_stop();return
    x,y,z=[u.reg_read(reg) for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8]]
    if a==0x1404c6b10:m.finish(100)
    elif a==0x14055b4c0:m.finish(source if c.get('exists',True) else 0)
    elif a==m.stop+0x10:m.finish(source)
    elif a==0x14055b3d0:m.finish((source if c.get('sourceType',5)==5 else creator if c.get('sourceType',5)==11 and c.get('creatorExists',True) else 0) if (y&0xffffffff)!=0x7f000000 else 0)
    elif a==0x1404c6af0:m.finish(c.get('spell',1) if (y&0xffffffff)==0 else c.get('harmful',1))
    elif a==0x14049b070:calls.append(['hostile',owner(x),y&0xffffffff,z&0xffffffff]);m.finish()
    elif a==0x1404953b0:m.finish(c.get('dead',0))
    elif a==m.stop+0x20:m.finish(nameStruct)
    elif a==0x140392ec0:m.finish(c.get('pc',0) if x==actor else c.get('casterPC',0))
    elif a==0x1404998a0:calls.append(['script',owner(x),y&0xffffffff]);m.finish()
    elif a==0x1403837d0:calls.append(['state',owner(x)]);m.finish()
    elif a==0x14039f100:calls.append(['initiative',owner(x)]);m.finish()
    elif a==0x1403a3000:calls.append(['excited',owner(x),y&255]);m.finish()
    elif a==0x14039e500:calls.append(['invisibility',owner(x)]);m.finish()
    elif a==0x14039e0d0:calls.append(['faction',owner(x),y&0xffffffff,z&0xffffffff]);m.finish()
    elif a==0x140382bb0:calls.append(['associate',owner(x),y&0xffffffff]);m.finish()
    elif a==0x14055b960:m.finish(app)
    elif a==0x140557660:calls.append(['reputations',y&0xffffffff,z&0xffffffff,u.reg_read(UC_X86_REG_R9)&0xffffffff]);m.finish()
    elif not 0x14038f8a7<=a<0x14038faed:raise AssertionError(f'Uncaptured spell notification dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
    global c,calls
    c=case;calls=[];u.mem_write(m.heap,bytes(0x100000));wq(0x1412df970,app);wq(app+8,app)
    wi(actor+8,99);wi(source+8,100);wi(creator+8,101);wi(source+0x330,101);u.mem_write(source+0xc,bytes([c.get('sourceType',5)]))
    for obj in [source,creator]:wq(obj+0xad0,stats)
    wi(stats+0xc4,5);wq(source,vtable);wq(actor,vtable);wq(vtable+0xa8,m.stop+0x10);wq(vtable+0x1e0,m.stop+0x20)
    wq(nameStruct,nameText);name=c.get('name','spell_script').encode('ascii')+b'\0';u.mem_write(nameText,name);wi(nameStruct+8,len(name)-1)
    rsp=m.stack+0x1f008;rbp=rsp+0x300;u.mem_write(rsp-0x100,bytes(0xb00));u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RBP,rbp)
    u.reg_write(UC_X86_REG_RSI,actor);u.reg_write(UC_X86_REG_R14,payload);u.reg_write(UC_X86_REG_R12,1);u.reg_write(UC_X86_REG_R13,10);u.reg_write(UC_X86_REG_RDI,0);u.reg_write(UC_X86_REG_R15,nameText)
    u.emu_start(0x14038f8a7,m.stop,count=5000);assert u.reg_read(UC_X86_REG_RIP)==0x14038faed
    return dict(case=c,calls=calls,casterId=si(actor+0x230)&0xffffffff,spellId=si(actor+0x234),harmful=si(actor+0x238))
rows=[]
for sourceType,exists,harmful,dead,pc,name in itertools.product([3,5,6,9,10,11,14],[False,True],[-1,0,1,2],[0,1,2],[0,1,2],['','default','Default','spell_script']):rows.append(run(dict(sourceType=sourceType,exists=exists,harmful=harmful,dead=dead,pc=pc,name=name)))
for creatorExists,casterPC in itertools.product([False,True],[0,1,2]):rows.append(run(dict(sourceType=11,creatorExists=creatorExists,casterPC=casterPC)))
out=m.root/'backups/animations/native-spell-notification-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2)+'\n');print(json.dumps(dict(rows=len(rows),output=str(out))))
