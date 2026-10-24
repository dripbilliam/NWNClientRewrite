"""Execute complete hash-pinned skill writer7c0860, object wrapper805480 and
full input dispatcher4531b0 subtype7 in isolated Unicorn memory. Native scalar
codecs execute. Transport, controlled actor/area lookup and final UseSkill are
captured boundaries; skill success, action execution and network are not tested.
No original process or file is modified, and no original asset bytes are saved.
"""
import sys,importlib,json,itertools,argparse
from pathlib import Path
root=Path(__file__).resolve().parents[2];sys.path.insert(0,str(root/'scripts'))
t=importlib.import_module('inspect-native-message-text');w=t.w;m=w.m;u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(t.hook_handle)
client,actor,vt,area,point=[m.heap+n*0x1000 for n in range(20,25)]
ranges=[(0x1407c0860,0x1407c096c),(0x140805480,0x1408054f6),(0x1409737f0,0x140973838),(0x1404531b0,0x140455859)]
def hook(u,address,size,data):
 x,y,z,k=[u.reg_read(r)for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];sp=u.reg_read(UC_X86_REG_RSP)
 if address==0x1407c25c0:
  length=m.si(sp+0x28)&0xffffffff;sent.append(bytes([112,y&255,z&255])+bytes(u.mem_read(k,length))[3:]);m.finish(1);return
 if address==0x1406abf90:m.finish(0 if c.get('noMessage')else w.message);return
 if address==0x1404ba840:m.finish(0 if c.get('noActor')else actor);return
 if address==m.stop+0x60:m.finish(x);return
 if address==0x140494e80:m.finish(0 if c.get('noArea')else area);return
 if address==0x1403aa390:
  p=m.q(sp+0x28);calls.append(dict(skillId=y&255,mode=z&255,targetId=k&0xffffffff,position=[m.rf(p+i*4)for i in range(3)],areaId=m.si(sp+0x30)&0xffffffff,itemId=m.si(sp+0x38)&0xffffffff,force=m.si(sp+0x40)));m.finish(1);return
 if any(lo<=address<hi for lo,hi in ranges):return
 t.hook(u,address,size,data)
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,sent,calls
 c=case;sent=[];calls=[];t.reset(dict(format=c['format']));sp=m.stack+0x1fe08
 if c['kind']=='wrapper':w.call(0x140805480,[actor,c['packedSkill'],c['targetId']])
 else:
  for i,value in enumerate(c['point']):m.wf(point+i*4,value)
  m.wq(sp+0x28,point);w.call(0x1407c0860,[w.message,c['packedSkill']&255,(c['packedSkill']>>16)&255,c['targetId']])
 if not sent:return dict(case=c,packet=None,calls=[])
 assert len(sent)==1
 packet=sent[0];offset=u.mem_read(w.message+0x2c,1)[0];byte_length=m.si(w.message+0x14)
 u.mem_write(t.inputBase,packet[3:]+bytes([0xa5])*128);m.wi(sp+0x28,1);assert w.call(0x1402da7b0,[w.message,t.inputBase,len(packet)-3,0xffffffff])==1
 m.wq(actor,vt);m.wq(vt+0x60,m.stop+0x60);m.wi(actor+0x8ac,c.get('blocked',0));m.wi(area+0x140,7)
 result=w.call(0x1404531b0,[w.message,client,7])
 assert w.call(0x1402d9460,[w.message])==0 and w.call(0x1402d9520,[w.message])==0
 return dict(case=c,packet=packet.hex(),lastBitOffset=offset,byteLength=byte_length,result=result,calls=list(calls))
skills=[0,4,9,10,13,14,18,22,255,0x660002,0xffff0009,0x80000000,0xffffffff]
ids=[0x7f000000,0x80000002,0xffffffff]
cases=[dict(kind='writer',format=f,packedSkill=s,targetId=i,point=p)for f,s,i,p in itertools.product([0,1],skills,ids,[[0,0,0],[1.25,-2.5,3.75]])]
cases.extend(dict(kind='wrapper',format=f,packedSkill=s,targetId=i,point=[0,0,0])for f,s,i in itertools.product([0,1],skills,ids))
for extra in [dict(noActor=True),dict(blocked=1),dict(noArea=True)]:cases.append(dict(kind='writer',format=1,packedSkill=0x660002,targetId=0x80000002,point=[1,2,3])|extra)
cases.append(dict(kind='wrapper',format=1,packedSkill=4,targetId=0x80000002,point=[0,0,0],noMessage=True))
rows=[]
for case in cases:
 try:rows.append(run(case))
 except Exception:print(json.dumps(dict(case=case,ip=hex(u.reg_read(UC_X86_REG_RIP)))));raise
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--report',default='godot-client/reports/native-skill-request-observations-v2.json')
args=parser.parse_args()
output=(root/args.report).resolve()
assert output.is_relative_to(root/'godot-client/reports'), 'Report must stay in project reports'
assert not output.exists(), 'Existing evidence is preserved; choose a new report name'
with output.open('x',encoding='utf-8') as report: report.write(json.dumps(dict(binarySha256=m.digest,scope=__doc__,cases=rows),indent=2)+'\n')
print(json.dumps(dict(cases=len(rows),output=str(output))))
