"""Original client OBJECT_ID leaf and complete localized-string reader with
real message writers/setup/scalar/string readers. TLK lookup, optional ResRef
copy, logging and allocator boundaries are captured. No client scene, transport
or native asset copies. Server and client ID namespaces are kept distinct.
"""
import importlib,sys,json,itertools,struct
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
t=importlib.import_module('inspect-native-message-text');m=t.m;u=t.u;w=t.w;r=t.r
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(t.hook_handle);target,sound,duration,talk=[m.heap+i for i in [0x30000,0x30100,0x30200,0x30300]]

def hook(u,a,n,_):
 x,y,z,q=[u.reg_read(reg)for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
 if a==0x140198c60:
  trace.append(['talkString',y&0xffffffff,u.mem_read(talk+0x28,1)[0]])
  data=bytes.fromhex(case['text']);buf=m.heap+w.cursor;w.cursor+=(len(data)+16)&~15;u.mem_write(buf,data+b'\0');m.wq(z,buf);m.wi(z+8,len(data));m.wi(z+12,len(data)+1);u.mem_write(z+0x10,bytes.fromhex(case['soundRef']));m.wf(z+0x24,case['duration']);m.finish(case['status']);return
 if a==0x14018de80:u.mem_write(x,bytes(u.mem_read(y,17)));m.finish(x);return
 if a==0x140115890:trace.append(['warning','strRef']);m.finish();return
 if 0x1409735f0<=a<0x1409737b4 or 0x1409737c0<=a<0x1409737e8:return
 t.hook(u,a,n,_)
u.hook_add(UC_HOOK_CODE,hook)

def run(c):
 global case,trace
 case=c;trace=[];t.reset(dict(format=c['format']));m.wq(0x1412df968,talk);u.mem_write(talk+0x28,b'\x07')
 if c['kind']=='object':w.call(0x1404763e0,[w.message,c['id'],0,0])
 else:
  w.call(0x1402da920,[w.message,c['reference'],0,0])
  if c['reference']:
   w.call(0x1402da960,[w.message,c['gender'],1,1]);w.call(0x1402db150,[w.message,c['strRef'],32,0])
  else:
   raw=bytes.fromhex(c['text']);buf=m.heap+w.cursor;w.cursor+=(len(raw)+16)&~15;u.mem_write(buf,raw+b'\0');m.wq(t.owned,buf);m.wi(t.owned+8,len(raw));m.wi(t.owned+12,len(raw)+1);w.call(0x1402dab50,[w.message,t.owned,32,0])
 snapshot=w.snapshot();data=bytes.fromhex(snapshot['hex'])[3:];u.mem_write(r.packet,data);m.wi(m.stack+0x1fe30,1);w.call(0x1402da7b0,[w.message,r.packet,len(data),42])
 if c['kind']=='object':
  if 'cursor'in c:m.wi(w.message+0x44,c['cursor'])
  if 'declared'in c:m.wi(w.message+0x40,c['declared'])
  result=w.call(0x1409737c0,[w.message,0,0,0]);value=dict(id=result)
 else:
  u.mem_write(sound,bytes([0xa5])*17);m.wf(duration,99)
  w.call(0x1409735f0,[w.message,target,sound if c['soundOut'] else 0,duration if c['durationOut'] else 0]);value=t.stringState(target)
  value.update(soundRef=bytes(u.mem_read(sound,17)).hex() if c['soundOut'] else None,duration=m.rf(duration) if c['durationOut'] else None)
 return dict(case=c,bodyHex=data.hex(),value=value,state=r.state(),trace=trace,gender=u.mem_read(talk+0x28,1)[0],diagnostics=list(r.diagnostics))

rows=[]
for mode,id_ in itertools.product([0,1],[0,1,0x7f000000,0x7fffffff,0x80000000,0x80000001,0xffffffff]):
 rows.append(run(dict(kind='object',format=mode,id=id_)))
 for cursor,declared in [(4,4),(0xffffffff,0xffffffff),(0xfffffffd,0xffffffff)]:rows.append(run(dict(kind='object',format=mode,id=id_,cursor=cursor,declared=declared)))
for mode,reference,status,text_,soundOut,durationOut in itertools.product([0,1],[0,1],[-1,0,1,2],['','5465787480','0048656164','4162004364'],[False,True],[False,True]):
 rows.append(run(dict(kind='localized',format=mode,reference=reference,gender=3,strRef=0x10203040,status=status,text=text_,soundRef=(b'fixture_voice'.ljust(17,b'\0')).hex(),duration=1.25,soundOut=soundOut,durationOut=durationOut)))
out=m.root/'backups/animations/native-client-message-identity-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2));print(json.dumps(dict(output=str(out),rows=len(rows))))
