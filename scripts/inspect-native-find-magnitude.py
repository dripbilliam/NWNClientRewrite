"""Complete original FindSubString and VectorMagnitude wrappers and original
Find/strstr/magnitude/sqrt lowers. VM transfers/string ownership and FP status
notification are captured. Ordinary zero-length VM strings are null-backed;
explicit allocated-empty strings are separately retained as representation cases
and not interchangeable with the replacement VM's ordinary empty strings.
SSE dispatch0, round-nearest, noFTZ; not whole-VM or CRT errno/status parity.
"""
import importlib,sys,json,itertools,random,struct
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
cmd,vm,text,needle=[m.heap+n*0x1000 for n in range(1,5)]
ranges=[(0x1403136a0,0x14031378f),(0x14016aea0,0x14016af06),(0x140c422bc,0x140c424bc),(0x14054ab00,0x14054ab60),(0x1402303d0,0x14023040d),(0x140c7d6d8,0x140c7d783)]
def hook(u,a,n,_):
 global output,transfers
 if a==m.stop:u.emu_stop();return
 x,y=[u.reg_read(r)for r in[UC_X86_REG_RCX,UC_X86_REG_RDX]]
 if a==0x1402861b0:
  index=transfers;transfers+=1;value=bytes.fromhex(c['text'if index==0 else'needle']);ptr=text if index==0 else needle;u.mem_write(ptr,value+b'\0');m.wq(y,ptr if value or c.get('allocatedEmpty')else 0);m.wi(y+8,len(value));m.wi(y+12,len(value)+1);m.finish(c['pop1'if index==0 else'pop2']);return
 if a==0x140286110:transfers+=1;m.wi(y,c['start']);m.finish(c['intPop']);return
 if a==0x140286250:
  for i,b in enumerate(c['bits']):m.wi(y+i*4,b)
  transfers+=1;m.finish(c['pop1']);return
 if a==0x140286410:output=y&0xffffffff;m.finish(c['push']);return
 if a==0x1402863b0:output=u.reg_read(UC_X86_REG_XMM1)&0xffffffff;m.finish(c['push']);return
 if a==0x140c10370:m.finish();return
 if a==0x140cae8e0:m.finish();return
 if not any(lo<=a<hi for lo,hi in ranges):raise RuntimeError(f'Uncaptured find/magnitude owner{a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,output,transfers
 c=case;output=None;transfers=0;m.wq(cmd+0x10,vm);m.wq(0x1412df910,vm);m.wi(0x1415d8224,0);u.reg_write(UC_X86_REG_MXCSR,0x1f80)
 rsp=m.stack+0x1fe08;u.mem_write(rsp-0x180,bytes(0x200));m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,cmd);u.reg_write(UC_X86_REG_R8,c.get('argc',3));u.emu_start(0x1403136a0 if c['mode']=='find'else 0x14054ab00,m.stop,count=10000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=c,result=u.reg_read(UC_X86_REG_RAX)&0xffffffff,output=output,transfers=transfers)
def bits(v):return struct.unpack('<I',struct.pack('<f',v))[0]
if __name__=='__main__':
 default=dict(mode='find',text='',needle='',start=0,argc=3,pop1=1,pop2=1,intPop=1,push=1);rows=[]
 for a,b,start,argc in itertools.product([b'',b'abcabc',b'ab\0cd',bytes([0x80,0xe9,0x80]),b'aaaaa'],[b'',b'a',b'bc',b'cd',b'\0x',bytes([0x80]),b'aaa'],[-1,0,1,2,3,5,6,7,0x7fffffff],[2,3]):rows.append(run(default|dict(text=a.hex(),needle=b.hex(),start=start,argc=argc)))
 for op1,op2,ip,push,argc in itertools.product([0,1],repeat=5):rows.append(run(default|dict(text='616263',needle='62',pop1=op1,pop2=op2,intPop=ip,push=push,argc=2+argc)))
 for a,b in itertools.product([b'',b'abc'],[b'',b'b']):rows.append(run(default|dict(text=a.hex(),needle=b.hex(),allocatedEmpty=True)))
 rng=random.Random(20261016);vectors=[[bits(x)for x in v]for v in[[0,0,0],[-0.,-0.,-0.],[3,4,0],[1e-30,1e-30,0],[1e30,-1e30,0],[float('inf'),0,0],[float('nan'),0,0]]]+[[rng.getrandbits(32)for _ in range(3)]for _ in range(800)]
 rows += [run(default|dict(mode='magnitude',bits=v))for v in vectors]
 rows += [run(default|dict(mode='magnitude',bits=[bits(3),bits(4),0],pop1=pop,push=push))for pop,push in itertools.product([0,1],repeat=2)]
 out=m.root/'backups/animations/native-find-magnitude-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2)+'\n');print(json.dumps(dict(output=str(out),rows=len(rows))))
