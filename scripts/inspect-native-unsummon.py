"""Original UnsummonMyself1403daee0. Capture actions, area/master/client,
visual, feedback and deferred event transport; effect selection executes.
Actual event11 destruction and associate removal are separate owners.
"""
import importlib.util,itertools,json,struct
from pathlib import Path
spec=importlib.util.spec_from_file_location('fixture',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
actor,master,area,app,visual,ints,values,client,sheet,message=[m.heap+n*0x1000 for n in range(1,11)]
def point(ptr):return list(struct.unpack('<3f',u.mem_read(ptr,12)))
def hook(u,a,n,_):
 if a==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(reg) for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
 if a==0x14055b810:calls.append(['message']);m.finish(message if c.get('message',True) else 0)
 elif a==0x140490b80:calls.append(['clear',99]);m.finish()
 elif a==0x140494e80:calls.append(['area',99]);m.finish(0 if c.get('noArea') else area)
 elif a==0x14055b3d0:calls.append(['creature',y&0xffffffff]);m.finish(master if c.get('master',True) else 0)
 elif a==0x140423fd0:m.finish(m.si(x+0xc0+(y&255)*4)&0xffffffff)
 elif a==0x140423fc0:m.finish(m.si(m.q(x+0x48)+(y&255)*4)&0xffffffff)
 elif a==0x140c10324:m.finish(visual)
 elif a==0x1404233d0:u.mem_write(visual,bytes(0x110));m.wq(visual+0x48,ints);m.wi(visual+0x40,8);m.finish(visual)
 elif a==0x14035bdf0:calls.append(['visual',m.si(ints),point(z),point(w)]);m.finish()
 elif a==0x14055b390:calls.append(['client',y&0xffffffff]);m.finish(client if c.get('client',True) else 0)
 elif a==0x1404be500:calls.append(['displayed',y&0xffffffff]);m.finish()
 elif a==0x1404d90b0:calls.append(['notPermitted',y&0xffffffff,z&0xffffffff]);m.finish()
 elif a==0x1402da770:m.finish()
 elif a==0x1403a2480:calls.append(['feedback',y,99]);m.finish()
 elif a==0x14055b960:m.finish(app)
 elif a==0x1405570b0:calls.append(['event',y,z,w&0xffffffff,m.si(rsp+0x28)&0xffffffff,m.si(rsp+0x30),m.q(rsp+0x38)]);m.finish()
 elif a==0x140c10370:m.finish()
 elif not any(lo<=a<hi for lo,hi in [(0x1403daee0,0x1403db1df),(0x140425210,0x14042521c)]):raise AssertionError(f'Uncaptured unsummon dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,calls
 c=case;calls=[];u.mem_write(m.heap,bytes(0x100000));m.wq(0x1412df970,app);m.wq(app+8,app);m.wi(actor+8,99);m.wi(actor+0x8fc,100);m.wi(actor+0x540,c.get('open',0));m.wi(client+0x48,100);m.wq(client+0x90,sheet if c.get('sheet',True) else 0)
 u.mem_write(actor+0xa4,struct.pack('<3f',1,2,3));u.mem_write(actor+0xb0,struct.pack('<3f',4,5,6));m.wq(master+0x150,values);effects=c.get('effects',[]);m.wi(master+0x158,len(effects))
 for i,e in enumerate(effects):
  ptr=m.heap+0x10000+i*0x1000;iptr=ptr+0x200;m.wq(values+i*8,ptr);u.mem_write(ptr+8,struct.pack('<H',e.get('type',6)));m.wi(ptr+0xc4,e.get('id',99));m.wq(ptr+0x48,iptr);m.wi(iptr+8,e.get('enabled',1));m.wi(iptr+12,e.get('visual',99))
 rsp=m.stack+0x1fe08;u.mem_write(rsp-0x300,bytes(0x400));m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,actor)
 u.emu_start(0x1403daee0,m.stop,count=10000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=c,calls=calls)
rows=[run(dict(effects=effects,noArea=noArea,master=hasMaster,open=opened,client=hasClient,sheet=hasSheet,message=hasMessage)) for effects,noArea,hasMaster,opened,hasClient,hasSheet,hasMessage in itertools.product([[],[{'visual':321}],[{'visual':-1}],[{'enabled':0,'visual':321}],[{'id':98,'visual':321},{'visual':777}],[{'type':30},{'visual':321}],[{'visual':-1},{'visual':777}]], [False,True],[False,True],[0,1],[False,True],[False,True],[False,True])]
out=m.root/'backups/animations/native-unsummon-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows))+'\n');print(json.dumps(dict(rows=len(rows),output=str(out))))
