"""Original STR/CON/DEX setters, full GetMaxHitPoints, and all six cache
writes from UpdateCombatInformation140417256..1404172f8. The stage sequence is
the separately compared form coordinators' stat/equipment boundary order, not
another full coordinator execution. Lower score/modifier/feat/level/ruleset/
encumbrance providers captured. Score queries read supplied base/racial values;
native maximum-HP instructions and per-level clamp execute without replacement.
"""
import importlib,itertools,json,math,struct
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle);actor,stats,vt,levels=[m.heap+n*0x2000 for n in range(4)]
scores=[0x140406930,0x1403fd3e0,0x1403fa0f0,0x140402d10,0x14040b5e0,0x1403fa050]
ranges=[(0x1404167d0,0x140416808),(0x140415530,0x14041555b),(0x1404152a0,0x140415343),(0x140391850,0x140391e70),(0x140417256,0x1404172f8),(0x1402ae870,0x1402ae899)]
def byte(a):return u.mem_read(a,1)[0]
def signed8(v):return(v^128)-128
def hook(u,a,n,_):
 if a in [m.stop,0x1404172f8]:u.emu_stop();return
 x,y,z=[u.reg_read(r)for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8]]
 if a in scores:
  index=scores.index(a);value=byte(stats+0xd38+index*2)+(raceAdjust if index==2 else 0);m.finish(max(3,value)&255)
 elif a==0x1403f16c0:m.finish(math.floor(((y&255)-10)/2))
 elif a==0x1403db1e0:m.finish()
 elif a==m.stop+0x20:m.finish(m.si(actor+0xe0))
 elif a==0x14040b900:m.finish(int(y==40 and c['toughness']))
 elif a==0x1403d54d0:m.finish(0)
 elif a==0x1404035c0:m.finish(len(c['dice']))
 elif a==0x1404036b0:m.finish(levels+(y&255)*0x200 if (y&255)<len(c['dice'])else 0)
 elif a==0x140405570:m.finish(0)
 elif a==0x1402a4130:m.finish(z)
 elif not any(lo<=a<hi for lo,hi in ranges):raise RuntimeError(f'Unexpected polymorph stat pipeline dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def execute(entry,argument=0,flag=0):
 rsp=m.stack+0x1fe08;u.mem_write(m.stack,bytes(0x20000));m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_R12,stats)
 for r,v in [(UC_X86_REG_RCX,actor if entry==0x140391850 else stats),(UC_X86_REG_RDX,argument),(UC_X86_REG_R8,flag)]:u.reg_write(r,v&0xffffffffffffffff)
 u.emu_start(entry,m.stop,count=100000);assert u.reg_read(UC_X86_REG_RIP)in[m.stop,0x1404172f8];return(u.reg_read(UC_X86_REG_RAX)&65535^32768)-32768
def snapshot():return dict(hp=m.si(actor+0xe0),maximum=execute(0x140391850,1),con=byte(stats+0xd3c),modifier=signed8(byte(stats+0xd3d)))
rows=[]
wizard=[4,4,4,3,3,2,4,4,2,2,3,2,2,4,4]
for base,initial,form,con,dice,toughness,injury in itertools.product([14],[-2,0],[0,2],[None,8,14,20],[wizard,[1,1,2,4]],[False,True],[0,7]):
 c=dict(base=base,initialAdjust=initial,formAdjust=form,formCon=con,dice=dice,toughness=toughness,injury=injury);u.mem_write(m.heap,bytes(0x100000));raceAdjust=initial
 m.wq(actor,vt);m.wq(vt+0x130,0x140391850);m.wq(vt+0x138,m.stop+0x20);m.wq(actor+0xad0,stats);m.wq(stats+0x30,actor);m.wi(stats+0xb0,1)
 for i in range(6):u.mem_write(stats+0xd38+i*2,bytes([base if i==2 else 12,0]))
 for n,value in enumerate(dice):u.mem_write(levels+n*0x200+0x15b,bytes([value&255]))
 execute(0x140417256);maximum=execute(0x140391850,1);m.wi(actor+0xe0,maximum-injury);before=snapshot()
 raceAdjust=form;execute(0x1404167d0,18)
 if con is not None:execute(0x1404152a0,con,1)
 execute(0x140415530,16);execute(0x140417256);changed=snapshot()
 execute(0x140417256);raceAdjust=initial;execute(0x1404167d0,12);execute(0x1404152a0,base,1);execute(0x140415530,12);restored=snapshot()
 rows.append(dict(case=c,before=before,changed=changed,restored=restored))
out=m.root/'backups/animations/native-polymorph-hp-pipeline-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2)+'\n');print(json.dumps(dict(rows=len(rows),output=str(out))))
