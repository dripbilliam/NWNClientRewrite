"""Complete original spell sender7bf4e0 -> server4531b0 subtype18.
Scalar/OBJECTID encoding, vector magnitude, field reading, conversion admission
and branch decisions execute unchanged. Spell/class/slot/control/config lookups,
transport, feedback, action manager and AddCastSpellActions are captured lower
boundaries. No original action execution, consumption, effects or live writes.
"""
import sys,importlib,json,struct,itertools
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
t=importlib.import_module('inspect-native-message-text');w=t.w;r=t.r;m=w.m;u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(t.hook_handle)
ranges=[(0x1402303d0,0x14023040d),(0x140c7d6d8,0x140c7d783),(0x1409737f0,0x140973838)]
for name in ['rea-network-spell-input-sender','rea-network-input-dispatch-procedure']:
 d=json.loads((m.root/f'backups/animations/{name}.json').read_text())['structuredContent'];p=(d.get('raw_result')or{}).get('value',{}).get('procedure')or d['normalized_result']['item'];ranges.extend((int(v['start'],16),int(v['end'],16)+1)for v in p['body']['ranges'])
client,actor,stats,vt,spell,master,rules,cfg,point=[m.heap+n*0x1000 for n in range(20,29)]
classInfo=m.heap+0x60000
def hook(u,a,n,data):
 x,y,z,k=[u.reg_read(q)for q in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];sp=u.reg_read(UC_X86_REG_RSP)
 if a==0x1407c25c0:
  size=m.si(sp+0x28)&0xffffffff;p=bytes(u.mem_read(k,size));sent.append(bytes([112,y&255,z&255])+p[3:]);m.finish(1);return
 if a==0x1404ba840:m.finish(0 if c.get('noActor')else actor);return
 if a==m.stop+0x10:m.finish(0 if c.get('badCast')else x);return
 if a==m.stop+0x68:m.finish(cfg);return
 if a==m.stop+0x38:m.finish(0);return
 if a==0x1402af4a0:
  if phase=='send':m.finish(0 if c.get('missingClientSpell')else spell)
  else:m.finish(0 if c.get('missingServerSpell')else master if (y&0xffffffff)==2 else spell)
  return
 if a==0x1403fa4a0:m.finish(c.get('classType',10));return
 if a==0x140409160:calls.append(dict(kind='uses',spell=y&0xffffffff,classIndex=z&255,domainLevel=k&255,metamagic=m.si(sp+0x28)&255));m.finish(c.get('uses',1));return
 if a==0x1402af530:m.finish(c.get('spellLevel',3));return
 if a==0x1402a3f70:m.finish(c.get('metaCost',1));return
 if a==0x140405770:m.finish(len(c.get('slots',[])));return
 if a in [0x140404db0,0x140402ff0]:m.finish(c['slots'][k&255].get('ready'if a==0x140404db0 else'domain',0));return
 if a==0x14037cbc0:calls.append(dict(kind='manager',value=y&0xffffffff));m.finish();return
 if a==0x1403a2480:calls.append(dict(kind='feedback',value=y&0xffffffff));m.finish();return
 if a==0x14037d540:
  calls.append(dict(kind='cast',spell=y&0xffffffff,classIndex=z&255,domainLevel=k&255,metamagic=m.si(sp+0x28)&255,conversion=m.si(sp+0x30),position=[m.rf(m.q(sp+0x38)+i*4)for i in range(3)],targetId=m.si(sp+0x40)&0xffffffff,path=m.si(sp+0x48),instant=m.si(sp+0x50),casterLevel=m.si(sp+0x58),projectilePath=m.si(sp+0x60)&255,cheat=m.si(sp+0x68),extra=m.si(sp+0x70),itemId=m.si(sp+0x78)&0xffffffff,itemProperty=m.si(sp+0x80)&255));m.finish(1);return
 if any(lo<=a<hi for lo,hi in ranges):return
 t.hook(u,a,n,data)
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,calls,sent,phase
 c=case;calls=[];sent=[];phase='send';t.reset(dict(format=c['format']));sp=m.stack+0x1fe08
 m.wq(0x1412df8f8,rules);m.wq(rules+0xd0,spell);m.wq(rules+0x110,classInfo);m.wi(spell+0x178,2);u.mem_write(spell+0x50,struct.pack('<H',c.get('targetType',127)));u.mem_write(master+0x18c,bytes([c.get('allowedMeta',255)]));m.wi(classInfo+10*0x530+0x520,c.get('classAllows',1))
 for i,v in enumerate(c['point']):m.wf(point+i*4,v)
 m.wi(sp+0x28,c['metamagic']);m.wi(sp+0x30,c['conversion']);m.wq(sp+0x38,point);m.wi(sp+0x40,c['targetId']);w.call(0x1407bf4e0,[w.message,c['spellId'],c['classIndex'],c['domainLevel']]);assert len(sent)==1;packet=sent[0]
 u.mem_write(t.inputBase,packet[3:]+bytes([0xa5])*128);m.wi(sp+0x28,1);assert w.call(0x1402da7b0,[w.message,t.inputBase,len(packet)-3,0xffffffff])==1
 phase='receive';m.wq(actor,vt);m.wq(vt+0x60,m.stop+0x10);m.wq(actor+0xad0,0 if c.get('noStats')else stats);m.wi(actor+0x8ac,c.get('blocked',0));m.wi(actor+0xec,c.get('commandable',1));m.wq(t.server,vt);m.wq(vt+0x68,m.stop+0x68);m.wq(vt+0x38,m.stop+0x38);m.wi(cfg+0x14c,c.get('strict',0));m.wi(client+0x48,17)
 result=w.call(0x1404531b0,[w.message,client,18]);assert w.call(0x1402d9460,[w.message])==0;assert w.call(0x1402d9520,[w.message])==0
 return dict(case=c,packet=packet.hex(),result=result,calls=list(calls))
points=[[0,0,0],[1.25,-2.5,3.75],[0,0,-.3],[1e-6,0,0],[9.999999e-6,0,0],[1e-5,0,0],[1.0000001e-5,0,0],[6e-6,8e-6,0]]
cases=[dict(format=f,spellId=0x12345678,targetId=id,point=p,classIndex=index,domainLevel=domain,metamagic=meta,conversion=conv)for f,id,p,(index,domain,meta),conv in itertools.product([0,1],[0x7f000000,0x80000002,0xffffffff],points,[(0,0,0),(7,9,33),(255,255,255)],[0,1])]
base=dict(format=1,spellId=0x12345678,targetId=0x80000002,point=[1,2,3],classIndex=0,domainLevel=0,metamagic=1,conversion=0)
for change in [dict(noActor=True),dict(badCast=True),dict(noStats=True),dict(blocked=1),dict(commandable=0),dict(missingClientSpell=True),dict(missingServerSpell=True),dict(uses=0),dict(allowedMeta=0),dict(strict=1),dict(strict=1,missingClientSpell=True)]:cases.append(base|change)
for slots,uses,allows,typ in itertools.product([[],[dict(ready=0,domain=0)],[dict(ready=1,domain=1)],[dict(ready=1,domain=0)]],[0,1],[0,1],[10,255]):cases.append(base|dict(conversion=1,slots=slots,uses=uses,classAllows=allows,classType=typ))
rows=[run(c)for c in cases];output=m.root/'backups/animations/native-network-spell-input-observations.json';output.write_text(json.dumps(dict(target=m.digest,limits=__doc__,cases=rows),indent=2)+'\n');print(json.dumps(dict(cases=len(rows),output=str(output))))
