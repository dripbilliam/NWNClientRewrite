"""Original interaction senders and full server input dispatcher 1404531b0.

Native scalar/OBJECT_ID writers, readers and dispatch/validation execute intact.
Allocation/copy/logging, client GUI/group selection, controlled-object/target
lookup, reaction and queued action/event boundaries are captured. This does
not execute live AI actions, dialogue scripts, pathfinding or door effects.
"""
import sys,importlib,itertools,json
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
t=importlib.import_module('inspect-native-message-text');w=t.w;r=t.r;m=w.m;u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(t.hook_handle)
senders={'door':('network-client-door-request',0x1407bf860,3),'attack':('network-client-attack-request',0x1407bf180,2),'talk':('network-client-talk-request',0x1407bf900,8),'use':('network-client-use-request',0x1407c07c0,11)}
ranges=[]
for name in [v[0]for v in senders.values()]+['network-client-objectid-writer']:
 d=json.loads((m.root/'backups/animations'/('rea-'+name+'.json')).read_text())['structuredContent']['normalized_result']['procedure']
 ranges.extend((int(b['start'],16),int(b['end'],16)+1)for b in d['body']['ranges'])
d=json.loads((m.root/'backups/animations/rea-network-input-dispatch-procedure.json').read_text())['structuredContent']['normalized_result']['item']
ranges.extend((int(b['start'],16),int(b['end'],16)+1)for b in d['body']['ranges'])
client,actor,target,vt,stats,roundPtr,update,updateState=[m.heap+n*0x1000 for n in range(10,18)]
current={};calls=[];sent=[]
def hook(u,a,n,data):
 x,y,z,k=[u.reg_read(reg)for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];sp=u.reg_read(UC_X86_REG_RSP)
 if a==0x1407c25c0:
  size=m.si(sp+0x28)&0xffffffff;packet=bytearray(u.mem_read(k,size));packet[:3]=bytes([112,y&255,z&255]);sent.append(bytes(packet));m.finish(1);return
 if a==0x1406daac0:m.finish(0);return # no group selection; single controlled actor
 if a==0x1404ba840:m.finish(0 if current.get('noActor')else actor);return
 if a in [m.stop+0x10,m.stop+0x20]:m.finish(x);return
 if a==0x14055b4c0:m.finish(0 if current.get('missingTarget')else target);return
 if a==0x1404ab6c0:m.finish(current.get('reaction',0));return
 if a==0x14037cbc0:calls.append(['actionManager',y&0xffffffff]);m.finish();return
 if a in [0x14048dc70,0x14048d750]:calls.append(['open'if a==0x14048dc70 else'close',y&0xffffffff,z&0xffffffff]);m.finish();return
 if a==0x14037d180:calls.append(['attack',y&0xffffffff,z&0xffffffff,k&0xffffffff,m.si(sp+0x28)&0xffffffff]);m.finish();return
 if a==0x140375570:calls.append(['clearSpecial']);m.finish();return
 if a==0x14048cb80:calls.append(['addAction',y&0xffff,z&0xffff,k&0xffffffff,m.si(m.q(sp+0x28))&0xffffffff]);m.finish();return
 if a==0x1404ab5b0:calls.append(['use',y&0xffffffff]);m.finish();return
 if a==0x14055b960:m.finish(stats);return
 if a==0x1404c6490:m.finish(x);return
 if a==0x1405570b0:calls.append(['event',y&0xffffffff,z&0xffffffff,k&0xffffffff,m.si(sp+0x28)&0xffffffff,m.si(sp+0x30)&0xffffffff,m.si(m.q(sp+0x38))&0xffff]);m.finish(1);return
 if a==0x140559cb0:calls.append(['aiLevel',z&0xffffffff]);m.finish();return
 if any(lo<=a<hi for lo,hi in ranges):return
 t.hook(u,a,n,data)
u.hook_add(UC_HOOK_CODE,hook)
def encode(c):
 global sent,current,calls
 current=c;sent=[];calls=[];t.reset(dict(format=c['format']))
 args=[w.message,c['targetId'],c.get('action',0),c.get('flag1',0)]
 if c['kind']=='use':args[2]=c['flag0']
 w.call(senders[c['kind']][1],args);assert len(sent)==1
 return sent[0]
def receive(packet,c):
 global current,calls
 current=c;calls=[];u.mem_write(t.inputBase,packet[3:]+bytes([0xa5])*128);sp=m.stack+0x1fe08;m.wi(sp+0x28,1)
 assert w.call(0x1402da7b0,[w.message,t.inputBase,len(packet)-3,0xffffffff])==1
 for p in [client,actor,target,vt,stats,roundPtr,update,updateState]:u.mem_write(p,bytes(0x1000))
 m.wq(actor,vt);m.wq(target,vt);m.wq(vt+0x60,m.stop+0x10);m.wq(vt+0x20,m.stop+0x20);m.wq(actor+0xad0,stats);m.wq(actor+0x880,roundPtr);m.wi(actor+0xec,c.get('commandable',1));m.wi(actor+0x8ac,c.get('blocked',0));m.wi(actor+8,99);m.wi(actor+0x7c,1);m.wq(client+0x98,update);m.wq(update+0x18,updateState)
 result=w.call(0x1404531b0,[w.message,client,senders[c['kind']][2],0]);return dict(result=result,calls=list(calls),flag0=m.si(updateState+4),reader=r.state())
rows=[]
for format,targetId in itertools.product([0,1],[0x80000002,0xffffffff,0x7f000000]):
 for kind in senders:
  fields=[dict(action=v)for v in [0,21,22,65535]]if kind=='door'else[dict(flag0=a,flag1=b)for a,b in itertools.product([0,1],[0,1])]if kind=='use'else[{}]
  for field in fields:
   c=dict(format=format,targetId=targetId,kind=kind,**field);packet=encode(c);decoded=receive(packet,c)
   expected=targetId&0x7fffffff
   if kind=='door':assert decoded['calls']==[['actionManager',2],['open'if c['action']==21 else'close',expected,1]]
   if kind=='attack':assert decoded['calls']==[['attack',expected,0,1,0],['clearSpecial']]
   if kind=='talk':assert decoded['calls'][-1]==['addAction',24,65535,3,expected]
   if kind=='use':assert decoded['calls'][-2:]==[['actionManager',2],['use',expected]]and decoded['flag0']==c['flag0']
   rows.append(dict(case=c,packet=packet.hex(),decoded=decoded))
for kind,extra in itertools.product(senders,[dict(noActor=True),dict(blocked=1),dict(commandable=0),dict(reaction=2),dict(missingTarget=True)]):
 c=dict(format=1,targetId=0x80000002,kind=kind,action=21,flag0=0,flag1=0,**extra);packet=encode(c);decoded=receive(packet,c)
 if extra.get('noActor')or extra.get('blocked'):assert decoded['calls']==[]
 if kind=='talk'and(extra.get('commandable')==0 or extra.get('reaction')==2):assert decoded['calls']==[]
 rows.append(dict(case=c,packet=packet.hex(),decoded=decoded))
output=m.root/'backups/animations/native-network-interaction-observations.json';output.write_text(json.dumps(dict(target=m.digest,limits=__doc__,cases=rows),indent=2)+'\n');print(json.dumps(dict(cases=len(rows),output=str(output))))
