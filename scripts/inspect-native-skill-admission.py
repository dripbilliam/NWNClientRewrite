"""Run unchanged original skill getter and InventoryStats skill merge code.

The getter executes its complete pinned body. InventoryStats executes its full
body with decoded-message reads, object lookup and inactive UI/tracing services
captured at explicit call boundaries. This validates client-cache decisions;
it is not a live server, packet decoder or proof of stats+110's producer.
"""
from pathlib import Path
import argparse, hashlib, itertools, json, struct, sys

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'backups/research-python'))
import pefile
from unicorn import Uc,UC_ARCH_X86,UC_MODE_64,UC_HOOK_CODE
from unicorn.x86_const import *

p=argparse.ArgumentParser();p.add_argument('--report',required=True);args=p.parse_args()
out=Path(args.report).resolve()
if out.exists():raise SystemExit('Refusing to overwrite observations')
image=(ROOT.parent/'FullDecomp/NwnRootInstall/bin/win32/nwmain.exe').read_bytes()
digest=hashlib.sha256(image).hexdigest()
assert digest=='3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a'
pe=pefile.PE(data=image);u=Uc(UC_ARCH_X86,UC_MODE_64);base=pe.OPTIONAL_HEADER.ImageBase
u.mem_map(base,(pe.OPTIONAL_HEADER.SizeOfImage+4095)&~4095);u.mem_write(base,pe.get_memory_mapped_image())
heap,stack,stop=0x200000000,0x300000000,0x400000000
u.mem_map(heap,0x100000);u.mem_map(stack,0x10000);u.mem_map(stop,0x1000)
stats,rules,actor,obj,vt,gui,msg= [heap+n for n in [0x1000,0x2000,0x3000,0x4000,0x5000,0x6000,0x7000]]
def wq(a,v):u.mem_write(a,struct.pack('<Q',v&0xffffffffffffffff))
def wi(a,v):u.mem_write(a,struct.pack('<I',v&0xffffffff))
def q(a):return int.from_bytes(u.mem_read(a,8),'little')
def ret(v=0):
 sp=u.reg_read(UC_X86_REG_RSP);u.reg_write(UC_X86_REG_RAX,v&0xffffffffffffffff);u.reg_write(UC_X86_REG_RIP,q(sp));u.reg_write(UC_X86_REG_RSP,sp+8)
trace=[];reads=[];dwords=[];ranks=[];flags=[];mode='getter'
def hook(_u,a,_size,_data):
 if a==stop:u.emu_stop();return
 trace.append(hex(a))
 if len(trace)>40:trace.pop(0)
 if mode=='getter':
  if not 0x1407f0bf0<=a<=0x1407f0c25:raise RuntimeError('Uncaptured getter boundary '+hex(a))
  return
 x,y,z=[u.reg_read(r) for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8]]
 if a==0x1409737c0:ret(99)
 elif a==0x1406abb70:ret(heap+0x8000)
 elif a==0x140296470:wq(z,obj);ret(0)
 elif a==0x1406abbc0:ret(gui)
 elif a==0x1406ac020:ret(0)
 elif a==stop+0x100:ret(actor)
 elif a==0x1402d9bc0:reads.append(['DWORD',y]);ret(dwords.pop(0))
 elif a==0x1402d98d0:reads.append(['CHAR',y]);ret(ranks.pop(0))
 elif a==0x1402d9600:reads.append(['BOOL']);ret(flags.pop(0))
 elif a==0x1402d9460:ret(0)
 elif a==0x140c10410:ret(u.reg_read(UC_X86_REG_RAX)) # native cookie check preserves the return register
 elif not (0x1407b2740<=a<=0x1407b2fae or 0x1407b2fb0<=a<=0x1407b35ac):raise RuntimeError('Uncaptured inventory boundary '+hex(a))
