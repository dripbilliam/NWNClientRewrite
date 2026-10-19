"""Original bounded creature AI clock block7fbfb8..7fc01d and complete
SubtractWorldTimes597a20. Timer lookup/time getters are captured. Explicit
caller scratch seeds show unwritten invalid subtraction outputs; full AI,
prologue stack history, model playback and deterministic recovery are not claimed.
"""
import importlib,itertools,json
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle);actor,timer,app=[m.heap+n*0x1000 for n in range(3)];frame=m.stack+0x1f500
def hook(u,a,n,_):
 if a==0x1407fc01d:u.emu_stop();return
 x,y,z=[u.reg_read(r)for r in[UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8]]
 if a in[0x1406ab840,0x1406ac330]:m.finish(timer)
 elif a==0x140597180:m.wi(y,c['now'][0]);m.wi(z,c['now'][1]);m.finish()
 elif not(0x1407fbfb8<=a<0x1407fc01d or 0x140597a20<=a<0x140597a6b):raise AssertionError(f'Unknown client frame clock dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c
 c=case;u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));m.wq(0x1412df970,app);m.wq(app,app);m.wi(timer+0x30,1000);m.wi(actor+8,99);m.wi(actor+0x50,c['previous'][0]);m.wi(actor+0x54,c['previous'][1]);m.wi(frame-0x55,c['seedTime']);m.wi(frame-0x41,c['seedDay']);u.reg_write(UC_X86_REG_RSP,m.stack+0x1f000);u.reg_write(UC_X86_REG_RBP,frame);u.reg_write(UC_X86_REG_RSI,actor)
 u.emu_start(0x1407fbfb8,0x1407fc01d,count=1000);assert u.reg_read(UC_X86_REG_RIP)==0x1407fc01d
 return dict(case=c,status=u.reg_read(UC_X86_REG_RAX)&0xffffffff,elapsed=m.si(actor+0x58)&0xffffffff,outputDay=m.si(frame-0x41)&0xffffffff,outputTime=m.si(frame-0x55)&0xffffffff)
rows=[run(dict(now=now,previous=previous,seedDay=seedDay,seedTime=seedTime))for now,previous,seedDay,seedTime in itertools.product([[1,0],[1,299],[1,1000],[2,0],[0,500]],[[1,0],[1,300],[2,0]],[0,0x12345678],[0,300,0xffffffff])]
out=m.root/'backups/animations/native-client-creature-clock-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2)+'\n');print(json.dumps(dict(rows=len(rows))))
