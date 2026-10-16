"""Read-only original CNWMessage construction, CreateWriteMessage, scalar
writers, real bit/byte growth and GetWriteMessage. Only allocation/free/copy
are captured lower boundaries. Allocations deliberately start with known A5
fixture bytes; padding and envelope bytes are otherwise native-uninitialized.
No live network, compression/encryption or area-pack completeness claim.
"""
import importlib,sys,json,itertools,struct,random
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
m=importlib.import_module('inspect-native-intratile-coordinator')
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle);message,app,out=[m.heap+i*0x1000 for i in range(3)]
addresses={'unsigned':0x1402db990,'signed':0x1402db870,'bool':0x1402da920,'byte':0x1402da960,'word':0x1402dbcd0,'dword':0x1402db150,'int':0x1402db5a0,'float':0x1402db240}
ranges=[(0x1402d4830,0x1402d48ac),(0x1402d54a0,0x1402d5554),(0x1402d5880,0x1402d5976),(0x1402d5650,0x1402d56aa),(0x1402d56b0,0x1402d5718),
 (0x1402db990,0x1402dbc14),(0x1402db870,0x1402db8e5),(0x1402db8f0,0x1402db987),(0x1402daaa0,0x1402dab46),(0x1402da920,0x1402da955),(0x1402da960,0x1402daa4d),(0x1402db150,0x1402db238),(0x1402db240,0x1402db313),(0x1402db5a0,0x1402db678),(0x1402dbcd0,0x1402dbdbb)]
def hook(u,a,n,_):
 global cursor
 if a==m.stop:u.emu_stop();return
 x,y,z=[u.reg_read(r)for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8]]
 if a==0x140c10368:
  assert 0<x<0xf0000;ptr=m.heap+cursor;cursor+=(x+15)&~15;assert cursor<0xff000;u.mem_write(ptr,bytes([0xa5])*x);m.finish(ptr)
 elif a==0x140c10370:m.finish()
 elif a==0x140c417f0:
  if z:u.mem_write(x,bytes(u.mem_read(y,z)))
  m.finish(x)
 elif not any(lo<=a<hi for lo,hi in ranges):raise RuntimeError(f'Unmapped native message dependency {a:x}')
hook_handle=u.hook_add(UC_HOOK_CODE,hook)
def call(address,values=None,floatArgs=None):
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],values or [message,0,0,0]):u.reg_write(reg,value&0xffffffffffffffff)
 if floatArgs:
  for reg,value in zip([UC_X86_REG_XMM1,UC_X86_REG_XMM2],floatArgs):u.reg_write(reg,int.from_bytes(struct.pack('<f',value),'little'))
 u.emu_start(address,m.stop,count=100000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return u.reg_read(UC_X86_REG_RAX)&0xffffffff
def snapshot():
 result=call(0x1402d5880,[message,out,out+8,0]);ptr=m.q(out);length=m.si(out+8)&0xffffffff
 return dict(result=result,length=length,hex=bytes(u.mem_read(ptr,length)).hex() if ptr else None,byteLength=m.si(message+0x14),bitLength=m.si(message+0x24),bitOffset=u.mem_read(message+0x2c,1)[0],total=m.si(message+0x28),byteCapacity=m.si(message+0x10),bitCapacity=m.si(message+0x20),writing=m.si(message+0x30),flag=m.si(message+0x60),playerId=m.si(message+0x64)&0xffffffff)
def run(case):
 global cursor
 cursor=0x10000;u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));m.wq(0x1412df970,app);m.wi(app+0x28,case['format']);call(0x1402d4830);observations=[]
 call(0x1402d54a0,[message,case.get('size',0),0x80000001,case.get('flag',1)])
 try:
  for op in case['ops']:
   name=op[0]
   if name=='create':call(0x1402d54a0,[message,op[1],0x80000001,case.get('flag',1)]);continue
   if name=='get':observations.append(snapshot());continue
   value=op[1]
   if name=='float':call(addresses[name],[message,0,0,op[3]],[value,op[2]])
   else:call(addresses[name],[message,int(value,0) if isinstance(value,str) else value,op[2] if len(op)>2 else 0,op[3] if len(op)>3 else 1])
  observations.append(snapshot())
 except Exception:print(json.dumps(dict(case=case,rip=hex(u.reg_read(UC_X86_REG_RIP)),cursor=cursor)));raise
 return dict(case=case,observations=observations)
if __name__=='__main__':
 rows=[]
 for format_,kind,bits,value in itertools.product([0,1,2],['unsigned','signed'],[1,2,7,8,9,15,16,17,31,32,33,40,63,64],['0','1','-1','0x123456789abcdef0','-9223372036854775808']):rows.append(run(dict(format=format_,ops=[[kind,value,bits]])))
 for format_,kind,bits,value in itertools.product([0,1],['byte','word','dword','int'],[1,7,8,9,16,24,31,32,40,64],[-2147483648,-2,0,1,2,255,65535,0x80000001]):rows.append(run(dict(format=format_,ops=[[kind,value,bits]])))
 for format_,value in itertools.product([0,1],[-2147483648,-3,-2,-1,0,1,2,3,2147483647]):rows.append(run(dict(format=format_,ops=[['bool',value]])))
 for format_,value,scale,bits in itertools.product([0,1],[0.,-0.,1.25,-1.25,4294967296.,9e18,1e20],[0.,1.,2.,1000.,-2.],[1,7,8,16,32,64]):rows.append(run(dict(format=format_,ops=[['float',value,scale,bits]])))
 for format_,size,kind,count in itertools.product([0,1],[0,120,121,128,65536],['bool','int'],[1,30,130,1030]):rows.append(run(dict(format=format_,size=size,ops=[([kind,n,32] if kind=='int' else [kind,n]) for n in range(count)])))
 rng=random.Random(4271)
 for n in range(36):
  ops=[]
  for i in range(40):
   kind=rng.choice(['bool','int','dword','unsigned','float'])
   if kind=='bool':ops.append([kind,rng.randrange(-4,5)])
   elif kind=='unsigned':ops.append([kind,hex(rng.getrandbits(64)),rng.randrange(0,65)])
   elif kind=='float':ops.append([kind,rng.uniform(-500,500),rng.choice([1,10,1000]),rng.choice([8,16,32])])
   else:ops.append([kind,rng.randrange(-2147483648,2147483648),rng.choice([8,16,24,32])])
   if i in [7,20]:ops.append(['get'])
   if i==21 and n%2==0:ops.append(['create',0])
  rows.append(run(dict(format=n%2,ops=ops)))
 outPath=m.root/'backups/animations/native-message-writer-observations.json';outPath.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2));print(json.dumps(dict(output=str(outPath),rows=len(rows))))
