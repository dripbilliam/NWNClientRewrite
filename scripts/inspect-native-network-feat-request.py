"""Original feat sender7c04e0 -> complete4531b0 subtype6; mode sender7c02e0.
Native serialization and feat server routing execute. Lookup/area/finalUseFeat
and transport are captured boundaries. Mode packets are sender-only evidence,
not mode validation/effect simulation. Unmodified hash-pinned original code.
"""
import sys,importlib,json,itertools
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
t=importlib.import_module('inspect-native-message-text');w=t.w;m=w.m;u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(t.hook_handle);client,actor,vt,area,point=[m.heap+n*0x1000 for n in range(20,25)]
ranges=[(0x1404531b0,0x140455858),(0x1409737f0,0x140973838)]
for name in ['input-sender','mode-sender']:
 d=json.loads((m.root/f'backups/animations/rea-network-feat-{name}.json').read_text())['structuredContent']['raw_result']['value'];ranges.extend((int(r['start'],16),int(r['end'],16)+1)for r in d['procedure']['body']['ranges'])
def hook(u,a,n,data):
 x,y,z,k=[u.reg_read(q)for q in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];sp=u.reg_read(UC_X86_REG_RSP)
 if a==0x1407c25c0:size=m.si(sp+0x28)&0xffffffff;sent.append(bytes([112,y&255,z&255])+bytes(u.mem_read(k,size))[3:]);m.finish(1);return
 if a==0x1404ba840:m.finish(0 if c.get('noActor')else actor);return
 if a==m.stop+0x60:m.finish(x);return
 if a==0x140494e80:calls.append(dict(kind='area'));m.finish(0 if c.get('noArea')else area);return
 if a==0x1403a91d0:calls.append(dict(kind='feat',featId=y&65535,auxiliary=z&65535,targetId=k&0xffffffff,areaId=m.si(sp+0x28)&0xffffffff,position=[m.rf(m.q(sp+0x30)+i*4)for i in range(3)]));m.finish(c.get('addResult',1));return
 if any(lo<=a<hi for lo,hi in ranges):return
 t.hook(u,a,n,data)
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,calls,sent
 c=case;calls=[];sent=[];t.reset(dict(format=c['format']));sp=m.stack+0x1fe08
 if c['kind']=='mode':w.call(0x1407c02e0,[w.message,c['mode'],c['targetId']])
 else:
  if c['point']is not None:
   for i,v in enumerate(c['point']):m.wf(point+i*4,v)
  m.wq(sp+0x28,point if c['point']is not None else 0);w.call(0x1407c04e0,[w.message,c['featId'],c['auxiliary'],c['targetId']])
 if not sent:return dict(case=c,packet=None,calls=[])
 assert len(sent)==1;packet=sent[0];result=None
 if c['kind']=='feat':
  u.mem_write(t.inputBase,packet[3:]+bytes([0xa5])*128);m.wi(sp+0x28,1);assert w.call(0x1402da7b0,[w.message,t.inputBase,len(packet)-3,0xffffffff])==1
  m.wq(actor,vt);m.wq(vt+0x60,m.stop+0x60);m.wi(actor+0x8ac,c.get('blocked',0));m.wi(area+0x140,7);result=w.call(0x1404531b0,[w.message,client,6]);assert w.call(0x1402d9460,[w.message])==0;assert w.call(0x1402d9520,[w.message])==0
 return dict(case=c,packet=packet.hex(),result=result,calls=list(calls))
ids=[0x7f000000,0x80000002,0xffffffff]
cases=[dict(kind='feat',format=f,featId=id,auxiliary=aux,targetId=target,point=p)for f,id,aux,target,p in itertools.product([0,1],[0,303,65535],[0,65001,65535],ids,[None,[0,0,0],[1.25,-2.5,3.75]])]
for target,extra in itertools.product(ids,[dict(noActor=True),dict(blocked=1),dict(noArea=True),dict(addResult=0)]):cases.append(dict(kind='feat',format=1,featId=303,auxiliary=0,targetId=target,point=[1,2,3])|extra)
cases.extend(dict(kind='mode',format=f,mode=mode,targetId=target)for f,mode,target in itertools.product([0,1],range(256),ids))
rows=[]
for c in cases:
 try:rows.append(run(c))
 except Exception:print(json.dumps(dict(case=c,ip=hex(u.reg_read(UC_X86_REG_RIP)))));raise
out=m.root/'backups/animations/native-network-feat-request-observations.json';out.write_text(json.dumps(dict(target=m.digest,limits=__doc__,cases=rows),indent=2)+'\n');print(json.dumps(dict(cases=len(rows),output=str(out))))
