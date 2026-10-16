"""Complete GetACNaturalBase, actual permanent/bonus WORD Contains and ordinary
HasFeat. Captured monk eligibility, ruleset lookup and class natural-AC getter.
Tests native transition9f4/polymorph97c guards and individual contribution gates.
"""
import importlib,itertools,json,struct
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
actor,stats,permanent,bonus,rules=[m.heap+n*0x2000 for n in range(5)];classes=m.heap+0x10000
ranges=[(0x1403f3e90,0x1403f4118),(0x140296910,0x14029699a),(0x14040b900,0x14040b9cb),(0x1402ae870,0x1402ae899)]
def hook(u,a,n,_):
 if a==m.stop:u.emu_stop();return
 x,y,z=[u.reg_read(r)for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8]]
 if a==0x140396370:calls.append(['monk']);m.finish(c.get('monk',1))
 elif a==0x1402a4130:
  expected=0xcbf29ce484222325
  for value in b'EPIC_ARMOR_SKIN_NATURAL_AC_BONUS':expected=((expected^value)*0x100000001b3)&0xffffffffffffffff
  assert y==expected;calls.append(['rule','EPIC_ARMOR_SKIN_NATURAL_AC_BONUS',z]);m.finish(c.get('rule',2))
 elif a==0x140299d00:
  index=(x-classes)//0x530;calls.append(['gain',index,y]);m.finish(c.get('gains',{}).get(str(index),3))
 elif not any(lo<=a<hi for lo,hi in ranges):raise RuntimeError(f'Unexpected natural armor dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,calls
 c=case;calls=[];u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));m.wq(stats+0x30,actor);m.wq(0x1412df8f8,rules);m.wq(rules+0x110,classes);u.mem_write(rules+0x105,bytes([c.get('classCount',44)&255]));m.wi(actor+0x9f4,c.get('transition',0));m.wi(actor+0x97c,c.get('polymorph',0))
 for offset,key,default in [(0xd44,'natural',5),(0xd51,'override',9),(0xd41,'wisdom',4)]:u.mem_write(stats+offset,bytes([c.get(key,default)&255]))
 for offset,storage,key in [(0,permanent,'permanent'),(0x20,bonus,'bonus')]:
  values=c.get(key,[]);m.wq(stats+offset,storage);m.wi(stats+offset+8,len(values));m.wi(stats+offset+12,max(16,len(values)))
  for i,value in enumerate(values):u.mem_write(storage+i*2,struct.pack('<H',value&65535))
 values=c.get('classes',[]);u.mem_write(stats+0xd8,bytes([len(values)&255]))
 for i,value in enumerate(values):u.mem_write(stats+0x25c+i*0x188,bytes([value['Class']&255,value['ClassLevel']&255]))
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,stats);u.reg_write(UC_X86_REG_RDX,c.get('flag',0)&0xffffffff);u.emu_start(0x1403f3e90,m.stop,count=50000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 result=u.reg_read(UC_X86_REG_RAX)&255;return dict(case=c,calls=calls,result=result if result<128 else result-256)
rows=[]
profiles=[[],[dict(Class=5,ClassLevel=10)],[dict(Class=5,ClassLevel=255),dict(Class=39,ClassLevel=9),dict(Class=34,ClassLevel=4)],[dict(Class=39,ClassLevel=255),dict(Class=255,ClassLevel=18)],[dict(Class=5,ClassLevel=2),dict(Class=5,ClassLevel=20)]]
for flag,monk,transition,polymorph,profile,feats in itertools.product([-1,0,1,2],[0,1,2],[-1,0,1],[0,1],profiles,[[],[260],[490],[260,490]]):rows.append(run(dict(flag=flag,monk=monk,transition=transition,polymorph=polymorph,classes=profile,permanent=feats)))
for natural,override,wisdom,rule,polymorph,bonusFeats in itertools.product([-129,-1,0,127,128,255],[0,127,128,255],[-1,0,1,127,128],[2,257],[0,1],[[],[260,490]]):rows.append(run(dict(natural=natural,override=override,wisdom=wisdom,rule=rule,polymorph=polymorph,classes=profiles[2],bonus=bonusFeats,gains={'5':127,'39':-129,'34':255})))
out=m.root/'backups/animations/native-natural-armor-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2)+'\n');print(json.dumps(dict(rows=len(rows),output=str(out))))
