"""Original SafeProjectile4df550 with real scalar/OBJECTID writers and bounded
client header7ac7d1..7ac97b with real scalar/OBJECTID readers and overflow guards.
Build admission and SendServerToPlayerMessage are captured lower boundaries;
sender supplies envelope34/1. Allocation/copy fixture services are unchanged.
No transport/encryption, receiver models, paths, AI or game resolution executes.
"""
import sys,importlib,json,struct,itertools
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
t=importlib.import_module('inspect-native-message-text');w=t.w;r=t.r;m=w.m;u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(t.hook_handle)
player,fromPoint,toPoint,input_=[m.heap+n for n in [0x3000,0x4000,0x4100,0x30000]]
ranges=[(0x1404df550,0x1404df785),(0x1407ac7d1,0x1407ac97b),(0x1409737c0,0x1409737e8)]
packet=None;case={}
def hook(u,a,n,data):
 global packet
 x,y,z,v=[u.reg_read(q)for q in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];sp=u.reg_read(UC_X86_REG_RSP)
 if a in [0x1407ac97b,0x1407ae7fd]:u.emu_stop();return
 if a==0x1404bd6d0:m.finish(case['build']);return
 if a==0x1404dc490:
  length=m.si(sp+0x30)&0xffffffff;payload=m.q(sp+0x28);raw=bytes(u.mem_read(payload,length));packet=bytes([80,z&255,v&255])+raw[3:];m.finish(1);return
 if any(lo<=a<hi for lo,hi in ranges):return
 t.hook(u,a,n,data)
u.hook_add(UC_HOOK_CODE,hook)
rows=[]
for appearance,build,source,target in itertools.product([0,1,2,5,6,7,8,255],[0,1],[0,0x7f000000,0xffffffff],[0x123456,0x7f000000]):
 case=dict(appearance=appearance,build=build,source=source,target=target,duration=65535,spell=0xf1234567,path=13,base=49,result=3,from_=[1.25,-2,3.5],to=[4,5,6]);packet=None;t.reset(dict(format=1));m.wi(player+0x48,1234)
 u.mem_write(fromPoint,struct.pack('<3f',*case['from_']));u.mem_write(toPoint,struct.pack('<3f',*case['to']))
 sp=m.stack+0x1fe08
 for off,val in [(0x28,fromPoint),(0x30,toPoint)]:m.wq(sp+off,val)
 for off,val in [(0x38,case['duration']),(0x40,appearance),(0x48,case['spell']),(0x50,case['base']),(0x58,case['result']),(0x60,case['path'])]:m.wi(sp+off,val)
 w.call(0x1404df550,[w.message,player,source,target]);assert packet[:3]==bytes([80,34,1])
 u.mem_write(input_,packet[3:]);m.wi(sp+0x28,1);assert w.call(0x1402da7b0,[w.message,input_,len(packet)-3,0xffffffff])==1
 m.wq(sp,m.stop);u.reg_write(UC_X86_REG_RSP,sp);u.reg_write(UC_X86_REG_RSI,w.message);u.reg_write(UC_X86_REG_RBP,m.stack+0x10000);u.reg_write(UC_X86_REG_R13,0);u.mem_write(sp+0x40,b'\xff')
 u.emu_start(0x1407ac7d1,m.stop,count=100000);assert u.reg_read(UC_X86_REG_RIP)==0x1407ac97b
 rbp=u.reg_read(UC_X86_REG_RBP);app=u.reg_read(UC_X86_REG_R12)&255
 header=dict(sourceId=u.reg_read(UC_X86_REG_RBX)&0xffffffff,targetId=m.si(sp+0x48)&0xffffffff,from_=list(struct.unpack('<3f',u.mem_read(rbp-0x60,12))),to=list(struct.unpack('<3f',u.mem_read(rbp-0x50,12))),duration=m.si(rbp-0x74)&0xffffffff,appearance=app,spellId=(u.reg_read(UC_X86_REG_R15)&0xffffffff)if app in [6,7]else None,path=None if app==6 else m.si(sp+0x44)&255,baseItem=u.mem_read(sp+0x40,1)[0],result=u.reg_read(UC_X86_REG_R13)&255)
 assert w.call(0x1402d9460,[w.message])==0;assert w.call(0x1402d9520,[w.message])==0
 rows.append(dict(case=case,packet=packet.hex(),header=header))
out=m.root/'backups/animations/native-network-projectile-message-observations.json';out.write_text(json.dumps(dict(target=m.digest,limits=__doc__,cases=rows),indent=2)+'\n');print(json.dumps(dict(cases=len(rows),output=str(out))))
