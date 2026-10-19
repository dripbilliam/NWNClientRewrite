"""Complete original G/S client handler7b2740 with original scalar packets.

Lookup/cast, UI notifications, combat constructors/list insertion and final
stats setters are captured boundaries. The original handler performs every
wire read, build-gated branch and scalar memory write. Fixed synthetic objects
and original-byte execution only; no live process or installed asset writes.
"""
import sys,importlib,json,itertools,struct
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
t=importlib.import_module('inspect-native-message-text');w=t.w;r=t.r;m=w.m;u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(t.hook_handle);ranges=[]
for name in ['network-client-inventory-status','network-write-char','network-read-char','network-write-short','network-read-short']:
 d=json.loads((m.root/'backups/animations'/('rea-'+name+'.json')).read_text())['structuredContent']['raw_result']['value']['procedure'];ranges.extend((int(b['start'],16),int(b['end'],16)+1)for b in d['body']['ranges'])
ranges.append((0x1409737c0,0x1409737f0))
obj,vt,stats,rules,root,gui,skills=[m.heap+n*0x1000 for n in [10,11,12,13,14,15,16]]

def hook(u,a,n,data):
 x,y,z,k=[u.reg_read(reg)for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
 if a in [0x1406abb70,0x1406ac020]:m.finish(root);return
 if a==0x140296470:m.wq(z,obj);m.finish(0);return
 if a==0x1406abbc0:m.finish(root);return
 if a==m.stop+0x10:m.finish(obj);return
 if a==0x1407c4ab0:
  gates.append([y,z,k]);m.finish(int(c['revision']>z or c['revision']==z and c['postfix']>=k));return
 if a in [0x1402a22b0,0x1402a2370]:u.mem_write(x,bytes(0x70 if a==0x1402a22b0 else 6));m.finish(x);return
 if a==0x1402a3760:nodes.append(list(u.mem_read(y,6)));m.finish();return
 if a==0x1407f9b40:combat.append(list(u.mem_read(y,0x20)));m.finish();return
 if a in [0x14088af90,0x14088a730]:events.append(['remove'if a==0x14088af90 else'add',y&0xffff]);m.finish();return
 if a in [0x14088b740,0x14088b180,0x1407ed6d0]:m.finish();return
 if a==0x1403ef530:events.append(['list118'if x==stats+0x118 else'list128',y&0xffff]);m.finish();return
 if a==0x1407fa350:events.append(['class',y&255,z&255]);m.finish();return
 if any(lo<=a<hi for lo,hi in ranges):return
 t.hook(u,a,n,data)
u.hook_add(UC_HOOK_CODE,hook)
def byte(v,bits=8):w.call(0x1402da960,[w.message,v,bits,1])
def char(v):w.call(0x1402dacb0,[w.message,v&255,8])
def word(v):w.call(0x1402dbcd0,[w.message,v,16])
def short(v):w.call(0x1402db790,[w.message,v&65535,16])
def dword(v,bits=32):w.call(0x1402db150,[w.message,v,bits])
def boolean(v):w.call(0x1402da920,[w.message,v])
rows=[]
for format,build,mask,optional in itertools.product([0,1],[(34,0),(36,2),(37,1),(37,17)],[0,1,0x3e,0x40,0x80,0x100,0x200,0x1c00,0xe000,0xffff],[0,1]):
 revision,postfix=build;c=dict(format=format,revision=revision,postfix=postfix,mask=mask,optional=optional,skillCount=28);events=[];combat=[];nodes=[];gates=[];t.reset(dict(format=format))
 char(ord('G'));char(ord('S'));w.call(0x1404763e0,[w.message,0x7fffffff]);dword(mask)
 if mask&1:
  for i in range(6):byte(10+i)
  for i in range(13):char(i-6)
 for bit,value in [(2,-3),(4,4),(8,-5),(0x2000,6),(0x4000,-7),(0x8000,8)]:
  if mask&bit:char(value)
 if mask&16:dword(0xfedcba98)
 if mask&32:byte(19);boolean(optional)
 if mask&64:
  byte(5,3);char(-4);char(6);char(-8);byte(91,7)
  for v in [17,23,29]:byte(v,5)
  for i in range(3):byte(i+11,5);byte(i+18,5);char(i-3)
  byte(13,4);byte(6,3);boolean(optional)
  if optional:char(-11);char(12);byte(9,4);byte(3,3)
  for second in [False,True]:
   byte(2)
   for i in range(2):
    char(i-7)
    if second:byte(i+9,5 if revision>=35 else 4)
    byte(i+4,3)
    for bits,value in [(8,211),(2,3),(3,7)]:
     boolean(optional)
     if optional:byte(value,bits)
 if mask&0x400:short(-19)
 if mask&0x800:short(-21);short(300)
 if mask&128:
  dword((1<<0)|(1<<27),28)
  for value in [-5,12]:char(value);boolean(optional)
 if mask&256:
  (word if revision>37 or revision==37 and postfix>=2 else byte)(2)
  feat=word if revision>37 or revision==37 and postfix>=2 else byte
  feat(17);feat(101);feat(2)
  for v in [25,103]:feat(v);boolean(optional)
 if mask&512:
  word(2);word(17);word(945);word(1);word(65535)
 if mask&0x1000:byte(3);byte(4);byte(8);byte(12)
 byte(0x5a);p=bytearray.fromhex(w.snapshot()['hex']);p[:3]=bytes([80,5,1]);packet=bytes(p)
 u.mem_write(t.inputBase,packet[3:]);m.wi(m.stack+0x1fe08+0x28,1);assert w.call(0x1402da7b0,[w.message,t.inputBase,len(packet)-3,0xffffffff])==1
 assert w.call(0x1402d98d0,[w.message,8])==ord('G');assert w.call(0x1402d98d0,[w.message,8])==ord('S')
 for ptr in [obj,vt,stats,rules,root,gui,skills]:u.mem_write(ptr,bytes(0x1000))
 m.wq(obj,vt);m.wq(vt+0x58,m.stop+0x10);m.wq(obj+0x3b0,stats);m.wq(root+0x78,gui);m.wq(stats+0xd0,skills);m.wi(stats+0xe0,2);m.wq(0x1412df8f8,rules);u.mem_write(rules+0x107,b'\x1c')
 result=w.call(0x1407b2740,[w.message]);assert result==1,(c,result);state=r.state();tail=w.call(0x1402d9630,[w.message,8,1]);assert tail==0x5a,(c,tail,state,gates);assert w.call(0x1402d9460,[w.message])==0;assert w.call(0x1402d9520,[w.message])==0
 cells={hex(i):struct.unpack('b',u.mem_read(stats+i,1))[0]for i in range(0x70,0x83)}
 cells.update({hex(i):struct.unpack('b',u.mem_read(stats+i,1))[0]for i in range(0x98,0x9f)})
 for i in [0x88,0x8a,0x8c]:cells[hex(i)]=struct.unpack('<h',u.mem_read(stats+i,2))[0]
 for i in [0x94,0xa0,0xe0]:cells[hex(i)]=m.si(stats+i)&0xffffffff
 rows.append(dict(case=c,packet=packet.hex(),cells=cells,skills=list(u.mem_read(skills,28)),combat=combat,nodes=nodes,events=events,reader=state))
output=m.root/'backups/animations/native-network-inventory-stats-observations.json';output.write_text(json.dumps(dict(target=m.digest,limits=__doc__,cases=rows),indent=2)+'\n');print(json.dumps(dict(cases=len(rows),output=str(output))))
