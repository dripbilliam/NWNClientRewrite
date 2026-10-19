"""Original innate sender7bf6e0 -> complete4531b0 subtype35 plus full native
talent wrappers380fb0/380e20. Scalar/ID/vector encoding, packet reads and native
wrapper routing execute. Object/area/spell lookup, transport, feedback and final
cast queue insertion are captured. No effects, resource spend or live writes.
"""
import sys,importlib,json,struct,itertools
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
t=importlib.import_module('inspect-native-message-text');w=t.w;m=w.m;u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(t.hook_handle);client,actor,stats,vt,target,area,point=[m.heap+n*0x1000 for n in range(20,27)]
ranges=[(0x1404531b0,0x140455858),(0x140380fb0,0x140381205),(0x140380e20,0x140380fae),(0x1402303d0,0x14023040d),(0x140c7d6d8,0x140c7d783),(0x1409737f0,0x140973838)]
d=json.loads((m.root/'backups/animations/rea-network-spell-like-input-sender.json').read_text())['structuredContent']['raw_result']['value'];ranges.extend((int(r['start'],16),int(r['end'],16)+1)for r in d['procedure']['body']['ranges'])
def hook(u,a,n,data):
 x,y,z,k=[u.reg_read(q)for q in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];sp=u.reg_read(UC_X86_REG_RSP)
 if a==0x1407c25c0:size=m.si(sp+0x28)&0xffffffff;sent.append(bytes([112,y&255,z&255])+bytes(u.mem_read(k,size))[3:]);m.finish(1);return
 if a==0x1404ba840:m.finish(0 if c.get('noActor')else actor);return
 if a==m.stop+0x60:m.finish(x);return
 if a==0x1402af4a0:m.finish(0 if c.get('missingSpell')else point);return
 if a==0x14055b3d0:m.finish(0 if c.get('missingCreature')else target);return
 if a==0x140494e80:m.finish(0 if c.get('missingArea')else area);return
 if a==0x14037cbc0:calls.append(dict(kind='manager',value=y&0xffffffff));m.finish();return
 if a==0x1403a2480:calls.append(dict(kind='feedback',value=y&0xffffffff));m.finish();return
 if a==0x14037d540:
  calls.append(dict(kind='cast',spell=y&0xffffffff,classIndex=z&255,domainLevel=k&255,metamagic=m.si(sp+0x28)&255,conversion=m.si(sp+0x30),position=[m.rf(m.q(sp+0x38)+i*4)for i in range(3)],targetId=m.si(sp+0x40)&0xffffffff,location=m.si(sp+0x48),casterLevel=m.si(sp+0x80)&255));m.finish(c.get('addResult',1));return
 if any(lo<=a<hi for lo,hi in ranges):return
 t.hook(u,a,n,data)
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,calls,sent
 c=case;calls=[];sent=[];t.reset(dict(format=c['format']));sp=m.stack+0x1fe08;m.wq(0x1412df8f8,m.heap+0x30000);m.wq(m.heap+0x300d0,m.heap+0x30000)
 for i,v in enumerate(c['point']):m.wf(point+i*4,v)
 m.wi(sp+0x28,c['targetId']);w.call(0x1407bf6e0,[w.message,c['spellId'],c['casterLevel'],point]);assert len(sent)==1;packet=sent[0]
 u.mem_write(t.inputBase,packet[3:]+bytes([0xa5])*128);m.wi(sp+0x28,1);assert w.call(0x1402da7b0,[w.message,t.inputBase,len(packet)-3,0xffffffff])==1
 m.wq(actor,vt);m.wq(vt+0x60,m.stop+0x60);m.wq(actor+0xad0,0 if c.get('noStats')else stats);m.wi(actor+0x8ac,c.get('blocked',0));m.wi(actor+0xec,c.get('commandable',1));m.wi(area+0x140,7)
 for i,v in enumerate([4.25,5.5,6.75]):m.wf(target+0xa4+i*4,v)
 result=w.call(0x1404531b0,[w.message,client,35]);assert w.call(0x1402d9460,[w.message])==0;assert w.call(0x1402d9520,[w.message])==0;return dict(case=c,packet=packet.hex(),result=result,calls=list(calls))
points=[[0,0,0],[1.25,-2.5,3.75],[0,0,-.3],[1e-6,0,0],[1e-5,0,0],[6e-6,8e-6,0]]
cases=[dict(format=f,spellId=0x12345678,targetId=id,casterLevel=level,point=p)for f,id,level,p in itertools.product([0,1],[0x7f000000,0x80000002,0xffffffff],[0,7,15,255],points)]
base=dict(format=1,spellId=0x12345678,targetId=0x80000002,casterLevel=7,point=[1,2,3])
for targetId,extra in itertools.product([0x80000002,0x7f000000],[dict(noActor=True),dict(noStats=True),dict(blocked=1),dict(commandable=0),dict(missingSpell=True),dict(missingCreature=True),dict(missingArea=True),dict(addResult=0)]):cases.append(base|dict(targetId=targetId)|extra)
rows=[]
for c in cases:
 try:rows.append(run(c))
 except Exception:print(json.dumps(dict(case=c,ip=hex(u.reg_read(UC_X86_REG_RIP)))));raise
output=m.root/'backups/animations/native-network-spell-like-request-observations.json';output.write_text(json.dumps(dict(target=m.digest,limits=__doc__,cases=rows),indent=2)+'\n');print(json.dumps(dict(cases=len(rows),output=str(output))))
