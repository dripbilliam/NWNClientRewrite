"""Original quickchat7c3770 -> full45cf80 -> full relay3d6c30.
Also original associate-replication adapter8693b0 -> captured GUI setter860760,
then original general shortcut85c8f0/types38,39,42 and actual native senders.
The GUI setter is explicitly modeled from its observed widget writes; lookup,
GetGameObject, final ReceiveAssociateCommand, response sender and transport are
captured boundaries. No local AI or native GUI execution claim at that boundary.
"""
import sys,importlib,json,itertools
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
t=importlib.import_module('inspect-native-message-text');w=t.w;m=w.m;u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(t.hook_handle)
actor,vt,player,pet1,pet2,app,server=[m.heap+n*0x1000 for n in range(20,27)]
gui=m.heap+0x40000;ids=m.heap+0x50000;ranges=[(0x1409737f0,0x140973838)]
for name in ['network-command-global-sender','network-command-server-quickchat','network-command-server-relay','network-associate-shortcut-replication','network-quickbar-general-activate','network-associate-command-sender','network-possess-familiar-sender','network-command-global-input']:
 d=json.loads((m.root/f'backups/animations/rea-{name}.json').read_text())['structuredContent']['raw_result']['value'];ranges.extend((int(r['start'],16),int(r['end'],16)+1)for r in d['procedure']['body']['ranges'])
def signed(v):return (v&0xffffffff)-(0x100000000 if v&0x80000000 else 0)
def hook(u,a,n,data):
 x,y,z,k=[u.reg_read(q)for q in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];sp=u.reg_read(UC_X86_REG_RSP)
 if a==0x1407c25c0:
  size=m.si(sp+0x28)&0xffffffff;sent.append(bytes([112,y&255,z&255])+(bytes(u.mem_read(k,size))[3:]if size else b''));m.finish(1);return
 if a==0x1406abf90:m.finish(0 if c.get('noClient')else w.message);return
 if a==0x1406abbe0:m.finish(0);return
 if a in [0x1406ac1a0,0x1404ba840]:m.finish(0 if c.get('noActor')else actor);return
 if a==0x140860760:calls.append(dict(kind='widget',packed=y&0xffffffff));m.finish();return
 if a==0x14055b3d0:
  oid=y&0xffffffff;calls.append(dict(kind='lookup',id=oid));m.finish({100:actor,200:pet1,201:pet2}.get(oid,0));return
 if a==0x1403d69f0:
  calls.append(dict(kind='receive',id=m.si(x+8)&0xffffffff,command=signed(y)))
  if c.get('mutate'):m.wi(ids+8,max(0,m.si(ids+8)-1))
  m.finish();return
 if a==0x1404df1c0:calls.append(dict(kind='response',id=y&0xffffffff,quickChat=z&65535));m.finish(1);return
 if any(lo<=a<hi for lo,hi in ranges):return
 t.hook(u,a,n,data)
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,calls,sent
 c=case;calls=[];sent=[];t.reset(dict(format=c['format']));sp=m.stack+0x1fe08
 m.wq(0x1412df970,app);m.wi(app+0x28,c['format']);m.wq(app+8,server);m.wi(actor+8,100);m.wi(pet1+8,200);m.wi(pet2+8,201)
 m.wi(actor+0x278,0x800000c8);m.wi(actor+0x27c,0xffffffff)
 if c['kind']=='chat':
  w.call(0x1407c3770,[w.message,c['quickChat']]);assert len(sent)==1;packet=sent[0];u.mem_write(t.inputBase,packet[3:]+bytes([0xa5])*128);m.wi(sp+0x28,1);assert w.call(0x1402da7b0,[w.message,t.inputBase,len(packet)-3,0xffffffff])==1
  values=c.get('ids',[200,777,201,200]);m.wq(actor+0x900,0 if c.get('noList')else ids);m.wq(ids,ids+0x100);m.wi(ids+8,len(values))
  for i,oid in enumerate(values):m.wi(ids+0x100+i*4,oid)
  result=w.call(0x14045cf80,[w.message,player,0]);assert w.call(0x1402d9460,[w.message])==0;assert w.call(0x1402d9520,[w.message])==0
  return dict(case=c,packet=packet.hex(),calls=list(calls),result=result)
 widget=gui+0xf0+c.get('index',0)*0x2c8
 if c['type']==39:
  m.wi(sp+0x28,c['associateId']);w.call(0x1408693b0,[gui,c.get('index',0),c['intParam'],c['associateType']]);packed=calls[-1]['packed'];m.wi(widget+0x118,packed)
 else:m.wi(widget+0x118,c.get('intParam',0))
 u.mem_write(widget+0x140,bytes([c['type']]));m.wi(widget+8,c.get('disabled',0));w.call(0x14085c8f0,[widget]);return dict(case=c,packets=[p.hex()for p in sent],calls=list(calls))
words=[0,1,4,9,10,22,26,27,255,256,32768,65535]
cases=[dict(kind='chat',format=f,quickChat=word)|extra for f,word,extra in itertools.product([0,1],words,[{},dict(noActor=True),dict(noList=True),dict(ids=[]),dict(mutate=True)])]
values=[-2147483648,-65535,-32769,-20,-9,-8,-5,0,65535,2147483647]
cases.extend(dict(kind='shortcut',format=f,type=39,associateId=oid,associateType=role,intParam=value,index=35)for f,oid,role,value in itertools.product([0,1],[0x7f000000,0x80000002,0xffffffff],[0,1,2,3,4,65535],values))
cases.extend(dict(kind='shortcut',format=f,type=kind,intParam=value)|extra for f,kind,value,extra in itertools.product([0,1],[38,42],values,[{},dict(noActor=True),dict(noClient=True),dict(disabled=1)]))
rows=[]
for c in cases:
 try:rows.append(run(c))
 except Exception:print(json.dumps(dict(case=c,ip=hex(u.reg_read(UC_X86_REG_RIP)))));raise
out=m.root/'backups/animations/native-network-party-command-observations.json';out.write_text(json.dumps(dict(target=m.digest,limits=__doc__,cases=rows),indent=2)+'\n');print(json.dumps(dict(cases=len(rows),output=str(out))))
