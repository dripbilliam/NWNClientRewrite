"""Full beam application and TrueSeeing/UltraVision suppression/restoration owners, with
original base/copy constructors, CopyEffect, ID allocation and accessors.
Heap/string/vector primitives and lower effect insertion/removal are captured;
the latter maintain a sorted synthetic pool and mapped indices. Darkness AoE
lookup/ID getter are captured lower boundaries. This is owner
transition evidence, not recursive child-handler or full visibility parity.
"""
import importlib.util,itertools,json,struct
from pathlib import Path
spec=importlib.util.spec_from_file_location('fixture',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle);actor,stats,source,pool,vtable=[m.heap+n*0x2000 for n in range(1,6)]
ranges=[(0x140427a20,0x140427ba6),(0x140434990,0x140434b1b),(0x140434be0,0x140434d73),(0x1404392b0,0x1404394d8),(0x1404394f0,0x140439718),(0x1404233d0,0x14042356e),(0x140423570,0x140423768),(0x140423ce0,0x140423f86),(0x140423fc0,0x140423fcb),(0x140425210,0x14042521c),(0x140423fd0,0x140423fdb),(0x140425300,0x14042530c),(0x140423fb0,0x140423fba),(0x140425200,0x14042520a),(0x1404246a0,0x1404246c4),(0x140425340,0x140425361)]
def allocate(size):
 global cursor
 ptr=m.heap+cursor;cursor+=(size+15)&~15;assert cursor<0xf0000;return ptr
def string(ptr,text):
 raw=text.encode();target=allocate(len(raw)+1);u.mem_write(target,raw+b'\0');m.wq(ptr,target if raw else 0);m.wi(ptr+8,len(raw));m.wi(ptr+12,len(raw)+1 if raw else 0)
def read_string(ptr):return bytes(u.mem_read(m.q(ptr),m.si(ptr+8))).decode() if m.q(ptr) else ''
def snapshot(ptr):
 flags=int.from_bytes(u.mem_read(ptr+10,2),'little')
 return dict(id=f'{m.q(ptr):016x}',type=int.from_bytes(u.mem_read(ptr+8,2),'little'),subtype=flags&~7,durationType=flags&7,duration=m.rf(ptr+12),expiryDay=m.si(ptr+16)&0xffffffff,expiryTime=m.si(ptr+20)&0xffffffff,creatorId=m.si(ptr+24)&0xffffffff,spellId=m.si(ptr+28),casterLevel=m.si(ptr+40),showIcon=m.si(ptr+36),exposed=bool(m.si(ptr+32)),bypassImmunity=m.si(ptr+0x108),propertyId=f'{m.q(ptr+0xf0):016x}',customTag=read_string(ptr+0xf8),integers=[m.si(m.q(ptr+0x48)+i*4) for i in range(m.si(ptr+0x40))],strings=[read_string(ptr+0x60+i*16) for i in range(6)],floats=[m.rf(ptr+0x50+i*4) for i in range(4)],objectIds=[m.si(ptr+0xc0+i*4)&0xffffffff for i in range(4)],vectors=[[m.rf(ptr+0xd0+j*12+i*4) for i in range(3)] for j in range(2)])
def store(ptr,type,id,first):
 m.wq(ptr,id);u.mem_write(ptr+8,struct.pack('<HH',type,9));m.wf(ptr+12,2.5)
 for off,value in [(16,2),(20,3300),(24,98),(28,14),(32,c['exposed']),(36,c['showIcon']),(40,7),(0x108,1)]:m.wi(ptr+off,value)
 m.wq(ptr+0xf0,0x123456789abcdef0);string(ptr+0xf8,'tag');m.wi(ptr+0x40,8);m.wq(ptr+0x48,allocate(32))
 for i,value in enumerate([first,2,1,500,501,502,503,504]):m.wi(m.q(ptr+0x48)+i*4,value)
 for i,value in enumerate([2.5,7.5,8.5,9.5]):m.wf(ptr+0x50+i*4,value);m.wi(ptr+0xc0+i*4,0x80000001+i)
 for i in range(6):m.wf(ptr+0xd0+i*4,[1,-2,3,4,-5,6][i]);string(ptr+0x60+i*16,f's{i}')
def update_pool():
 live.sort(key=lambda ptr:int.from_bytes(u.mem_read(ptr+8,2),'little'));m.wq(actor+0x150,pool);m.wi(actor+0x158,len(live))
 for i,ptr in enumerate(live):
  m.wq(pool+i*8,ptr)
  if int.from_bytes(u.mem_read(ptr+8,2),'little')==73:
   u.mem_write(stats+0xdb0,struct.pack('<H',i));break
 first72=next((i for i,p in enumerate(live) if int.from_bytes(u.mem_read(p+8,2),'little')==72),None)
 if first72 is not None:u.mem_write(stats+0xdaa,struct.pack('<H',first72))
 # Write the complete pointer list even when the index loop found a match.
 for i,ptr in enumerate(live):m.wq(pool+i*8,ptr)
