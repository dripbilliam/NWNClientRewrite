"""Complete original LocationAccess140535600, VectorNormalize14054ab60 and
PrintString1403147c0 wrappers. Typed VM transfers, structure/string ownership,
debug logging and floating-status notification are captured lower boundaries.
Original atan2f, vector normalization and its nonnegative sqrtf paths execute.
Finite FLOAT inputs, SSE dispatch0, nearest rounding/no FTZ; no whole VM/logger
or exceptional atan2 CRT/errno claim. Outputs retain raw FLOAT bits.
"""
import importlib,sys,json,struct,itertools,random
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
commandPtr,vmPtr,locationPtr,textPtr=[m.heap+i*0x1000 for i in range(1,5)]
ranges=[(0x140535600,0x140535711),(0x14054ab60,0x14054ac2e),(0x1403147c0,0x1403148cc),(0x140230920,0x1402309f5),(0x140c8f29c,0x140c8f6ad),(0x140c7d6d8,0x140c7d783)]
def raw(ptr,count=3):return[struct.unpack('<I',u.mem_read(ptr+i*4,4))[0]for i in range(count)]
def string(ptr):
 out=bytearray()
 while ptr:
  b=u.mem_read(ptr,1)[0]
  if not b:break
  out.append(b);ptr+=1
 return out.decode('cp1252')
def hook(u,a,n,_):
 global output,logs,transfers,frees
 if a==m.stop:u.emu_stop();return
 x,y,z=[u.reg_read(r)for r in[UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8]];rsp=u.reg_read(UC_X86_REG_RSP)
 if a==0x140286030:m.wq(z,locationPtr);transfers+=1;m.finish(c.get('pop',1));return
 if a==0x140286250:
  for i,b in enumerate(c['vectorBits']):m.wi(y+i*4,b)
  transfers+=1;m.finish(c.get('pop',1));return
 if a==0x1402861b0:
  value=bytes.fromhex(c['hex']);u.mem_write(textPtr,value+b'\0');m.wq(y,0 if c.get('nullString')else textPtr);m.wi(y+8,len(value));m.wi(y+12,len(value)+1);transfers+=1;m.finish(c.get('pop',1));return
 if a==0x140286110:m.wi(y,c.get('prefix',0));transfers+=1;m.finish(c.get('intPop',1));return
 if a==0x1402865c0:output=dict(kind='vector',bits=raw(y));m.finish(c.get('push',1));return
 if a==0x140286470:output=dict(kind='object',value=y&0xffffffff);m.finish(c.get('push',1));return
 if a==0x1402863b0:output=dict(kind='float',bits=u.reg_read(UC_X86_REG_XMM1)&0xffffffff);m.finish(c.get('push',1));return
 if a in[0x140c10360,0x140c10370]:frees+=1;m.finish();return
 if a==0x140115890:
  logs.append(dict(flags=[x,y],function=string(z),file=string(u.reg_read(UC_X86_REG_R9)),line=m.si(rsp+0x28),format=string(m.q(rsp+0x30)),text=string(m.q(rsp+0x38))));m.finish(c.get('loggerResult',0));return
 if a==0x140cae8e0:m.finish();return # floating-status notification, not math
 if not any(lo<=a<hi for lo,hi in ranges):raise RuntimeError(f'Uncaptured script utility dependency{a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,output,logs,transfers,frees
 c=case;output=None;logs=[];transfers=0;frees=0;u.mem_write(m.heap,bytes(0x10000));u.mem_write(m.stack,bytes(0x20000));m.wq(commandPtr+0x10,vmPtr);m.wq(0x1412df910,vmPtr);m.wi(0x1415d8224,0);u.reg_write(UC_X86_REG_MXCSR,0x1f80)
 for i,b in enumerate(c.get('positionBits',[0,0,0])+c.get('vectorBits',[0,0,0])):m.wi(locationPtr+i*4,b)
 m.wi(locationPtr+24,c.get('areaId',0x80000001));rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,commandPtr);u.reg_write(UC_X86_REG_RDX,c.get('command',225));u.reg_write(UC_X86_REG_R8,c.get('argc',1))
 start={'location':0x140535600,'normalize':0x14054ab60,'print':0x1403147c0}[c['mode']]
 u.emu_start(start,m.stop,count=10000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=c,result=u.reg_read(UC_X86_REG_RAX)&0xffffffff,output=output,logs=logs,transfers=transfers,frees=frees)
def bits(v):return struct.unpack('<I',struct.pack('<f',v))[0]
def finite_bits(rng):return rng.randrange(0x7f800000)|(rng.randrange(2)<<31)
if __name__=='__main__':
 rng=random.Random(20261016);rows=[]
 vectors=[[0,0,0],[-0.,-0.,-0.],[1,0,0],[-1,-0.,0],[0,-1,0],[2,-3,4],[1e-20,0,0],[0,-1e-20,0],[1e-30,-1e-30,1e-30],[1e30,-1e30,0],[.999995,0,0],[1.000005,0,0]]
 vectors=[[bits(v)for v in point]for point in vectors]+[[finite_bits(rng)for _ in range(3)]for _ in range(700)]
 for mode,vector in itertools.product(['location','normalize'],vectors):rows.append(run(dict(mode=mode,vectorBits=vector)))
 for command,area,pop,push in itertools.product([223,224,225,222,226],[0,0x7f000000,0x80000001],[0,1],[0,1]):rows.append(run(dict(mode='location',command=command,areaId=area,positionBits=[bits(-2),bits(5.25),bits(-0.)],vectorBits=[bits(2),bits(-3),bits(4)],pop=pop,push=push)))
 for pop,push in itertools.product([0,1],[0,1]):rows.append(run(dict(mode='normalize',vectorBits=[bits(2),bits(3),bits(4)],pop=pop,push=push)))
 for text,argc,prefix,pop,intPop in itertools.product(['','00','4125004225','80ff','48656c6c6f'],[0,1,2,3],[0,1,2,-1],[0,1],[0,1]):rows.append(run(dict(mode='print',hex=text,argc=argc,prefix=prefix,pop=pop,intPop=intPop)))
 rows.append(run(dict(mode='print',hex='',nullString=True,argc=1)))
 target=m.root/'backups/animations/native-script-utilities-observations.json';target.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2)+'\n');print(json.dumps(dict(output=str(target),rows=len(rows))))
