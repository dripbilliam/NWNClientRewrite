"""Read-only original complete map-pin Created/Enabled senders and client
Created/Enabled handlers, with profiling disabled. Actual scalar, object-ID,
localized-string, language, CString and collection append/lookup code executes.
Transport, temporary-localized destruction, pin construction/position, TLK,
client-area/GUI lookup and GUI refresh are captured lower owners. Heap starts
A5. No live process, transport, game assets copied or complete map UI claim.
"""
import importlib,sys,json,itertools,struct
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
t=importlib.import_module('inspect-native-message-text');m=t.m;u=t.u;w=t.w;r=t.r
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(t.hook_handle)
clientPtr=m.heap+0xf000;pointPtr=clientPtr+0x100;areaPtr=m.heap+0xf1000;worldPtr=areaPtr+0x400;guiPtr=areaPtr+0x800;controlPtr=guiPtr+0x100;talkPtr=guiPtr+0x200
ranges=[(0x1404dc2d0,0x1404dc3ed),(0x1404dc3f0,0x1404dc486),(0x1407a3990,0x1407a3cad),(0x1407a3cb0,0x1407a3e7c),(0x1407d8e40,0x1407d8eca),(0x1407daeb0,0x1407daef0),(0x1409735f0,0x1409737b4),(0x1409737c0,0x1409737e8)]

def hook(u,a,n,_):
 global packet
 x,y,z,q=[u.reg_read(reg)for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];sp=u.reg_read(UC_X86_REG_RSP)
 if a==0x1404dc490:
  ptr=m.q(sp+0x28);length=m.si(sp+0x30)&0xffffffff;packet=bytes(u.mem_read(ptr,length));trace.append(['send',y&0xffffffff,z&255,q&255,length]);m.finish(case.get('sendResult',1));return
 if a==0x1401695b0:trace.append(['disposeLocalized']);m.finish();return
 if a==0x1402d5880 and case.get('payloadFail'):m.finish(0);return
 if a==0x1402d9520 and case.get('underflow'):trace.append(['underflow']);m.finish(1);return
 if a==0x1402d9460 and case.get('overflow'):trace.append(['overflow']);m.finish(1);return
 if a==0x1406abea0:trace.append(['area']);m.finish(worldPtr);return
 if a==0x140983020:
  trace.append(['construct']);m.wq(x,0x140e72800);m.wq(x+0x178,0);m.wq(x+0x180,0);m.wi(x+0x170,0);m.wi(x+0x18c,0);m.finish(x);return
 if a==0x140766760:
  values=[m.rf(y+i*4)for i in range(3)];trace.append(['position',values]);u.mem_write(x+0x38,bytes(u.mem_read(y,12)));m.finish();return
 if a==0x1406abbc0:trace.append(['gui']);m.finish(guiPtr if case.get('gui',True) else 0);return
 if a==0x140893c70:trace.append(['refresh',y&0xffffffff]);m.finish();return
 if a==0x140198c60:
  trace.append(['talkString',y&0xffffffff,u.mem_read(talkPtr+0x28,1)[0]]);data=bytes.fromhex(case.get('talkText','54616c6b80'));buf=m.heap+w.cursor;w.cursor+=(len(data)+16)&~15;u.mem_write(buf,data+b'\0');m.wq(z,buf);m.wi(z+8,len(data));m.wi(z+12,len(data)+1);m.finish(case.get('talkStatus',1));return
 if a==0x140115890 and phase=='client' and m.si(sp+0x28) not in [0x29e,0x15c,0x505,0x511,0x51c,0x528]:trace.append(['warning','strRef']);m.finish();return
 if any(lo<=a<hi for lo,hi in ranges):return
 t.hook(u,a,n,_)
handle=u.hook_add(UC_HOOK_CODE,hook)

def send(c):
 global case,trace,packet,phase
 case=c;trace=[];packet=None;phase='sender';t.reset(c);m.wi(clientPtr+0x48,c['playerId']);t.populateLoc(t.loc,c)
 for i,value in enumerate(c['point']):m.wf(pointPtr+i*4,value)
 sp=m.stack+0x1fe08;m.wq(sp+0x28,t.loc);m.wi(sp+0x30,c['enabled'])
 result=w.call(0x1404dc2d0 if c['kind']=='created' else 0x1404dc3f0,[w.message,clientPtr,c['id'],pointPtr if c['kind']=='created' else c['enabled']])
 return dict(case=c,result=result,packetHex=packet.hex() if packet is not None else None,trace=list(trace),diagnostics=list(r.diagnostics))