def hook(u,a,n,_):
 global live
 if a==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(r) for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
 if a==m.stop+0x10:m.finish(actor if c['objectType']==5 else 0);return
 if a==m.stop+0x20:m.finish(36);return
 if a==0x14055b2f0:m.finish(m.heap+0x1a000);return
 if a in [0x140c10324,0x140c10368]:m.finish(allocate(x));return
 if a in [0x140c10360,0x140c10370]:m.finish();return
 if a==0x140c11414:u.mem_write(x,bytes(y*z));m.finish();return
 if a==0x140047300:u.mem_write(x,bytes(12));m.finish(x);return
 if a==0x140c42060:u.mem_write(x,bytes([y&255])*z);m.finish(x);return
 if a==0x14003d8c0:string(x,bytes(u.mem_read(y,z)).decode() if z else '');m.finish(x);return
 if a==0x14048e350:calls.append(['apply',snapshot(y),z&0xffffffff]);live.append(y);update_pool();m.finish(0);return
 if a==0x140498280:calls.append(['remove',f'{y:016x}']);live=[p for p in live if m.q(p)!=y];update_pool();m.finish(1);return
 if not any(lo<=a<hi for lo,hi in ranges):raise AssertionError(f'Uncaptured copy transfer dependency {a:x}: {c}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,cursor,calls,live
 c=case;cursor=0x20000;calls=[];live=[];u.mem_write(m.heap,bytes(0x100000));m.wq(0x141290568,100);m.wq(actor,vtable);m.wq(vtable+0x60,m.stop+0x10);m.wi(actor+8,99);u.mem_write(actor+12,bytes([c['objectType']]));m.wq(actor+0xad0,stats);u.mem_write(actor+0x770,bytes([c.get('flags',0)]));type=32 if c['mode']=='beam' else 71 if c['mode'] in ['ultra','removeUltra'] else 72;store(source,type,91,100)
 restoring=c['mode'].startswith('remove')
 if restoring:
  live.append(source)
  if c.get('otherSame'):
   other=m.heap+0x1c000;store(other,type,90,100);live.append(other)
  m.wq(0x1412df970,m.heap+0x17000);m.wq(m.heap+0x17008,m.heap+0x17000);m.wq(actor+0x518,m.heap+0x19000);m.wi(actor+0x520,int(c['darkness']));m.wi(m.heap+0x19000,123);m.wq(m.heap+0x1a000,m.heap+0x1b000);m.wq(m.heap+0x1b178,m.stop+0x20)
 for i,value in enumerate(c.get('blindness',[])):
  ptr=m.heap+0xc000+i*0x400;store(ptr,89 if restoring else 73,77+i,value);live.append(ptr)
  # Real admitted blindness has a type75 sibling. UltraVision's original
  # iterator relies on a following non73 record rather than a count guard.
  if not restoring:
   sibling=ptr+0x200;store(sibling,75,77+i,50);live.append(sibling)
 update_pool();initial=[snapshot(p) for p in live];before=snapshot(source)
 rsp=m.stack+0x1fe08;u.mem_write(rsp-0x400,bytes(0x500));m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],[m.heap,actor,source,c.get('loading',0)]):u.reg_write(reg,value)
 entry={'beam':0x140427a20,'ultra':0x140434be0,'true':0x140434990,'removeUltra':0x1404394f0,'removeTrue':0x1404392b0}[c['mode']]
 try:u.emu_start(entry,m.stop,count=100000)
 except Exception:print(json.dumps(dict(case=c,rip=hex(u.reg_read(UC_X86_REG_RIP)),calls=calls)));raise
 assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=c,source=before,initial=initial,result=u.reg_read(UC_X86_REG_RAX)&0xffffffff,calls=calls,effects=[snapshot(p) for p in live],flags=u.mem_read(actor+0x770,1)[0],nextId=f'{m.q(0x141290568):016x}')
rows=[]
for objectType,showIcon,exposed,loading in itertools.product([4,5,6,9,10],[0,1],[0,1],[0,1]):rows.append(run(dict(mode='beam',objectType=objectType,showIcon=showIcon,exposed=exposed,loading=loading)))
for mode,objectType,flags,blindness,showIcon,exposed in itertools.product(['ultra','true'],[5,9],[0,8,24], [[],[8],[16],[8,16],[8,8]],[0,1],[0,1]):rows.append(run(dict(mode=mode,objectType=objectType,flags=flags,blindness=blindness,showIcon=showIcon,exposed=exposed)))
for mode,objectType,flags,blindness,otherSame,darkness,showIcon,exposed in itertools.product(['removeUltra','removeTrue'],[5,9],[2,4,6],[[],[8],[16],[8,16],[8,8]],[False,True],[False,True],[0,1],[0,1]):rows.append(run(dict(mode=mode,objectType=objectType,flags=flags,blindness=blindness,otherSame=otherSame,darkness=darkness,showIcon=showIcon,exposed=exposed)))
out=m.root/'backups/animations/native-effect-copy-transfer-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2)+'\n');print(json.dumps(dict(rows=len(rows),output=str(out))))
