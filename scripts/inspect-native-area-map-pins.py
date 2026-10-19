"""Verified bounded LoadArea1407dd55c..1407dd7ee, both complete initial
pin loops. Not the entire LoadArea, subsequent sound/profiling/error paths or
scene creation. Real native message writer/readers, localized/CString owners
and append execute; pin ctor/position and TLK are captured lower boundaries.
Fixture XMM8=1 comes from LoadArea1407dc1ca; no live changes or asset copies.
"""
import importlib,json,itertools,sys,struct
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
b=importlib.import_module('inspect-native-map-pin-messages');m=b.m;u=b.u;w=b.w;t=b.t;r=b.r
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(b.handle)
def hook(u,a,n,_):
 if 0x1407dd55c<=a<0x1407dd7ee:return
 b.hook(u,a,n,_)
handle=u.hook_add(UC_HOOK_CODE,hook)

def writeString(data):
 raw=bytes.fromhex(data);buf=m.heap+w.cursor;w.cursor+=(len(raw)+16)&~15;u.mem_write(buf,raw+b'\0');m.wq(t.owned,buf);m.wi(t.owned+8,len(raw));m.wi(t.owned+12,len(raw)+1);w.call(0x1402dab50,[w.message,t.owned,32,0])

def run(c):
 b.case=c;b.phase='sender';b.trace=[];t.reset(c)
 w.call(0x1402db5a0,[w.message,c.get('waypointCount',len(c['waypoints'])),32,0])
 for pin in c['waypoints']:
  w.call(0x1404763e0,[w.message,pin['id'],0,0])
  for value in pin['point']:w.call(0x1402db240,[w.message,0,0,32],[value,1])
  w.call(0x1402da920,[w.message,pin['enabled'],0,0]);t.populateLoc(t.loc,pin['note']);w.call(0x140476160,[w.message,t.loc,0,0])
 w.call(0x1402db5a0,[w.message,c.get('userCount',len(c['users'])),32,0])
 for pin in c['users']:
  w.call(0x1402db5a0,[w.message,pin['id'],32,0]);writeString(pin['text'])
  for value in pin['point']:w.call(0x1402db240,[w.message,0,0,32],[value,1])
 snapshot=w.snapshot();body=bytes.fromhex(snapshot['hex'])[3:];u.mem_write(r.packet,body);m.wi(m.stack+0x1fe30,1);w.call(0x1402da7b0,[w.message,r.packet,len(body),42]);b.phase='client';b.trace=[]
 m.wq(0x1412df968,b.talkPtr);u.mem_write(b.talkPtr+0x28,b'\x07');u.reg_write(UC_X86_REG_RSP,m.stack+0x1fb00);u.reg_write(UC_X86_REG_RBP,m.stack+0x1fd00);u.reg_write(UC_X86_REG_RDI,b.areaPtr);u.reg_write(UC_X86_REG_RSI,w.message);u.reg_write(UC_X86_REG_R14,0);u.reg_write(UC_X86_REG_XMM8,0x3f800000)
 u.emu_start(0x1407dd55c,0x1407dd7ee,count=500000);assert u.reg_read(UC_X86_REG_RIP)==0x1407dd7ee
 pins=[]
 for i in range(m.si(b.areaPtr+0x2c0)):
  ptr=m.q(m.q(b.areaPtr+0x2b8)+i*8);pins.append(dict(id=m.si(ptr+0x188)&0xffffffff,type=m.si(ptr+0x18c),enabled=m.si(ptr+0x170),position=[m.rf(ptr+0x38+j*4)for j in range(3)],text=t.stringState(ptr+0x178)))
 return dict(case=c,bodyHex=body.hex(),pins=pins,trace=list(b.trace),state=r.state(),diagnostics=list(r.diagnostics),capacity=m.si(b.areaPtr+0x2c4))

if __name__=='__main__':
 rows=[];notes=[dict(strRef=0xffffffff,entries=[]),dict(strRef=123,entries=[]),dict(strRef=123,entries=[dict(key=0,hex='4e6f746580')])]
 for mode,number,users,note,status in itertools.product([0,1],[0,1,2],[0,1,2],notes,[0,1]):
  c=dict(format=mode,talkStatus=status,waypoints=[dict(id=[0x7f000001,0xffffffff][i],point=[1.25,-2.75,3.5],enabled=[0,3][i],note=note)for i in range(number)],users=[dict(id=[0,0x80000001][i],text=['5573657280','410042'][i],point=[4.25,5.75,-6.5])for i in range(users)]);rows.append(run(c))
 for mode,waypointCount,userCount in itertools.product([0,1],[-1,0],[-1,0]):rows.append(run(dict(format=mode,waypoints=[],users=[],waypointCount=waypointCount,userCount=userCount)))
 out=m.root/'backups/animations/native-area-map-pin-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2));print(json.dumps(dict(output=str(out),rows=len(rows))))