def receive(c,source):
 global case,trace,phase
 case=c;phase='client';t.reset(c);trace=[];body=bytes.fromhex(source['packetHex'])[3:];u.mem_write(r.packet,body);m.wi(m.stack+0x1fe30,1);w.call(0x1402da7b0,[w.message,r.packet,len(body),42])
 m.wq(worldPtr+0xf8,areaPtr);m.wq(guiPtr+0xb8,controlPtr if c.get('control',True) else 0);m.wq(0x1412df968,talkPtr);u.mem_write(talkPtr+0x28,b'\x07')
 if c.get('declaredDelta'):m.wi(w.message+0x40,m.si(w.message+0x40)+c['declaredDelta'])
 initial=c.get('initial',[])
 if initial:
  arr=m.heap+0x80000;m.wq(areaPtr+0x2b8,arr);m.wi(areaPtr+0x2c0,len(initial));m.wi(areaPtr+0x2c4,len(initial));t.sizes[arr]=len(initial)*8
  for i,p in enumerate(initial):
   ptr=m.heap+0x81000+i*0x200 if p else 0;m.wq(arr+i*8,ptr)
   if p:m.wi(ptr+0x188,p['id']);m.wi(ptr+0x18c,p['type']);m.wi(ptr+0x170,p['enabled'])
 result=w.call(0x1407a3990 if c['kind']=='created' else 0x1407a3cb0,[w.message,0,0,0]);pins=[]
 for i in range(m.si(areaPtr+0x2c0)):
  ptr=m.q(m.q(areaPtr+0x2b8)+i*8)
  if not ptr:pins.append(None);continue
  pin=dict(id=m.si(ptr+0x188)&0xffffffff,type=m.si(ptr+0x18c),enabled=m.si(ptr+0x170))
  if c['kind']=='created' and i>=len(initial):pin.update(position=[m.rf(ptr+0x38+i*4)for i in range(3)],text=t.stringState(ptr+0x178))
  pins.append(pin)
 return dict(case=c,bodyHex=body.hex(),result=result,pins=pins,trace=list(trace),state=r.state(),diagnostics=list(r.diagnostics),capacity=m.si(areaPtr+0x2c4))

if __name__=='__main__':
 senders=[];receivers=[]
 notes=[dict(strRef=0xffffffff,entries=[]),dict(strRef=123,entries=[]),dict(strRef=123,entries=[dict(key=0,hex='4d617080')]),dict(strRef=123,entries=[dict(key=2,hex='004869'),dict(key=0,hex='410042')]),dict(strRef=456,entries=[dict(key=2,hex='42'*200)])]
 for kind,mode,id_,enabled,note,point in itertools.product(['created','enabled'],[0,1],[0,1,0x7f000000,0x80000001,0xffffffff],[0,1,2,-1],notes,[[0,0,0],[1.25,-2.75,3.5],[1e12,-1e12,0.1]]):
  if kind=='enabled' and (note!=notes[0] or point!=[0,0,0]):continue
  c=dict(kind=kind,format=mode,id=id_,enabled=enabled,point=point,playerId=0x80000009,sendResult=-7,**note);row=send(c);senders.append(row)
  if mode==1 and id_==0x7f000000 and enabled in [0,2] and point==[0,0,0]:
   for failure,gui,control in itertools.product(['none','underflow','overflow'],[False,True],[False,True]):
    c2=dict(c,gui=gui,control=control,**({failure:True}if failure!='none'else {}));c2['initial']=[None,dict(id=id_,type=1,enabled=7),dict(id=id_,type=0,enabled=8),dict(id=id_,type=0,enabled=9)];receivers.append(receive(c2,row))
 for kind,payloadFail,sendResult,noServer in itertools.product(['created','enabled'],[False,True],[0,1,-1],[False,True]):
  c=dict(kind=kind,format=1,id=3,enabled=1,point=[2,3,4],playerId=0x80000009,payloadFail=payloadFail,sendResult=sendResult,noServer=noServer,**notes[0]);senders.append(send(c))
 for mode,language in itertools.product([0,1],[0,1,2]):
  c=dict(kind='created',format=mode,id=5,enabled=1,point=[1,2,3],playerId=0x80000009,sendResult=1,clients=[dict(id=0xffffffff,language=language),dict(id=0x80000009,language=2)],strRef=123,entries=[dict(key=0,hex='456e676c697368'),dict(key=2,hex='4672656e6368')]);senders.append(send(c))
 for kind,delta in itertools.product(['created','enabled'],[-1,1]):
  c=dict(kind=kind,format=1,id=3,enabled=1,point=[2,3,4],playerId=0x80000009,sendResult=1,**notes[0]);source=send(c);receivers.append(receive(dict(c,declaredDelta=delta,gui=True,control=True,initial=[dict(id=3,type=0,enabled=7)]),source))
 out=m.root/'backups/animations/native-map-pin-message-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,senders=senders,receivers=receivers),indent=2));print(json.dumps(dict(output=str(out),senders=len(senders),receivers=len(receivers))))
