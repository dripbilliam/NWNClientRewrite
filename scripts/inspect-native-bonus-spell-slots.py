"""Original item bonus-slot apply46e820/remove473c30, ModifyNumberBonusSpells
40f110, stats SetNumberMemorizedSlots416540 and per-day getter/decrement owners.
GetClass, GetSpellGainWithBonus, class-info resize and ExoLog are captured lower
boundaries. Native class selection, counters, saturation, lock flags, per-day
byte mutation and warnings execute. Synthetic stats, not full inventory import.
"""
import importlib,itertools,json,struct
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle);owner,stats,prop,item,rules,info=[m.heap+n*0x8000 for n in range(6)]
ranges=[(0x14046e820,0x14046e8c5),(0x140473c30,0x140473d2f),(0x14040f110,0x14040f301),(0x140416540,0x14041660c),(0x140409680,0x14040975c),(0x1403f2790,0x1403f2869)]
def hook(u,a,n,_):
 if a==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(r) for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
 if a==0x1403fa4a0:calls.append(['class',y&255]);m.finish(c['classes'][y&255]&255)
 elif a==0x140408120:calls.append(['gain',y&255,z&255]);m.finish(c.get('gain',3)&255)
 elif a==0x140416610:calls.append(['resize',(x-stats-0xe0)//0x188,y&255,z&255,w&0xffffffff]);m.finish()
 elif a==0x140115890:calls.append(['warning']);m.finish()
 elif not any(lo<=a<hi for lo,hi in ranges):raise RuntimeError(f'Unexpected bonus slots dependency {a:x} case={c}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,calls
 c=case;calls=[];u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));m.wq(owner+0xad0,stats);m.wq(stats+0x30,owner);u.mem_write(stats+0xd8,bytes([len(c['classes'])&255]));m.wi(owner+0x9f4,c.get('suppressed',0));m.wi(owner+0x97c,c.get('locked',0));m.wq(0x1412df8f8,rules);m.wq(rules+0x110,info)
 for kind in set([v&255 for v in c['classes']]+[c.get('subtype',2)&255]):m.wi(info+kind*0x530+0x4ec,c.get('memorizes',1))
 # The class rule array may exceed the synthetic heap for large class IDs;
 # fixtures use mapped rule rows0..3, full WORD mismatch subtype258 stays row2.
 u.mem_write(prop+2,struct.pack('<H',c.get('subtype',2)));u.mem_write(prop+6,struct.pack('<H',c.get('level',1)))
 for i in range(len(c['classes'])):
  for l in range(10):m.wi(stats+0x220+i*0x188+l*4,c.get('bonus',0));u.mem_write(stats+0x248+i*0x188+l,bytes([c.get('perDay',2)&255]))
 mode=c['mode'];args=[stats,c.get('index',0),c.get('level',1),c.get('delta',1)] if mode=='modify' else [rules,item,prop,owner]
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);m.wi(rsp+0x28,16);m.wi(rsp+0x30,c.get('loading',0))
 for r,v in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],args):u.reg_write(r,v&0xffffffffffffffff)
 u.emu_start(dict(apply=0x14046e820,remove=0x140473c30,modify=0x14040f110)[mode],m.stop,count=20000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=c,calls=calls,result=None if mode=='modify' else u.reg_read(UC_X86_REG_RAX)&0xffffffff,bonus=[[m.si(stats+0x220+i*0x188+l*4) for l in range(10)]for i in range(len(c['classes']))],perDay=[list(u.mem_read(stats+0x248+i*0x188,10))for i in range(len(c['classes']))])
rows=[]
for mode,cls,subtype,level,bonus,memorizes,perDay in itertools.product(['apply','remove'],[[],[2],[1,2],[2,1,2]],[2,258],[0,1,9,10,256],[0,1,255],[0,1],[0,2]):rows.append(run(dict(mode=mode,classes=cls,subtype=subtype,level=level,bonus=bonus,memorizes=memorizes,perDay=perDay)))
for index,level,delta,bonus,gain,locked,suppressed in itertools.product([0,1,256],[1,10],[-1,1,2147483647,-2147483648],[0,1,255,256,2147483647],[0,3,255],[0,1],[0,1]):rows.append(run(dict(mode='modify',classes=[2],index=index,level=level,delta=delta,bonus=bonus,gain=gain,locked=locked,suppressed=suppressed)))
out=m.root/'backups/animations/native-bonus-spell-slots-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2)+'\n');print(json.dumps(dict(rows=len(rows),output=str(out))))
