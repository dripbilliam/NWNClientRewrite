"""Original acosf140c79a38 and positive finite logf140c946b0. SSE and FMA
dispatch inputs are explicit. CRT FP-status/notification helpers are captured.
Unicorn mishandles AVX and lacks FMA instructions: the original VEX instruction
stream is decoded and interpreted with explicit packed/scalar semantics, host
CRT IEEE fmaf for fused instructions and native branch/control flow. SSE/math
instructions outside those VEX boundaries execute unchanged. Both profiles
include positive subnormals after fixing the instruction-emulation discrepancy.
No process CPU detection/FP status claim.
The small extracted lookup constants are algorithm data, not game assets.
"""
import importlib.util,json,struct,random,ctypes,math
from pathlib import Path
spec=importlib.util.spec_from_file_location('fixture',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
import unicorn.x86_const as registers
from capstone import Cs,CS_ARCH_X86,CS_MODE_64
from capstone.x86_const import X86_OP_REG,X86_OP_MEM,X86_OP_IMM
u=m.u;u.hook_del(m.hook_handle)
fmaf=ctypes.CDLL('ucrtbase.dll').fmaf;fmaf.argtypes=[ctypes.c_float]*3;fmaf.restype=ctypes.c_float
decoder=Cs(CS_ARCH_X86,CS_MODE_64);decoder.detail=True
def scalar(raw):return struct.unpack('<f',struct.pack('<I',raw&0xffffffff))[0]
def floatBits(x):return int.from_bytes(struct.pack('<f',x),'little')
def vex(a):
 ins=next(decoder.disasm(bytes(u.mem_read(a,15)),a,count=1));ops=ins.operands;name=ins.mnemonic
 def reg(r):return getattr(registers,'UC_X86_REG_'+ins.reg_name(r).upper())
 def get(o):
  if o.type==X86_OP_REG:return u.reg_read(reg(o.reg))
  if o.type==X86_OP_IMM:return o.imm
  if o.type==X86_OP_MEM:
   base=a+ins.size if o.mem.base and ins.reg_name(o.mem.base)=='rip' else u.reg_read(reg(o.mem.base)) if o.mem.base else 0
   address=base+(u.reg_read(reg(o.mem.index))*o.mem.scale if o.mem.index else 0)+o.mem.disp
   return int.from_bytes(u.mem_read(address,o.size),'little')
  raise AssertionError('Unknown VEX operand')
 vals=[get(o)for o in ops];mask=(1<<128)-1
 if name in ['vmovaps','vmovd']:result=vals[1]
 elif name in ['vpand','vandps']:result=vals[1]&vals[2]
 elif name=='vpor':result=vals[1]|vals[2]
 elif name=='vpxor':result=vals[1]^vals[2]
 elif name in ['vpsrld','vpslld','vpsubd','vpaddd','vcvtdq2ps']:
  lanes=[(vals[1]>>(i*32))&0xffffffff for i in range(4)];out=[]
  for i,lane in enumerate(lanes):
   other=(vals[2]>>(i*32))&0xffffffff if len(vals)>2 and ops[2].type!=X86_OP_IMM else vals[2] if len(vals)>2 else 0
   if name=='vpsrld':x=lane>>other if other<32 else 0
   elif name=='vpslld':x=lane<<other if other<32 else 0
   elif name=='vpsubd':x=lane-other
   elif name=='vpaddd':x=lane+other
   else:x=floatBits(lane if lane<0x80000000 else lane-0x100000000)
   out.append(x&0xffffffff)
  result=sum(x<<(i*32)for i,x in enumerate(out))
 elif name=='vcomiss':
  x,y=map(scalar,vals);flags=u.reg_read(UC_X86_REG_EFLAGS)&~(0x800|0x80|0x40|0x10|0x4|1)
  flags|=0x45 if math.isnan(x)or math.isnan(y)else 1 if x<y else 0x40 if x==y else 0
  u.reg_write(UC_X86_REG_EFLAGS,flags);u.reg_write(UC_X86_REG_RIP,a+ins.size);return
 elif name in ['vaddss','vsubss','vmulss','vdivss','vfmadd213ss','vfmadd231ss','vfmsub213ss']:
  d,x,y=map(scalar,vals)
  if name=='vaddss':z=x+y
  elif name=='vsubss':z=x-y
  elif name=='vmulss':z=x*y
  elif name=='vdivss':z=x/y
  elif name=='vfmadd213ss':z=fmaf(d,x,y)
  elif name=='vfmadd231ss':z=fmaf(x,y,d)
  else:z=fmaf(d,x,-y)
  result=(vals[1]&~0xffffffff)|floatBits(z)
 else:raise AssertionError(f'Unsupported VEX instruction {ins.mnemonic} {ins.op_str}')
 assert ops[0].type==X86_OP_REG
 u.reg_write(reg(ops[0].reg),result&mask);u.reg_write(UC_X86_REG_RIP,a+ins.size)
ranges=[]
for name in ['special-random-angle','special-distance-round']:
 r=json.loads((m.root/f'backups/animations/rea-client-projectile-{name}.json').read_text())['structuredContent']['normalized_result']['procedure']['body'];ranges.extend((int(e['start'],16),int(e['end'],16)+1)for e in r['ranges'])
def hook(u,a,n,_):
 if a==m.stop:u.emu_stop();return
 if activeDispatch and 0x140c948b0<=a<=0x140c94aa5 and bytes(u.mem_read(a,1))[0] in [0xc4,0xc5]:vex(a)
 elif a in [0x140cae8e0]:m.finish(u.reg_read(UC_X86_REG_RAX))
 elif not any(lo<=a<hi for lo,hi in ranges):raise AssertionError(f'Uncaptured projectile math dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(kind,b,dispatch):
 global activeDispatch,activeBits
 activeDispatch=dispatch;activeBits=b;m.wi(0x1415d8224,dispatch);u.reg_write(UC_X86_REG_MXCSR,0x1f80);rsp=m.stack+0x1fe08;u.mem_write(rsp-0x400,bytes(0x500));m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_XMM0,b)
 try:u.emu_start(0x140c79a38 if kind=='acos' else 0x140c946b0,m.stop,count=5000)
 except Exception:print(json.dumps(dict(kind=kind,bits=b,dispatch=dispatch,rip=hex(u.reg_read(UC_X86_REG_RIP)))));raise
 assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(kind=kind,bits=b,dispatch=dispatch,result=u.reg_read(UC_X86_REG_XMM0)&0xffffffff)
bits=lambda f:struct.unpack('<I',struct.pack('<f',f))[0]
rng=random.Random(20261017)
rows=[run('acos',bits(v),0)for v in [-1,-.999999,-.5,-.499999,-.1,-0.0,0,.1,.499999,.5,.999999,1]+[rng.uniform(-1,1)for _ in range(2000)]]
for dispatch in [0,1]:
 samples=[1,0x7fffff,0x800000,0x3f800000,0x7f7fffff]+[bits(v)for v in [.1,.5,.9375,.96875,1,1.03125,1.0625,2,10,100]]+[rng.randint(1,0x7f7fffff)for _ in range(2000)]
 rows += [run('log',b,dispatch)for b in samples]
tables={name:list(struct.unpack('<129I',u.mem_read(address,129*4)))for name,address in [('inverse',0x140edb150),('high',0x140edad30),('low',0x140edaf40)]}
out=m.root/'backups/animations/native-projectile-math-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,tables=tables,rows=rows))+'\n');print(json.dumps(dict(rows=len(rows),output=str(out))))
