"""Original drive/abort/orientation senders and whole server drive/abort handlers.

Real native scalar codecs execute. Transport, lookup, area, sticky modes and
action insertion are captured boundaries; no live process writes or assets.
"""
import sys,importlib,json,itertools
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
t=importlib.import_module('inspect-native-message-text');w=t.w;r=t.r;m=w.m;u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(t.hook_handle)
ranges=[(0x1409737f0,0x140973838)]
for name in ['drive-send-native','abort-send-native','orientation-sender','drive-handler','abort-handler']:
 d=json.loads((m.root/'backups/animations'/f'rea-arelith-keyboard-{name}-v1.json').read_text())['structuredContent']['normalized_result']
 ranges.extend((int(x['start'],16),int(x['end'],16)+1)for x in d['procedure']['body']['ranges'])
client,actor,area,vt,roundPtr,head,node=[m.heap+n*0x1000 for n in [10,11,12,13,14,15,16]]

def hook(u,a,n,data):
 x,y,z,k=[u.reg_read(reg)for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];sp=u.reg_read(UC_X86_REG_RSP)
 if a==0x1407c25c0:
  size=m.si(sp+0x28)&0xffffffff;packet=bytearray(u.mem_read(k,size))if size else bytearray(3)
  packet[:3]=bytes([112,y&255,z&255]);sent.append(bytes(packet));m.finish(1);return
 if a==0x1404ba840:m.finish(actor);return
 if a==m.stop+0x10:m.finish(x);return
 if a==0x140494e80:m.finish(area);return
 if a==0x14055b9c0:m.finish(0);return
 if a==0x1403d8c50:calls.append(['mode',y&255,z&0xffffffff]);m.finish();return
 if a==0x140375570:calls.append(['clearSpecial']);m.finish();return
 if a==0x140490b80:calls.append(['clearActions']);m.finish();return
 if a==0x14037cbc0:calls.append(['actionManager',y&0xffffffff]);m.finish();return
 if a==0x14037e880:
  calls.append(['drive',y&65535,[m.rf(z+i)for i in [0,4,8]],k&0xffffffff,m.si(sp+0x28),m.si(sp+0x30),m.si(sp+0x38)]);m.finish(1);return
 if any(lo<=a<hi for lo,hi in ranges):return
 t.hook(u,a,n,data)
hook_handle=u.hook_add(UC_HOOK_CODE,hook)

def encode(c):
 global sent,calls
 sent=[];calls=[];t.reset(dict(format=1));point=m.heap+0x9000
 for i,v in enumerate(c.get('position',[0,0])):m.wf(point+i*4,v)
 sp=m.stack+0x1fe08
 if c['kind']=='drive':
  m.wi(sp+0x28,c['sequence']);m.wi(sp+0x30,c['flags'])
  w.call(0x1407bf980,[w.message,point,c['areaId'],c['heading']])
 elif c['kind']=='orientation':w.call(0x1407c03b0,[w.message,point])
 else:w.call(0x1407bf040,[w.message])
 assert len(sent)==1
 return sent[0]

def receive(c,packet,commandable=1,action=0x33):
 global calls
 calls=[];u.mem_write(t.inputBase,packet[3:]+bytes([0xa5])*128);m.wi(m.stack+0x1fe08+0x28,1)
 assert w.call(0x1402da7b0,[w.message,t.inputBase,len(packet)-3,0xffffffff])==1
 for ptr in [actor,area,vt,roundPtr,head,node]:u.mem_write(ptr,bytes(0x1000))
 m.wq(actor,vt);m.wq(vt+0x60,m.stop+0x10);m.wq(actor+0x880,roundPtr);m.wi(actor+0xec,commandable)
 m.wi(area+0x140,c.get('areaId',0x80000001)&0x7fffffff)
 m.wq(actor+0x100,head);m.wq(head,head+0x100);m.wq(head+0x110,node);m.wi(node,action);m.wi(node+0x60,7)
 result=w.call(0x140452ec0 if c['kind']=='drive'else 0x140452ba0,[w.message,client])
 return dict(result=result,calls=list(calls),continuation=m.si(node+0x60),reader=r.state())

rows=[]
for flags,sequence,heading in itertools.product([1,2,3,4,8,7,11,0x13,0x23],[0,255],[0,900,3599]):
 c=dict(kind='drive',position=[12.25,-3.5],areaId=0x80000001,heading=heading,sequence=sequence,flags=flags)
 packet=encode(c);d=receive(c,packet);assert d['result']==1
 drive=next(x for x in d['calls']if x[0]=='drive');assert drive==['drive',65535,[12.25,-3.5,0.0],heading,sequence,flags,2],drive
 rows.append(dict(case=c,packet=packet.hex(),decoded=d))
for commandable,action in itertools.product([0,1],[0x33,0x3e]):
 c=dict(kind='abort');packet=encode(c);d=receive(c,packet,commandable,action)
 assert d['continuation']==(0 if commandable==1 and action==0x33 else 7)
 rows.append(dict(case={**c,'commandable':commandable,'action':action},packet=packet.hex(),decoded=d))
for p in [[1.,0.],[0.,1.],[-1.,0.],[0.,-1.]]:
 c=dict(kind='orientation',position=p);rows.append(dict(case=c,packet=encode(c).hex()))
out=m.root/'backups/animations/native-network-drive-v1.json'
out.write_text(json.dumps(dict(target=m.digest,limits=__doc__,cases=rows),indent=2)+'\n');print(json.dumps(dict(cases=len(rows),output=str(out))))
