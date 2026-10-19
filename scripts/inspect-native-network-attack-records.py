"""Original UpdateObject attack writer and client creature update reader.

Complete mask4 owners execute against synthetic combat-round records. Scalar
code, GetAttack and the 80-byte action constructor execute unchanged. Damage
aggregation, object lookup, model/UI/motion/audio and final PlayAnimation are
captured lower boundaries. Stationary-path classification is fixed to true;
this does not cover movement interpolation. No combat resolution, assets or
live mutation.
"""
import sys,importlib,json,struct,itertools
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
t=importlib.import_module('inspect-native-message-text');w=t.w;r=t.r;m=w.m;u=m.u
from unicorn import UC_HOOK_CODE,UC_HOOK_MEM_INVALID
from unicorn.x86_const import *
u.hook_del(t.hook_handle)
round_,actor,client,vt,cvt,player,context=[m.heap+n for n in [0x3000,0x7000,0x8000,0x9000,0xa000,0xb000,0xc000]]
input_=m.heap+0x30000
ranges=[(0x1409737c0,0x1409737e8),(0x1404eb590,0x1404edc50),(0x140375e40,0x140375eb5),(0x140781e80,0x1407857e9),
 (0x1407fb0e0,0x1407fb140),(0x140762430,0x140762530),(0x140762530,0x1407626d0),
 (0x1407630d0,0x1407630e0),(0x140763220,0x140763230),(0x1402d98d0,0x1402d9960),(0x1402dacb0,0x1402dad90)]
calls=[];case={}
def word(a):return int.from_bytes(u.mem_read(a,2),'little')
def wh(a,v):u.mem_write(a,struct.pack('<H',v&65535))
def wb(a,v):u.mem_write(a,bytes([v&255]))
def action(p):
 return dict(type=u.mem_read(p,1)[0],sourceId=m.si(p+4)&0xffffffff,duration=word(p+8),damage=word(p+10),result=u.mem_read(p+12,1)[0],
 targetId=m.si(p+16)&0xffffffff,reactionDelay=word(p+20),reaction=word(p+22),reactionDuration=word(p+24),attackType=word(p+26),
 ranged=m.si(p+28),killingBlow=m.si(p+32),weaponAttackType=u.mem_read(p+36,1)[0])
def hook(u,a,n,data):
 x,y,z=[u.reg_read(reg)for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8]]
 if a==0x1404ba840:m.finish(actor);return
 if a==m.stop+0x100:m.finish(actor);return
 if a==0x1403767a0:m.finish(m.si(x+0x90));return
 if a==0x14048e320:m.finish(1);return # stationary-path fixture
 if a==0x1406ab9e0:m.finish(client if case.get('present',True)else 0);return
 if a in [0x1406abbc0,0x1406abea0]:m.finish(context);return
 if a==0x1406ac1c0:m.finish(0x80000002);return
 if a==0x1406ac1a0:m.finish(0);return
 if a==m.stop+0x150:
  records=[];p=z
  while p:
   records.append(action(p));p=m.q(p+0x40);assert len(records)<5
  calls.append(dict(animation=y&65535,records=records));m.finish();return
 if a==m.stop+0x230:m.finish(0);return
 if a in [0x140805d20,0x140765f50,0x140764300,0x1407668f0,0x14080b0d0,0x140801860]:m.finish();return
 if any(lo<=a<hi for lo,hi in ranges):return
 t.hook(u,a,n,data)
u.hook_add(UC_HOOK_CODE,hook)
def invalid(u,access,address,size,value,data):
 print(json.dumps(dict(case=case,rip=hex(u.reg_read(UC_X86_REG_RIP)),bad=hex(address))),flush=True);return False
u.hook_add(UC_HOOK_MEM_INVALID,invalid)
rows=[]
for format_,groups,result,present in itertools.product([0,1],[[255],[1],[1,1],[1,1,1],[1,1,1,1],[1,1,2],[1,2,2],[2,1,2]],[1,4,15],[True,False]):
 case=dict(format=format_,groups=groups,result=result,present=present);calls=[];t.reset(dict(format=format_))
 m.wq(actor,vt);m.wq(vt+0x60,m.stop+0x100);m.wi(actor+8,0xfedcba);wb(actor+12,5);wh(actor+0xd8,9);m.wf(actor+0xdc,1.75);m.wq(actor+0x880,round_);m.wq(actor+0x530,context);wb(round_+0x2f2c,len(groups))
 for i,g in enumerate(groups):
  p=round_+i*0xf0;wb(p,g);m.wi(p+4,[0x123456,0x7f000000,0xffffffff,0x80000009][i]);wh(p+0xa,11+i);wh(p+0xc,250+i);wh(p+2,800+i);wb(p+0x78,result);wh(p+0x7a,300+i);m.wi(p+0x90,510+i);m.wi(p+0x5c,i%2);m.wi(p+0x68,i==2);wb(p+0x56,1+i)
 m.wi(m.stack+0x1fe08+0x28,4);m.wi(m.stack+0x1fe08+0x30,0);w.call(0x1404eb590,[w.message,player,actor,0]);packet=bytes.fromhex(w.snapshot()['hex'])
 # The server adds the common object header. Dispatch it through the real
 # scalar readers before entering the original type5 update owner.
 u.mem_write(input_,packet[3:]);m.wi(m.stack+0x1fe08+0x28,1);assert w.call(0x1402da7b0,[w.message,input_,len(packet)-3,0xffffffff])==1
 assert w.call(0x1402d98d0,[w.message,8])&255==ord('U');assert w.call(0x1402d9630,[w.message,8,1])==5
 offset=m.si(w.message+0x44);id_=int.from_bytes(u.mem_read(input_+offset,4),'little');m.wi(w.message+0x44,offset+4);assert id_==0x80fedcba;mask=w.call(0x1402d9bc0,[w.message,32]);assert mask==4
 m.wq(client,cvt);m.wq(cvt+0x150,m.stop+0x150);m.wq(cvt+0x230,m.stop+0x230);wb(client+12,5);m.wi(client+8,id_)
 result_=w.call(0x140781e80,[w.message,id_,mask]);assert w.call(0x1402d9460,[w.message])==0;assert w.call(0x1402d9520,[w.message])==0
 rows.append(dict(case=case,packet=packet.hex(),result=result_,calls=calls,speed=m.rf(client+0x60),cursor=r.state()))
out=m.root/'backups/animations/native-network-attack-record-observations.json';out.write_text(json.dumps(dict(target=m.digest,limits=__doc__,cases=rows),indent=2)+'\n');print(json.dumps(dict(cases=len(rows),output=str(out))))
