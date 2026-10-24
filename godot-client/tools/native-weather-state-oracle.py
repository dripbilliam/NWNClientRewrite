"""Execute original weather requests1407e69a0/69e0, frame block8f21..903a
and visual setter1407e63c0. Synthetic C2DA/model objects; resource loading,
animation execution and sound/driver calls are explicit lower boundaries.
Original transition arithmetic, clamping, six-instance lifecycle and animation
rate requests execute unchanged. This does not establish precipitation pixels.
"""
from pathlib import Path
import sys,struct,json,importlib,itertools
root=Path(__file__).resolve().parents[2];sys.path.insert(0,str(root/'scripts'))
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
area,vt,rules,arrays,table,gv=[m.heap+n*0x1000 for n in range(6)]
allocate=m.heap+0x10000;next_model=m.heap+0x60000;created=removed=0;fades={};events=[]
def zstr(p):
 b=bytearray()
 for i in range(128):
  c=u.mem_read(p+i,1)[0]
  if c==0:return b.decode('ascii')
  b.append(c)
 raise RuntimeError('Invalid synthetic oracle string')
def f32reg(reg):return struct.unpack('<f',struct.pack('<I',u.reg_read(reg)&0xffffffff))[0]
def floatbits(p):return bytes(u.mem_read(p,4)).hex()
def hook(u,a,n,data):
 global allocate,next_model,created,removed
 x,y,z,w=[u.reg_read(reg) for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
 if a in [m.stop,0x1407e903a]:u.emu_stop();return
 if a==0x140c10368:
  value=allocate;allocate+=(x+31)&~15;m.finish(value);return
 if a==0x140c10370:m.finish();return
 if a==0x1401a7010:
  value=fades.get(str(y&255));m.wi(w,value if value is not None else 0);m.finish(int(value is not None));return
 if a==0x1401a68f0:
  column=zstr(m.q(z));value=('fixture_weather' if column=='Model' else 'fixture_anim') if y&255 else ''
  pointer=allocate;allocate+=64;u.mem_write(pointer,value.encode()+b'\0');m.wq(w,pointer);m.wi(w+8,len(value));m.wi(w+12,len(value)+1);m.finish(int(bool(value)));return
 if a==0x1400931f0:
  value=next_model;next_model+=0x200;m.wq(value,gv);created+=1;m.finish(value);return
 if a==m.stop+0x10:removed+=1;m.finish();return
 if a==m.stop+0x20:m.finish();return
 if a==m.stop+0x30:events.append(dict(kind='play',rateBits=struct.pack('<f',f32reg(UC_X86_REG_XMM2)).hex(),flags=w&0xffffffff));m.finish();return
 if a==m.stop+0x38:m.wf(w,3.3333332538604736);m.finish(1);return
 if a in [0x14008c080,0x140877020]:m.finish();return
 if any(lo<=a<hi for lo,hi in [(0x1407e63c0,0x1407e68c0),(0x1407e69a0,0x1407e6a10),(0x1407e8f21,0x1407e903a)]):return
 raise RuntimeError('Unexpected original weather dependency '+hex(a))
u.hook_add(UC_HOOK_CODE,hook)
sequences=[[[1,1,0],[None,None,1],[None,None,17],[None,None,1000],[None,None,2000],[None,None,2982],[1,0,1],[None,None,1000],[None,None,5000]],[[2,1,16],[None,None,1000],[1,1,16],[None,None,1000],[2,0,6000]],[[0,1,0],[None,None,6000]],[[1,1,5999],[None,None,1]],[[1,1,6000],[1,0,0],[None,None,6001]]]
fade_sets=[{}, {'1':6000,'2':6000},{'0':3000,'1':3000,'2':9000},{'0':0,'1':0,'2':0},{'0':-1,'1':-1,'2':-1}]
rows=[]
for fades,steps in itertools.product(fade_sets,sequences):
 u.mem_write(m.heap,bytes(0x100000));allocate=m.heap+0x10000;next_model=m.heap+0x60000;created=removed=0
 m.wq(area,vt);m.wq(vt+0x50,0x1407e63c0);m.wq(0x1412df8f8,rules);m.wq(rules+0x130,arrays);m.wq(arrays+0x268,table)
 for offset,target in [(0,0x10),(0x90,0x20),(0x30,0x30),(0x38,0x38)]:m.wq(gv+offset,m.stop+target)
 for index,(kind,on,delta) in enumerate(steps):
  events=[];u.mem_write(m.stack,bytes(0x20000));rsp=m.stack+0x10000
  if kind is not None:
   m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,area);u.reg_write(UC_X86_REG_RDX,kind);u.emu_start(0x1407e69a0 if on else 0x1407e69e0,m.stop,count=1000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
  u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RBP,m.stack+0x18000);u.reg_write(UC_X86_REG_RDI,area);u.reg_write(UC_X86_REG_R14,0);u.reg_write(UC_X86_REG_RCX,delta);u.reg_write(UC_X86_REG_XMM6,0);m.wi(rsp+0x40,delta)
  u.emu_start(0x1407e8f21,0x1407e903a,count=15000);assert u.reg_read(UC_X86_REG_RIP)==0x1407e903a
  rows.append(dict(reset=index==0,request=None if kind is None else dict(type=kind,enabled=bool(on)),delta=delta,fadeTimes=fades,current=u.mem_read(area+0x2f0,1)[0],target=u.mem_read(area+0x2f1,1)[0],remaining=m.si(area+0x2ec),intensityBits=floatbits(area+0x2f4),instances=sum(m.q(area+0x258+i*8)!=0 for i in range(6)),created=created,removed=removed,events=events))
out=Path(sys.argv[1]);assert not out.exists();out.write_text(json.dumps(dict(target=m.digest,scope=__doc__,rows=rows),indent=2)+'\n');print(json.dumps(dict(rows=len(rows),output=str(out))))
