"""Original appearance equipment-U branch780a90..78111b of reader77fe10.

The original CHAR/DWORD/BYTE readers and U routing execute. Client-ID lookup,
ObjectVisualTransformData construction/reading, effect clear/set, transform
application and map cleanup are captured lower boundaries. The transform
boundary consumes an explicit eight-byte empty-map fixture; this does not
validate the complete transform reader or actual effect rendering.
"""
import sys, importlib, json, itertools
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
t=importlib.import_module('inspect-native-message-text');w=t.w;m=w.m;u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(t.hook_handle)
item,head=m.heap+0x9000,m.heap+0xa000
ranges=[(0x140780a90,0x140780ad5),(0x140780fd5,0x14078111b),(0x1402dacb0,0x1402dad90),(0x1402d98d0,0x1402d9960)]
def hook(u,a,n,data):
 x,y,z=[u.reg_read(r)for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8]]
 if a==0x1409737c0:
  offset=m.si(w.message+0x44);value=m.si(m.q(w.message+0x38)+offset)&0xffffffff
  m.wi(w.message+0x44,offset+4);trace.append(['id',value]);m.finish(value);return
 if a==0x1406abc80:trace.append(['lookup',y&0xffffffff]);m.finish(item if existing else 0);return
 if a==0x140973160:
  assert y==w.message;m.wq(x,head);m.wq(head,head);m.wi(w.message+0x44,m.si(w.message+0x44)+(10 if fmt==0 else 8));trace.append(['transform']);m.finish(x);return
 if a==0x14083f660:trace.append(['clear']);m.finish();return
 if a==0x14083e040:trace.append(['effect',y&255]);m.finish(1);return
 if a==0x140766960:trace.append(['apply',x==item+0x48]);m.finish();return
 if a in [0x140369860,0x140c10360]:m.finish();return
 if any(lo<=a<hi for lo,hi in ranges):return
 t.hook(u,a,n,data)
u.hook_add(UC_HOOK_CODE,hook)
rows=[]
for fmt,effect,slot,existing in itertools.product([0,1],[0,1,7,255],[16,32],[False,True]):
 trace=[];t.reset(dict(format=fmt));w.call(0x1402dacb0,[w.message,ord('U'),8]);w.call(0x1404763e0,[w.message,42]);w.call(0x1402db150,[w.message,slot,32]);w.call(0x1402da960,[w.message,effect,8,1]);w.call(0x1402db5a0,[w.message,0,32]);w.call(0x1402db5a0,[w.message,0,32]);packet=bytes.fromhex(w.snapshot()['hex'])
 u.mem_write(t.inputBase,packet[3:]);m.wi(m.stack+0x1fe08+0x28,1);assert w.call(0x1402da7b0,[w.message,t.inputBase,len(packet)-3,0xffffffff])==1
 u.reg_write(UC_X86_REG_R12,w.message);u.reg_write(UC_X86_REG_RDI,1);u.reg_write(UC_X86_REG_RSP,m.stack+0x1e000);u.reg_write(UC_X86_REG_RBP,m.stack+0x1e500)
 u.emu_start(0x140780a90,0x14078111b,count=10000);assert u.reg_read(UC_X86_REG_RIP)==0x14078111b
 expected=[['id',0x8000002a],['lookup',0x8000002a],['transform']]+([['clear']]+([['effect',effect]]if effect else[])+[['apply',True]]if existing else[])
 assert trace==expected,(trace,expected)
 assert w.call(0x1402d9460)==0 and w.call(0x1402d9520)==0
 rows.append(dict(format=fmt,effect=effect,slot=slot,existing=existing,trace=trace))
out=m.root/'backups/animations/native-equipment-appearance-update-observations.json';out.write_text(json.dumps(dict(target=m.digest,limits=__doc__,cases=rows),indent=2)+'\n');print(json.dumps(dict(cases=len(rows))))
