"""Original client WalkToWaypoint sender 1407c0970 and server 140455860.

Real CNWMessage scalar/OBJECT_ID writers and server readers execute intact.
Only allocation/copy/logging, send transport, controlled-object lookup and the
AI/mode/action insertion boundaries are captured. No live process writes, local
game simulation, click-picking or server pathfinding completeness claim.
"""
import sys,importlib,itertools,json,struct
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
t=importlib.import_module('inspect-native-message-text');w=t.w;r=t.r;m=w.m;u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(t.hook_handle)
ranges=[]
for name in ['network-client-walk-sender','network-client-objectid-writer','network-walk-waypoint-handler']:
 d=json.loads((m.root/'backups/animations'/('rea-'+name+'.json')).read_text())['structuredContent']['normalized_result']
 ranges.extend((int(x['start'],16),int(x['end'],16)+1)for x in d['procedure']['body']['ranges'])
client,actor,path,area,vt,roundPtr=[m.heap+n*0x1000 for n in [10,11,12,13,14,15]]

def hook(u,a,n,data):
 x,y,z,k=[u.reg_read(reg)for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];sp=u.reg_read(UC_X86_REG_RSP)
 if a==0x1407c25c0:
  size=m.si(sp+0x28)&0xffffffff;packet=bytearray(u.mem_read(k,size));packet[:3]=bytes([112,y&255,z&255]);sent.append(bytes(packet));m.finish(1);return
 if a==0x1404ba840:m.finish(actor);return
 if a==0x140494e80:m.finish(area);return
 if a==m.stop+0x10:m.finish(x);return
 if a==0x140294430:calls.append(['reset']);m.finish();return
 if a==0x140387dc0:calls.append(['compute']);u.mem_write(actor+0x8d6,b'\0');m.finish();return
 if a==0x14055b9c0:m.finish(0);return
 if a==0x1403d8c50:calls.append(['mode',y&255,z&0xffffffff]);m.finish();return
 if a==0x140375570:calls.append(['clearSpecial']);m.finish();return
 if a==0x14037cbc0:calls.append(['actionManager',y&0xffffffff]);m.finish();return
 if a==0x14037f940:
  calls.append(['move',y&65535,[m.rf(z+i)for i in [0,4,8]],k&0xffffffff,m.si(sp+0x28)&0xffffffff,m.si(sp+0x30),m.rf(sp+0x38),m.rf(sp+0x40),m.si(sp+0x48),m.si(sp+0x50),m.si(sp+0x58),m.si(sp+0x60),m.si(sp+0x68),m.si(sp+0x70)]);m.finish(1);return
 if any(lo<=a<hi for lo,hi in ranges):return
 t.hook(u,a,n,data)
hook_handle=u.hook_add(UC_HOOK_CODE,hook)

def encode(c):
 global sent,calls
 sent=[];calls=[];t.reset(dict(format=c['format']));sp=m.stack+0x1fe08
 for reg,v in [(UC_X86_REG_XMM2,c['point'][0]),(UC_X86_REG_XMM3,c['point'][1])]:u.reg_write(reg,int.from_bytes(struct.pack('<f',v),'little'))
 m.wf(sp+0x28,c['point'][2])
 for offset,v in [(0x30,c['sequence']),(0x38,c['run']),(0x40,c['clientPath']),(0x48,c['fractional']),(0x50,c['targetId'])]:m.wi(sp+offset,v)
 w.call(0x1407c0970,[w.message,c['areaId'],0,0]);assert len(sent)==1
 return sent[0]

def receive(packet):
 global calls
 calls=[];u.mem_write(t.inputBase,packet[3:]+bytes([0xa5])*128);sp=m.stack+0x1fe08;m.wi(sp+0x28,1)
 result=w.call(0x1402da7b0,[w.message,t.inputBase,len(packet)-3,0xffffffff]);assert result==1
 u.mem_write(actor,bytes(0x1000));u.mem_write(path,bytes(0x1000));m.wq(actor,vt);m.wq(vt+0x60,m.stop+0x10);m.wq(actor+0x530,path);m.wq(actor+0x880,roundPtr);m.wi(actor+0xec,1);m.wi(actor+8,99)
 result=w.call(0x140455860,[w.message,client,0,0]);return dict(result=result,calls=list(calls),fractional=m.si(path+0x19c),reader=r.state())

rows=[]
for format,sequence,run,clientPath,fractional in itertools.product([0,1],[0,1,254,255],[0,1],[0,1],[0,1]):
 c=dict(format=format,areaId=0x80000001,point=[1.25,17.5,-.125],sequence=sequence,run=run,clientPath=clientPath,fractional=fractional,targetId=0x7f000000)
 packet=encode(c);decoded=receive(packet);assert decoded['result']==1
 move=next(v for v in decoded['calls']if v[0]=='move');assert move[2]==c['point']and move[3]==1 and move[4]==0x7f000000 and move[5]==run and move[8]==clientPath and move[9]==sequence and move[11]==fractional
 rows.append(dict(case=c,packet=packet.hex(),decoded=decoded))
for areaId,targetId,point,fractional in [(0xffffffff,0x8000007f,[0.,-0.,0.],2),(0x80000001,0xffffffff,[-12.75,3.125,319.75],255),(0x7f000000,0xff000000,[6.,3.,-20.],1)]:
 c=dict(format=1,areaId=areaId,point=point,sequence=127,run=1,clientPath=0,fractional=fractional,targetId=targetId);packet=encode(c);decoded=receive(packet);assert decoded['result']==1;rows.append(dict(case=c,packet=packet.hex(),decoded=decoded))

output=m.root/'backups/animations/native-network-walk-observations.json';output.write_text(json.dumps(dict(target=m.digest,limits=__doc__,cases=rows),indent=2)+'\n');print(json.dumps(dict(cases=len(rows),output=str(output))))
