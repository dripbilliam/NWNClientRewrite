"""Original sender7bf0e0 -> complete4531b0 subtype27, native writers/readers.
Creature lookup, GetAssociateId, final ReceiveAssociateCommand and transport are
captured boundaries. This proves routing/ownership/redirection, not server AI
or the unpossession owner. Existing associate-command oracle covers the latter
receiver dispatch separately. Unmodified hash-pinned original code only.
"""
import sys,importlib,json,itertools
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
t=importlib.import_module('inspect-native-message-text');w=t.w;m=w.m;u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(t.hook_handle)
client,actor,vt,target,app,server=[m.heap+n*0x1000 for n in range(20,26)]
d=json.loads((m.root/'backups/animations/rea-network-associate-command-sender.json').read_text())['structuredContent']['raw_result']['value']
ranges=[(0x1404531b0,0x140455858),(0x1409737f0,0x140973838)]+[(int(r['start'],16),int(r['end'],16)+1)for r in d['procedure']['body']['ranges']]
def signed(v):return (v&0xffffffff)-(0x100000000 if v&0x80000000 else 0)
def hook(u,a,n,data):
 x,y,z,k=[u.reg_read(q)for q in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];sp=u.reg_read(UC_X86_REG_RSP)
 if a==0x1407c25c0:
  size=m.si(sp+0x28)&0xffffffff;sent.append(bytes([112,y&255,z&255])+bytes(u.mem_read(k,size))[3:]);m.finish(1);return
 if a==0x1404ba840:m.finish(0 if c.get('noActor')else actor);return
 if a==m.stop+0x60:m.finish(x);return
 if a==0x1403d4d70:calls.append(dict(kind='associate',type=y&65535,index=z&0xffffffff));m.finish(c.get('redirectId',777));return
 if a==0x14055b3d0:
  oid=y&0xffffffff;calls.append(dict(kind='lookup',id=oid));m.finish(target if not c.get('noTarget')and oid==c.get('resolvedId',decodedId)else 0);return
 if a==0x1403d69f0:calls.append(dict(kind='receive',id=m.si(x+8)&0xffffffff,command=signed(y)));m.finish();return
 if any(lo<=a<hi for lo,hi in ranges):return
 t.hook(u,a,n,data)
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,calls,sent,decodedId
 c=case;calls=[];sent=[];t.reset(dict(format=c['format']));sp=m.stack+0x1fe08
 w.call(0x1407bf0e0,[w.message,c['targetId'],c['command']]);assert len(sent)==1;packet=sent[0]
 u.mem_write(t.inputBase,packet[3:]+bytes([0xa5])*128);m.wi(sp+0x28,1);assert w.call(0x1402da7b0,[w.message,t.inputBase,len(packet)-3,0xffffffff])==1
 decodedId=c['targetId']if c['targetId']==0x7f000000 else c['targetId']&0x7fffffff
 m.wq(0x1412df970,app);m.wi(app+0x28,c['format']);m.wq(app+8,server);m.wq(actor,vt);m.wq(vt+0x60,m.stop+0x60)
 m.wi(actor+8,c.get('actorId',100));m.wi(actor+0x8ac,c.get('blocked',0));m.wi(target+8,c.get('resolvedId',decodedId));m.wi(target+0x8fc,c.get('masterId',100))
 result=w.call(0x1404531b0,[w.message,client,27]);assert w.call(0x1402d9460,[w.message])==0;assert w.call(0x1402d9520,[w.message])==0
 return dict(case=c,packet=packet.hex(),result=result,calls=list(calls))
ids=[0x7f000000,100,0x80000064,0x80000002,0xffffffff]
commands=[-2147483648,-23,-22,-21,-20,-19,-18,-13,-12,-10,-9,-8,-7,-5,-4,-3,-2,0,99,2147483647]
cases=[dict(format=f,targetId=oid,command=cmd,masterId=owner)for f,oid,cmd,owner in itertools.product([0,1],ids,commands,[100,777])]
for oid,cmd,extra in itertools.product(ids,[-19,-13,-5],[dict(noActor=True),dict(blocked=1),dict(noTarget=True)]):cases.append(dict(format=1,targetId=oid,command=cmd)|extra)
for oid,cmd in itertools.product([100,0x80000064],[-19,-13,-5]):cases.append(dict(format=1,targetId=oid,command=cmd,redirectId=777,resolvedId=777))
rows=[]
for c in cases:
 try:rows.append(run(c))
 except Exception:print(json.dumps(dict(case=c,ip=hex(u.reg_read(UC_X86_REG_RIP)))));raise
out=m.root/'backups/animations/native-network-associate-request-observations.json';out.write_text(json.dumps(dict(target=m.digest,limits=__doc__,cases=rows),indent=2)+'\n');print(json.dumps(dict(cases=len(rows),output=str(out))))
