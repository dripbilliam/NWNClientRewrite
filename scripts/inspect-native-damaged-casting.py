"""Untouched OnApplyDamage damaged-casting block140428e6c..140429188.
DoDamage already ran. Capture spell/class/skill/RNG/action deletion, resource
consumption, visual application and feedback lower boundaries. No full HP,
script, cancellation or action-queue parity is claimed by this block fixture.
"""
import importlib.util,itertools,json,struct
from pathlib import Path
from native_rule_fixture import ruleset_value
spec=importlib.util.spec_from_file_location('fixture',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
actor,creator,stats,spell,master,rules,vt,frame,allocated=[m.heap+n*0x1000 for n in range(1,10)]
def hook(u,a,n,_):
 global allocation
 if a in [m.stop,0x140428bc0,0x140429188]:u.emu_stop();return
 x,y,z,w=[u.reg_read(reg) for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
 if a==m.stop+0x10:m.finish(creator if c.get('creator',True) else 0)
 elif a==m.stop+0x20:calls.append(['animation',y&65535]);m.finish()
 elif a==0x1402af4a0:calls.append(['spell',y&0xffffffff]);m.finish(0 if (y==1 and c.get('missing')) or (y==2 and c.get('masterMissing')) else spell if y==1 else master)
 elif a==0x1402ad680:calls.append(['roll',y&255,z&255]);m.finish(c.get('roll',20))
 elif a==0x140406a40:calls.append(['skill',y&255,98 if z else None,w&0xffffffff]);m.finish(c.get('rank',10)&255)
 elif a==0x1403fa4a0:m.finish(10)
 elif a==0x1402af530:calls.append(['level',1 if x==spell else 2,c.get('class',0)&255]);m.finish(c.get('level',1) if x==spell else c.get('masterLevel',2))
 elif a==0x1402ae870:m.finish(0)
 elif a==0x1402a4130:m.finish(c.get('dc',10))
 elif a==0x140491570:calls.append(['delete']);m.finish()
 elif a==0x14038a590:calls.append(['consume',y&0xffffffff,z&255,w&255,m.si(rsp+0x28)&255,m.si(rsp+0x30)&255]);m.finish(0)
 elif a==0x1403a2480:calls.append(['feedback',y&65535]);m.finish()
 elif a==0x140c10324:allocation+=1;m.finish(allocated+allocation*0x1000)
 elif a==0x1404233d0:u.mem_write(x,bytes(0x110));m.wq(x+0x48,x+0x200);m.finish(x)
 elif a==0x140425110:m.wi(x+0x18,y);m.finish()
 elif a==0x140425210:m.wi(m.q(x+0x48)+(y&0xffffffff)*4,z);m.finish()
 elif a==0x14048e350:calls.append(['visual',int.from_bytes(u.mem_read(y+8,2),'little'),m.si(y+0x18),m.si(m.q(y+0x48)),z&0xffffffff]);m.finish(1)
 elif a==0x1402da770:message['objects'][str(y&0xffffffff)]=z&0xffffffff;m.finish()
 elif a==0x1402da730:message['integers'][str(y&0xffffffff)]=z&0xffffffff;m.finish()
 elif a==0x140384150:calls.append(['message',json.loads(json.dumps(message))]);m.finish()
 elif not 0x140428e6c<=a<0x140429188:raise AssertionError(f'Uncaptured damaged-casting dependency {a:x} {c}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,calls,message,allocation
 c=case;calls=[];message={'objects':{},'integers':{}};allocation=0;u.mem_write(m.heap,bytes(0x100000));m.wq(0x1412df8f8,rules);m.wq(rules+0xd0,rules);m.wq(actor,vt);m.wq(vt+0x100,m.stop+0x20);m.wq(creator,vt);m.wq(vt+0x20,m.stop+0x10);m.wi(actor+8,99);m.wi(actor+0xd8,c.get('animation',15));m.wi(actor+0x218,1);u.mem_write(actor+0x22c,bytes([c.get('class',0)]));m.wq(actor+0xad0,stats);m.wi(spell+0x174,c.get('concentration',1));m.wi(spell+0x178,2);u.mem_write(spell+0x6f,bytes([c.get('innate',3)]));u.mem_write(spell+0x74,struct.pack('<H',c.get('conjure',1)));m.wq(frame-0x80,creator if c.get('creator',True) else 0)
 rsp=m.stack+0x1f000;u.mem_write(rsp-0x200,bytes(0x500));m.wi(rsp+0x60,c.get('loading',0));u.reg_write(UC_X86_REG_RSP,rsp)
 for reg,v in zip([UC_X86_REG_RSI,UC_X86_REG_RDI,UC_X86_REG_R15,UC_X86_REG_RBP],[actor,0,c.get('amount',1),frame]):u.reg_write(reg,v)
 u.emu_start(0x140428e6c,m.stop,count=5000);assert u.reg_read(UC_X86_REG_RIP) in [0x140428bc0,0x140429188,m.stop]
 return dict(case=c,calls=calls)
rows=[]
for animation,concentration,rank,roll,amount,index in itertools.product([1,15,16,17],[0,1],[-128,-1,0,10,127],[1,15,20],[1,20],[0,254,255]):rows.append(run(dict(animation=animation,concentration=concentration,rank=rank,roll=roll,amount=amount,**{'class':index})))
for level,masterMissing,masterLevel,creatorExists,loading,conjure,dc in itertools.product([1,255],[False,True],[2,255],[False,True],[0,1],[1,2],[-20,10,100]):rows.append(run(dict(level=level,masterMissing=masterMissing,masterLevel=masterLevel,creator=creatorExists,loading=loading,conjure=conjure,dc=dc)))
rows.append(run(dict(missing=True)))
out=m.root/'backups/animations/native-damaged-casting-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows))+'\n');print(json.dumps(dict(rows=len(rows),output=str(out))))
