"""Original whole CC3 writer4cf090 with real message bit/byte/scalar/object/
string codecs. Data getters, client lookup/build answer, string ownership,
cleanup and final transport are captured lower providers in synthetic memory.
"""
import importlib,sys,itertools,json
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
t=importlib.import_module('inspect-native-message-text');w=t.w;r=t.r;m=w.m;u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(t.hook_handle);data,client,raw=m.heap+0x40000,m.heap+0x42000,m.heap+0x44000
def hook(u,a,n,extra):
 x,y,z,k=[u.reg_read(reg)for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];sp=u.reg_read(UC_X86_REG_RSP)
 if a==0x1402d5740:m.finish(damage[y&0xffffffff]);return
 if a==0x1402d57f0:m.finish(case['sourceId']if y==0 else case['targetId']);return
 if a==0x14055b3a0:m.finish(client);return
 if a==0x1404bd6d0:m.finish(case['newBuild']);return
 if a==0x1402d5810:m.wq(y,raw);m.wi(y+8,len(debug));m.wi(y+12,len(debug)+1);m.finish(y);return
 if a in [0x140169560,0x1401695b0,0x140169600]:m.finish(x);return
 if a==0x1404dc490:
  ptr=m.q(sp+0x28);length=m.si(sp+0x30)&0xffffffff;packets.append((bytes([80,z&255,k&255])+bytes(u.mem_read(ptr,length))[3:]).hex());m.finish(1);return
 if 0x1404cf090<=a<=0x1404d0b50:return
 t.hook(u,a,n,extra)
u.hook_add(UC_HOOK_CODE,hook);rows=[]
patterns=[[-1]*32,[0]+[-1]*31,[i*17 if i%3 else-1 for i in range(32)],[16383]*32,[16384,32767,-2]+[-1]*29]
for newBuild,pattern,debugOn,ids in itertools.product([0,1],range(len(patterns)),[0,1],[(99,100),(0xffffffff,0xfffffffe),(0x7f000000,99)]):
 case=dict(newBuild=newBuild,pattern=pattern,debug=debugOn,sourceId=ids[0],targetId=ids[1]);damage=patterns[pattern];debug=b'Debug \x80\xe9';packets=[];t.reset(dict(format=1));m.wi(0x14141e818,debugOn);u.mem_write(raw,debug);m.wq(m.stack+0x1fe30,0);result=w.call(0x1404cf090,[w.message,0x80000001,3,data]);assert len(packets)==1 and result==1
 rows.append(dict(case=case,inputDamage=damage,debugHex=debug.hex()if debugOn else None,packet=packets[0]))
out=m.root/'backups/animations/native-network-damage-feedback-wire.json';out.write_text(json.dumps(dict(target=m.digest,limits=__doc__,cases=rows),indent=2)+'\n');print(json.dumps(dict(cases=len(rows),output=str(out))))
