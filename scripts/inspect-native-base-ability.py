"""Complete six original base-ability setters. Current score, modifier,
encumbrance and virtual current/maximum HP are captured lower providers.
The original setter instructions own byte writes, exact flag1, signed-short HP
arithmetic, cached modifiers and mental-stat dirty flag. No fake death events.
"""
import importlib,itertools,json
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
actor,stats,vt=[m.heap+n*0x2000 for n in range(3)]
setters=[0x1404167d0,0x140415530,0x1404152a0,0x140415aa0,0x140416e70,0x140415260]
scores=[0x140406930,0x1403fd3e0,0x1403fa0f0,0x140402d10,0x14040b5e0,0x1403fa050]
ranges=[(0x1404167d0,0x140416808),(0x140415530,0x14041555b),(0x1404152a0,0x140415343),(0x140415aa0,0x140415ad9),(0x140416e70,0x140416ea9),(0x140415260,0x140415299)]

def byte(ptr):return bytes(u.mem_read(ptr,1))[0]
def hook(u,a,n,_):
 global reads
 if a==m.stop:u.emu_stop();return
 x,y=[u.reg_read(r)for r in [UC_X86_REG_RCX,UC_X86_REG_RDX]]
 if a==m.stop+0x10:
  reads+=1;calls.append(['maximum',y,byte(stats+0xd3c),byte(stats+0xd3d)]);m.finish(c.get('oldMaximum',100)if reads==1 else c.get('newMaximum',150))
 elif a==m.stop+0x20:calls.append(['current',y]);m.finish(c.get('hp',80))
 elif a in scores:
  index=scores.index(a);calls.append(['score',index,byte(stats+0xd38+index*2),byte(stats+0xd39+index*2)]);m.finish(c.get('score',18))
 elif a==0x1403f16c0:calls.append(['modifier',y]);m.finish(c.get('modifier',4))
 elif a==0x1403db1e0:calls.append(['encumbrance',y]);m.finish()
 elif not any(lo<=a<hi for lo,hi in ranges):raise RuntimeError(f'Unexpected base ability dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)

def run(case):
 global c,calls,reads
 c=case;calls=[];reads=0;u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));m.wq(actor,vt);m.wq(stats+0x30,actor);m.wq(vt+0x130,m.stop+0x10);m.wq(vt+0x138,m.stop+0x20);m.wi(actor+0xe0,c.get('hp',80));m.wi(actor+0x544,7)
 for i in range(6):u.mem_write(stats+0xd38+i*2,bytes([12+i,1+i]))
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,stats);u.reg_write(UC_X86_REG_RDX,c['value']&0xffffffff);u.reg_write(UC_X86_REG_R8,c.get('adjust',1)&0xffffffff)
 u.emu_start(setters[c['ability']],m.stop,count=10000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=c,calls=calls,bases=[byte(stats+0xd38+i*2)for i in range(6)],modifiers=[byte(stats+0xd39+i*2)for i in range(6)],hp=m.si(actor+0xe0),dirty=m.si(actor+0x544))

rows=[]
for ability,value,adjust,score,modifier in itertools.product(range(6),[-257,-1,0,1,18,255,256,511],[-1,0,1,2],[3,18,256],[-129,4,256]):rows.append(run(dict(ability=ability,value=value,adjust=adjust,score=score,modifier=modifier)))
for hp,oldMaximum,newMaximum in itertools.product([-65537,-32769,-32768,-11,0,1,32767,32768,65535],[0,1,100,32767,32768,65535],[-32769,-1,0,150,32767,32768]):rows.append(run(dict(ability=2,value=20,adjust=1,hp=hp,oldMaximum=oldMaximum,newMaximum=newMaximum)))
out=m.root/'backups/animations/native-base-ability-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2)+'\n');print(json.dumps(dict(rows=len(rows),output=str(out))))
