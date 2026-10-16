"""Untouched ToggleMode1403a52b0 and decoded subtype10 block453807.
Dead/dying, skill/feat queries, SetActivity/SetCombatMode and event delivery
are captured boundaries. This does not establish their lower-owner parity.
"""
import importlib.util,itertools,json
from pathlib import Path
spec=importlib.util.spec_from_file_location('fixture',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
actor,stats,manager,ids,event,associate,message=[m.heap+n*0x1000 for n in range(1,8)]
def hook(u,a,n,_):
 global overflow
 if a in [m.stop,0x140453780,0x1404539e1]:u.emu_stop();return
 x,y,z,w=[u.reg_read(reg) for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
 if a==0x1404953b0:m.finish(c.get('dead',0))
 elif a==0x140495620:m.finish(c.get('dying',0))
 elif a==0x140390490:calls.append(['detect']);m.finish(c.get('detect',0))
 elif a==0x1403fa1d0:calls.append(['skill',y&255]);m.finish(int((y&255) in c.get('skills',[])))
 elif a==0x14040b900:calls.append(['feat',y&65535]);m.finish(int((y&65535) in c.get('feats',[])))
 elif a==0x1403a2480:calls.append(['feedback',y&65535]);m.finish()
 elif a==0x1403a2650:calls.append(['activity',y&0xffffffff,z&0xffffffff]);m.finish()
 elif a==0x1403d8c50:calls.append(['mode',y&255,z&0xffffffff]);m.finish()
 elif a==0x14055b3d0:m.finish(associate if y==100 else 0)
 elif a==0x140c10324:m.finish(event)
 elif a==0x1404c6490:u.mem_write(x,bytes(0x48));m.finish(x)
 elif a==0x1404c72e0:m.wi(x+0x20,z);m.finish()
 elif a==0x14055b960:m.finish(manager)
 elif a==0x1405570b0:
  payload=m.q(rsp+0x38);calls.append(['event',m.si(rsp+0x30),w&0xffffffff,m.si(rsp+0x28),int.from_bytes(u.mem_read(payload,2),'little'),m.si(payload+0x20)]);m.finish(1)
 elif a==0x1402d9630:calls.append(['read']);m.finish(c['requested'])
 elif a==0x1402d9460:overflow+=1;m.finish(c.get('overflow',0)==overflow)
 elif a==0x1402d9520:m.finish(c.get('underflow',0))
 elif a==0x140476130:calls.append(['target']);m.finish(100)
 elif a==0x14037e460:calls.append(['counter',y&0xffffffff]);m.finish(0)
 elif a==0x1403a52b0 and c.get('input'):calls.append(['toggle',y&255]);m.finish(0)
 elif not any(lo<=a<hi for lo,hi in [(0x1403a52b0,0x1403a571b),(0x140453807,0x14045389c)]):raise AssertionError(f'Uncaptured toggle dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,calls,overflow
 c=case;calls=[];overflow=0;u.mem_write(m.heap,bytes(0x100000));m.wq(0x1412df970,manager);m.wq(manager+8,manager);m.wq(actor+0xad0,stats);m.wi(actor+8,99);m.wi(associate+8,100)
 m.wi(actor+0x724,0 if c.get('busy') else 0x7f000000);m.wi(actor+0x728,0x7f000000);u.mem_write(actor+0x6ed,bytes([c.get('stealth',0)]));u.mem_write(actor+0x6ef,bytes([c.get('mode',0)]));m.wi(actor+0xec,c.get('commandable',1))
 m.wq(actor+0x900,ids);m.wq(ids,ids+0x100);m.wi(ids+8,len(c.get('associates',[])))
 for i,id in enumerate(c.get('associates',[])):m.wi(ids+0x100+i*4,id)
 rsp=m.stack+0x1fe08;u.mem_write(rsp-0x200,bytes(0x300));m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 if c.get('input'):
  for reg,v in [(UC_X86_REG_R15,actor if c.get('actor',True) else 0),(UC_X86_REG_RDI,message),(UC_X86_REG_RSI,0)]:u.reg_write(reg,v)
  u.emu_start(0x140453807,m.stop,count=2000);result=0 if u.reg_read(UC_X86_REG_RIP)==0x1404539e1 else u.reg_read(UC_X86_REG_R14)&0xffffffff
 else:
  u.reg_write(UC_X86_REG_RCX,actor);u.reg_write(UC_X86_REG_RDX,c['requested']);u.emu_start(0x1403a52b0,m.stop,count=5000);assert u.reg_read(UC_X86_REG_RIP)==m.stop;result=u.reg_read(UC_X86_REG_RAX)&0xffffffff
 return dict(case=c,calls=calls,result=result)
rows=[run(dict(requested=requested,mode=mode,feats=feats,associates=[100,101,100])) for requested,mode,feats in itertools.product(range(15),[0,1,4,9,11], [[],[28,19,204,30,389,390,425,947],[899],[866]])]
rows += [run(dict(requested=requested,dead=dead,dying=dying,detect=detect,stealth=stealth,busy=busy,skills=skills)) for requested,dead,dying,detect,stealth,busy,skills in itertools.product([0,1,10],[0,1],[0,1],[0,1,2],[0,1,2],[False,True],[[],[5],[8]])]
inputs=[run(dict(input=True,requested=requested,actor=actorExists,commandable=commandable,overflow=overflowAt,underflow=underflow)) for requested,actorExists,commandable,overflowAt,underflow in itertools.product([0,5,10,255],[False,True],[0,1],[0,1,2],[0,1])]
out=m.root/'backups/animations/native-mode-toggle-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows,inputs=inputs))+'\n');print(json.dumps(dict(rows=len(rows),inputs=len(inputs),output=str(out))))
