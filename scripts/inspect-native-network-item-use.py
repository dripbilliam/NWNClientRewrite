"""Execute original item-use sender7c0610 and server4531b0 subtype9.
Message serialization/reading executes from the pinned PE. Transport, actor/
area lookup and final UseItem action are captured boundaries. No original
process, resource, gameplay state or credential is modified.
"""
import sys,importlib,json,itertools
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
t=importlib.import_module('inspect-native-message-text');w=t.w;m=w.m;u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(t.hook_handle)
client,actor,vt,area,point=[m.heap+n*0x1000 for n in range(20,25)]
ranges=[(0x1407c0610,0x1407c07b9),(0x1404531b0,0x140455858),(0x1409737f0,0x140973838)]
def hook(u,a,n,data):
 x,y,z,k=[u.reg_read(q)for q in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];sp=u.reg_read(UC_X86_REG_RSP)
 if a==0x1407c25c0:
  size=m.si(sp+0x28)&0xffffffff;sent.append(bytes([112,y&255,z&255])+bytes(u.mem_read(k,size))[3:]);m.finish(1);return
 if a==0x1404ba840:m.finish(0 if case.get('noActor')else actor);return
 if a==m.stop+0x60:m.finish(x);return
 if a==0x14037cbc0:calls.append(dict(kind='actionManager',operation=y&0xffffffff));m.finish();return
 if a==0x140494e80:calls.append(dict(kind='area'));m.finish(0 if case.get('noArea')else area);return
 if a==0x1403a9f70:
  calls.append(dict(kind='use',itemId=y&0xffffffff,propertyIndex=z&255,variant=k&255,targetId=m.si(sp+0x28)&0xffffffff,position=[m.rf(m.q(sp+0x30)+4*i)for i in range(3)],areaId=m.si(sp+0x38)&0xffffffff,flag=m.si(sp+0x40)));m.finish(case.get('useResult',1));return
 if any(lo<=a<hi for lo,hi in ranges):return
 t.hook(u,a,n,data)
u.hook_add(UC_HOOK_CODE,hook)
def run(c):
 global case,sent,calls
 case=c;sent=[];calls=[];t.reset(dict(format=c['format']));sp=m.stack+0x1fe08
 for i,v in enumerate(c['position']):m.wf(point+4*i,v)
 m.wi(sp+0x28,c['targetId']);m.wq(sp+0x30,point)
 w.call(0x1407c0610,[w.message,c['itemId'],c['propertyIndex'],c['variant']]);assert len(sent)==1
 packet=sent[0]
 u.mem_write(t.inputBase,packet[3:]+bytes([0xa5])*128);m.wi(sp+0x28,1);assert w.call(0x1402da7b0,[w.message,t.inputBase,len(packet)-3,0xffffffff])==1
 m.wq(actor,vt);m.wq(vt+0x60,m.stop+0x60);m.wi(actor+0x8ac,c.get('blocked',0));m.wi(actor+0xa0,0x7f000000 if c.get('noArea')else 7);m.wi(area+0x140,7)
 result=w.call(0x1404531b0,[w.message,client,9]);assert w.call(0x1402d9460,[w.message])==0;assert w.call(0x1402d9520,[w.message])==0
 return dict(case=c,packet=packet.hex(),result=result,calls=list(calls))
if __name__=='__main__':
 cases=[dict(format=f,itemId=item,propertyIndex=index,variant=variant,targetId=target,position=p)for f,item,index,variant,target,p in itertools.product([0,1],[0x80000002,0xffffffff],[0,7,255],[0,3,255],[0x7f000000,0x80000003,0xffffffff],[[0,0,0],[-0.,0,0],[1.25,-2.5,3.75],[1e-8,0,0]])]
 cases.extend(dict(format=1,itemId=0x80000002,propertyIndex=0,variant=255,targetId=0x7f000000,position=[1,2,3],**extra)for extra in [dict(noActor=True),dict(blocked=1),dict(noArea=True)])
 rows=[]
 for c in cases:
  try:rows.append(run(c))
  except Exception:print(json.dumps(dict(case=c,ip=hex(u.reg_read(UC_X86_REG_RIP)),calls=calls)),flush=True);raise
 out=m.root/'backups/animations/native-network-item-use-observations.json';out.write_text(json.dumps(dict(target=m.digest,limits=__doc__,cases=rows),indent=2)+'\n');print(json.dumps(dict(cases=len(rows),output=str(out))))
