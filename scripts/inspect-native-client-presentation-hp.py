"""Read-only original client base/level-up stats constructors and HP getter.
Relevant instructions execute unchanged from the pinned executable. Allocation,
empty string/list constructors, TLK lookup, ruleset lookups and unrelated
attack/spell cache refresh are captured services. Class-4/race-6 metadata is
explicit fixture input, not a claim about undisclosed server creature HP.
"""
import importlib.util,itertools,json,struct
from pathlib import Path
spec=importlib.util.spec_from_file_location('fixture',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
actor,rules,races,classes=[m.heap+n for n in [0x1000,0x10000,0x11000,0x20000]]
ranges=[(0x1407ea230,0x1407ea6ff),(0x1407ea7a0,0x1407eab8d),(0x1407ec3a0,0x1407ec50b),
 (0x1407f1110,0x1407f1226),(0x1407f5d70,0x1407f5e11),(0x1407f5e20,0x1407f5e28),
 (0x1407f0f60,0x1407f0fc6),(0x140299710,0x14029978e),(0x1407f97b0,0x1407f9813),(0x1407f99f0,0x1407f9a53)]

def cstring(ptr):return bytes(u.mem_read(ptr,100)).split(b'\0')[0].decode('ascii')
def short(ptr):return struct.unpack('<h',u.mem_read(ptr,2))[0]
def hook(u,a,n,_):
 global cursor
 if a==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(r) for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
 if a in [0x140c10324,0x140c10368]:ptr=m.heap+cursor;cursor+=(x+15)&~15;u.mem_write(ptr,bytes([0xa5])*x);m.finish(ptr)
 elif a==0x140c10370:m.finish()
 elif a==0x140c42060:u.mem_write(x,bytes([y&255])*z);m.finish(x)
 elif a==0x1401994d0:u.mem_write(y,bytes(16));m.finish(y)
 elif a==0x14018ded0:u.mem_write(x,bytes(17));m.finish(x)
 elif a==0x14084c170:u.mem_write(x,bytes(0x28));m.finish(x)
 elif a==0x140c11414:u.mem_write(x,bytes(y*z));m.finish()
 elif a==0x1402a22b0:u.mem_write(x,bytes(0x70));m.finish(x)
 elif a in [0x1407f7b80,0x1407faf60]:m.finish() # No HP writes; unrelated cached attacks/spells.
 elif a==0x1402ae870:
  key=cstring(x)
  # Optimized call has already hashed the leading C into its seed.
  if key.startswith('HARGEN_'):key='C'+key
  keys.append(key);m.finish(len(keys))
 elif a==0x1402a4130:
  key=keys[y-1];queries.append(key);m.finish(c.get(key,z&0xffffffff))
 elif not any(lo<=a<hi for lo,hi in ranges):raise AssertionError(f'Uncaptured client HP dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)

def call(address,args=[]):
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],args):u.reg_write(reg,value)
 u.emu_start(address,m.stop,count=100000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return u.reg_read(UC_X86_REG_RAX)&0xffffffff
def snapshot():return dict(base=short(actor+0x84),temporary=short(actor+0x86),current=short(actor+0x88),maximum=call(0x1407f5e20,[actor])&65535)
def run(case):
 global c,cursor,keys,queries
 c=case;cursor=0x70000;keys=[];queries=[]
 u.mem_write(m.heap,bytes([0xa5])*0x100000);u.mem_write(m.stack,bytes(0x20000))
 u.mem_write(rules,bytes(0x200));u.mem_write(races,bytes(0x1000));u.mem_write(classes,bytes(0x5000))
 m.wq(0x1412df8f8,rules);m.wq(rules+0x118,races);m.wq(rules+0x110,classes);u.mem_write(rules+0x105,bytes([20]))
 u.mem_write(races+6*0x68+0x1d,bytes([c['raceCon']&255]));u.mem_write(classes+4*0x530+0x2f8,bytes([c['classCon']&255]))
 call(0x1407ea7a0,[actor]);constructed=snapshot()
 # The ordinary class/type setters do not replace constructor HP.
 call(0x1407f97b0,[actor,0,3]);call(0x1407f99f0,[actor,0,15]);partial=snapshot()
 # A later disclosed HP packet replaces all four stored shorts. This reproduces
 # the verified direct field writes, not the full message reader/transport.
 u.mem_write(actor+0x84,struct.pack('<hhhh',47,2,31,99));disclosed=snapshot()
 return dict(case=c,constructed=constructed,afterClassUpdate=partial,afterDisclosedFields=disclosed,rulesQueries=list(dict.fromkeys(queries)))
if __name__=='__main__':
 cases=[dict(CHARGEN_BASE_ABILITY_MIN=base,CHARGEN_ABILITY_NEUTRAL_VALUE=neutral,CHARGEN_ABILITY_MODIFIER_INCREMENT=increment,raceCon=race,classCon=gain) for base,neutral,increment,race,gain in itertools.product([8,10,24,255],[10,11],[2,3],[-2,0,2,100],[-1,0,2])]
 rows=[run(c) for c in cases]
 output=m.root/'backups/animations/native-client-presentation-hp-observations-v1.json'
 assert not output.exists(), 'Preserve prior evidence'
 output.write_text(json.dumps(dict(target=m.digest,scope=__doc__,rows=rows),indent=2));print(json.dumps(dict(output=str(output),rows=len(rows),sample=rows[12])))
