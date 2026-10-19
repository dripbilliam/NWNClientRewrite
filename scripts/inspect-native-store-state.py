"""Execute original ExecuteCode entry through one STORE_STATE/STORE_IP opcode.
Stop at the next interpreter-loop boundary; no full VM execution claim.
"""
import importlib,sys,json,struct
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
vm,pc,shared,view,block,code=[m.heap+n*0x2000 for n in range(1,7)]
def hook(u,a,n,_):
 global loops
 if a==0x1402803a0:
  loops+=1
  if loops==2:u.emu_stop();return
 if a==m.stop:raise RuntimeError('Interpreter returned before next opcode boundary')
 if not 0x140280250<=a<=0x1402825a3:raise RuntimeError(f'Uncaptured STORE_STATE dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
cases=[]
for op in [0x1c,0x2c]:
 for start,delta,base,top in [(0,10,4,8),(4,255,-4,7),(32,0,0,0),(0,2,0x7fffffff,-2147483648)]:
  cases.append(dict(op=op,start=start,delta=delta,base=base,top=top))
out=[]
for c in cases:
 loops=0;u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));m.wi(pc,c['start']);m.wi(vm+0x24,0);m.wi(vm+0x868,1000);m.wi(vm+0x80c,12345);m.wi(vm+0x810,6789);m.wi(vm+0x814,2345)
 body=bytearray(512);body[c['start']:c['start']+2]=bytes([c['op'],c['delta']])
 if c['op']==0x2c:body[c['start']+2:c['start']+10]=struct.pack('>ii',c['base'],c['top'])
 u.mem_write(code,bytes(body));m.wq(shared,view);m.wq(shared+8,0);m.wq(view,block);m.wq(block,code);m.wq(block+8,len(body));rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 for reg,v in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],[vm,pc,shared,0]):u.reg_write(reg,v)
 try:u.emu_start(0x140280250,m.stop,count=10000)
 except Exception:print(json.dumps(dict(case=c,rip=hex(u.reg_read(UC_X86_REG_RIP)))));raise
 assert loops==2
 out.append(dict(case=c,output=dict(instructionPtr=m.si(vm+0x80c),baseBytes=m.si(vm+0x814),topBytes=m.si(vm+0x810))))
path=m.root/'backups/animations/native-store-state-observations.json';path.write_text(json.dumps(dict(target=m.digest,cases=out),indent=2)+'\n');print(json.dumps(dict(cases=len(out),output=str(path))))
