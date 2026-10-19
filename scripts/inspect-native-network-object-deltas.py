"""Original UpdateObject owner for positional/orientation/animation records.

Real scalar/range writers execute. GetGameObject and the non-creature virtual
cast are captured fixture boundaries. No AI, world simulation or live mutation.
These fixtures cover masks0..7 for type9, not the complete replication owner.
"""
import sys,importlib,json,struct
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
t=importlib.import_module('inspect-native-message-text');w=t.w;r=t.r;m=w.m;u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(t.hook_handle)
obj,controlled,player,vtable=[m.heap+n*0x1000 for n in [9,10,11,12]]
ranges=[(0x1404eb590,0x1404edc50),(0x1402db320,0x1402db5a0),(0x1402dacb0,0x1402dad90),(0x1402d98d0,0x1402d9960)]
def hook(u,a,n,data):
 if a==0x1404ba840:m.finish(controlled);return
 if a==m.stop+0x100:m.finish(0);return
 if any(lo<=a<hi for lo,hi in ranges):return
 t.hook(u,a,n,data)
u.hook_add(UC_HOOK_CODE,hook)
rows=[]
for format in [0,1]:
 for mask in range(8):
  for point in [[1.234,2.345,3.456],[12.345,23.456,-20],[655.35,0,320]]:
   t.reset(dict(format=format));m.wq(obj,vtable);m.wq(vtable+0x60,m.stop+0x100);m.wi(obj+8,0x123456);u.mem_write(obj+0xc,bytes([9]));u.mem_write(obj+0xa4,struct.pack('<fff',*point));u.mem_write(obj+0xb0,struct.pack('<fff',0.4,-0.6,0.8));m.wi(obj+0xd8,42);u.mem_write(obj+0xdc,struct.pack('<f',1.75));m.wi(m.stack+0x1fe08+0x28,mask);m.wi(m.stack+0x1fe08+0x30,0)
   w.call(0x1404eb590,[w.message,player,obj,0]);packet=bytes.fromhex(w.snapshot()['hex'])
   # Execute original scalar/range readers against the emitted record. The
   # already-known raw OBJECTID is a captured four-byte cursor boundary here.
   u.mem_write(t.inputBase,packet[3:]);m.wi(m.stack+0x1fe08+0x28,1);assert w.call(0x1402da7b0,[w.message,t.inputBase,len(packet)-3,0xffffffff])==1
   assert w.call(0x1402d98d0,[w.message,8])&255==ord('U');assert w.call(0x1402d9630,[w.message,8,1])==9;m.wi(w.message+0x44,m.si(w.message+0x44)+4);assert w.call(0x1402d9bc0,[w.message,32])==mask
   def floating(scale=1,bits=32,minmax=None):
    if minmax:w.call(0x1402d9d40,[w.message,0,0,bits],minmax)
    else:w.call(0x1402d9c30,[w.message,0,bits,0],[scale])
    return struct.unpack('<f',struct.pack('<I',u.reg_read(UC_X86_REG_XMM0)&0xffffffff))[0]
   observed={}
   if mask&1:observed['position']=[floating(100,16),floating(100,16),floating(bits=18,minmax=[-20,320])]
   if mask&2:
    assert w.call(0x1402d9600,[w.message])==1;observed['orientation']=[floating(bits=16,minmax=[-2,2])for _ in range(3)]
   if mask&4:observed['animationTime']=floating();observed['animation']=w.call(0x1402da450,[w.message,16])
   assert w.call(0x1402d9460,[w.message])==0 and w.call(0x1402d9520,[w.message])==0
   rows.append(dict(format=format,mask=mask,point=point,packet=packet.hex(),observed=observed))
output=m.root/'backups/animations/native-network-object-delta-observations.json';output.write_text(json.dumps(dict(target=m.digest,limits=__doc__,cases=rows),indent=2)+'\n');print(json.dumps(dict(cases=len(rows),output=str(output))))
