"""Original whole CC5/6 writer4cf090 with original CHAR and all message codecs.
Data getters, debug string ownership, cleanup and final transport are captured
lower boundaries. Synthetic memory only; no original process or asset changes.
"""
import importlib,sys,itertools,json,struct
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
t=importlib.import_module('inspect-native-message-text');w=t.w;r=t.r;m=w.m;u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(t.hook_handle);data,attack,raw=m.heap+0x40000,m.heap+0x42000,m.heap+0x44000
def hook(u,a,n,extra):
 x,y,z,k=[u.reg_read(reg)for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];sp=u.reg_read(UC_X86_REG_RSP)
 if a==0x1402d57f0:m.finish(case['sourceId']if y==0 else case['targetId']);return
 if a==0x1402d5810:m.wq(y,raw);m.wi(y+8,len(debug));m.wi(y+12,len(debug)+1);m.finish(y);return
 if a in [0x140169560,0x1401695b0,0x140169600]:m.finish(x);return
 if a==0x1404dc490:
  ptr=m.q(sp+0x28);length=m.si(sp+0x30)&0xffffffff;packets.append((bytes([80,z&255,k&255])+bytes(u.mem_read(ptr,length))[3:]).hex());m.finish(1);return
 if 0x1404cf090<=a<=0x1404d0b50 or 0x1402dacb0<=a<0x1402dad90:return
 t.hook(u,a,n,extra)
u.hook_add(UC_HOOK_CODE,hook);rows=[]
for minor,result,profile,threatened,debugOn,ids in itertools.product([5,6],range(16),range(3),[0,1],[0,1],[(99,100),(0xffffffff,0xfffffffe),(0x7f000000,99)]):
 case=dict(minor=minor,result=result,modifier=[-128,0,383][profile],roll=[0,20,255][profile],confirmation=[0,17,255][profile],combatMode=[0,11,255][profile],weaponAttackType=[0,2,3][profile],sneakAttack=profile%2,deathAttack=int(profile==2),coupDeGrace=int(profile==2),threatened=threatened,concealmentChance=[0,100,255][profile],attackType=[0,0xfdea,65535][profile],debug=debugOn,sourceId=ids[0],targetId=ids[1]);debug=b'Debug \x80\xe9';packets=[];t.reset(dict(format=1));m.wi(0x14141e818,debugOn);u.mem_write(raw,debug)
 for off,name in [(0x10,'modifier'),(0x60,'sneakAttack'),(0x64,'deathAttack'),(0x6c,'coupDeGrace'),(0x70,'threatened')]:m.wi(attack+off,case[name])
 for off,name in [(0xe,'roll'),(0xf,'confirmation'),(0x56,'weaponAttackType'),(0x57,'combatMode'),(0x58,'concealmentChance'),(0x78,'result')]:u.mem_write(attack+off,bytes([case[name]&255]))
 u.mem_write(attack+0x7a,struct.pack('<H',case['attackType']));m.wq(m.stack+0x1fe30,attack);resultValue=w.call(0x1404cf090,[w.message,0x80000001,minor,data]);assert len(packets)==1 and resultValue==1
 rows.append(dict(case=case,debugHex=debug.hex()if debugOn else None,packet=packets[0]))
 if len(rows)%256==0:print(json.dumps(dict(progress=len(rows))),flush=True)
out=m.root/'backups/animations/native-network-attack-feedback-wire.json';out.write_text(json.dumps(dict(target=m.digest,limits=__doc__,cases=rows),indent=2)+'\n');print(json.dumps(dict(cases=len(rows),output=str(out))))