u.hook_add(UC_HOOK_CODE,hook)
def reset(count,mask,override=0):
 u.mem_write(heap,bytes(0x100000));u.mem_write(stack,bytes(0x10000));trace.clear();reads.clear()
 wq(0x1412df8f8,rules);u.mem_write(rules+0x107,bytes([count]));wi(stats+0xe0,mask);wi(stats+0x110,override)
 wq(actor+0x3b0,stats);wq(stats+0xd0,heap+0x9000);wq(obj,vt);wq(vt+0x58,stop+0x100)
 wq(0x1412df970,heap+0xa000);u.mem_write(0x14141e310,bytes(8))
 for r in [UC_X86_REG_RAX,UC_X86_REG_RBX,UC_X86_REG_RBP,UC_X86_REG_RSI,UC_X86_REG_RDI,UC_X86_REG_R8,UC_X86_REG_R9,UC_X86_REG_R10,UC_X86_REG_R11,UC_X86_REG_R12,UC_X86_REG_R13,UC_X86_REG_R14,UC_X86_REG_R15]:u.reg_write(r,0)
 sp=stack+0xfe08;wq(sp,stop);u.reg_write(UC_X86_REG_RSP,sp)
def run(entry):
 try:u.emu_start(entry,stop,count=100000)
 except Exception as e:raise RuntimeError(str(e)+'; trace='+str(trace)) from e
 assert u.reg_read(UC_X86_REG_RIP)==stop,'Original body did not return'
 return u.reg_read(UC_X86_REG_RAX)&0xffffffff
getters=[]
for count,skill,mask,override in itertools.product([0,1,13,14,31,32,33,255],[0,1,13,14,31,32,33,254,255,256,65535],[0,1,8193,0xffffffff,0x80000000],[0,1,-1]):
 mode='getter';reset(count,mask,override);u.reg_write(UC_X86_REG_RCX,stats);u.reg_write(UC_X86_REG_RDX,skill)
 value=run(0x1407f0bf0);expected=0 if skill>=count else 1 if override else mask&(1<<(skill&31))
 assert value==expected,(count,skill,mask,override,value,expected)
 getters.append(dict(count=count,skill=skill,mask=mask,override=override,result=value))
inventory=[]
for count,presence,initial,pattern in itertools.product([0,1,14,32,33,255],[0,1,8193,0xffffffff,0x80000000],[0,8193,0xffffffff],['false','true','alternate']):
 selected=[i for i in range(count) if presence&(1<<(i&31))]
 incoming=[dict(index=i,value=(i%256)-128,flag=int(pattern=='true' or pattern=='alternate' and i%2==1)) for i in selected]
 mode='inventory';reset(count,initial);dwords[:]=[128,presence];ranks[:]=[r['value'] for r in incoming];flags[:]=[r['flag'] for r in incoming];u.reg_write(UC_X86_REG_RCX,msg)
 returned=run(0x1407b2740);value=int.from_bytes(u.mem_read(stats+0xe0,4),'little');expected=initial
 for row in incoming:
  if row['flag']:expected|=1<<(row['index']&31)
 assert returned==1 and value==expected and not dwords and not ranks and not flags,(count,presence,initial,pattern,returned,value,expected,trace)
 expected_reads=[['DWORD',32],['DWORD',count]]+sum(([['CHAR',8],['BOOL']] for _ in incoming),[])
 assert reads==expected_reads,(reads,expected_reads)
 assert all(bytes(u.mem_read(heap+0x9000+r['index'],1))[0]==(r['value']&255) for r in incoming)
 inventory.append(dict(count=count,presence=presence,initial=initial,pattern=pattern,incoming=incoming,result=value,reads=list(reads)))
report=dict(success=True,binarySha256=digest,scriptSha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),getterCases=len(getters),inventoryCases=len(inventory),getter=getters,inventory=inventory,scope=__doc__,limitations=['Message reads are explicit decoded fixtures; original bit decoder and overflow paths are not exercised.','Inventory inactive sheet/party/tracing service boundaries do not prove UI refresh.','The getter override field stats+110 producer and disclosure remain unknown; fixtures set its int32 input explicitly.'])
out.parent.mkdir(parents=True,exist_ok=True);out.write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(dict(success=True,getterCases=len(getters),inventoryCases=len(inventory),report=str(out))))
