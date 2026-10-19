"""Original player queue cadence block14037c8df..14037c951 and complete
SubtractWorldTimes140597a20. Pause-timer lookup/time and GUI queue update are
captured boundaries. Seeded caller scratch explicitly demonstrates unwritten
outputs on backwards time, not a claimed deterministic native recovery branch.
No complete AIUpdate prologue/caller stack, action UI, pause cast or wire claim.
"""
import importlib,itertools,json
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
actor,server,timer,world=[m.heap+n*0x1000 for n in range(4)]
frame=m.stack+0x1f080
def hook(u,a,n,_):
 if a==0x14037c952:u.emu_stop();return
 x,y,z=[u.reg_read(r)for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8]]
 if a==0x14055b870:m.finish(timer)
 elif a==0x140597180:m.wi(y,c['now'][0]);m.wi(z,c['now'][1]);m.finish()
 elif a==0x1403a6270:calls.append(['queue',m.si(actor+0x594)&0xffffffff,m.si(actor+0x598)&0xffffffff]);m.finish()
 elif not any(lo<=a<hi for lo,hi in [(0x14037c8df,0x14037c952),(0x140597a20,0x140597a6b)]):raise AssertionError(f'Unknown queue clock dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,calls
 c=case;calls=[];u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));m.wi(world+0x30,1000);m.wi(actor+0x594,c['previous'][0]);m.wi(actor+0x598,c['previous'][1]);m.wi(frame+0x14,c['seedTime']);m.wi(frame+0x58,c['seedDay'])
 for reg,value in [(UC_X86_REG_RSP,m.stack+0x1f000),(UC_X86_REG_RBP,frame),(UC_X86_REG_RDI,actor),(UC_X86_REG_R15,server),(UC_X86_REG_R12,world)]:u.reg_write(reg,value)
 u.emu_start(0x14037c8df,0x14037c952,count=1000);assert u.reg_read(UC_X86_REG_RIP)==0x14037c952
 return dict(case=c,calls=calls,day=m.si(actor+0x594)&0xffffffff,time=m.si(actor+0x598)&0xffffffff,outputDay=m.si(frame+0x58)&0xffffffff,outputTime=m.si(frame+0x14)&0xffffffff)
rows=[run(dict(now=now,previous=previous,seedDay=seedDay,seedTime=seedTime))for now,previous,seedDay,seedTime in itertools.product([[1,0],[1,299],[1,300],[1,301],[2,0],[0,500]],[[1,0],[1,300],[2,0]],[0,0x12345678],[0,299,300,0xffffffff])]
out=m.root/'backups/animations/native-player-queue-clock-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2)+'\n');print(json.dumps(dict(rows=len(rows))))
