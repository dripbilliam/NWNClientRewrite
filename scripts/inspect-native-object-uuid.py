"""Original CNWSUUID eligibility, ctor/dtor, lookup, LoadFromGff and TryAssign.
GetObjectByUUID898 also executes its complete VM command branch.
Map/string/GFF/parse/format are captured lower boundaries; the real equality
helper executes. Supplied round-trip results test admission ordering, not general
UUID parser/stream/entropy parity. No original process or assets are modified.
"""
import importlib.util,itertools,json
from pathlib import Path
spec=importlib.util.spec_from_file_location('fixture',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
objectPtr,statePtr,inputPtr,gffPtr,rootPtr,sentinelPtr,nodePtr,iteratorPtr=[m.heap+n*0x1000 for n in range(1,9)]
ranges=[(0x140505390,0x140505401),(0x140505410,0x140505479),(0x140504d30,0x140504d6e),(0x140504df0,0x140504ee0),(0x140505ab0,0x140505ba7),(0x140505710,0x140505aa4),(0x140505cc0,0x14050602c),(0x140504960,0x1405049a1),(0x14054a330,0x14054a589)]

def allocate(size):
 global cursor
 ptr=m.heap+cursor;cursor+=(size+31)&~15;return ptr

def ctext(ptr):
 raw=bytearray()
 if ptr:
  while len(raw)<4096:
   byte=u.mem_read(ptr+len(raw),1)[0]
   if byte==0:break
   raw.append(byte)
 return raw.decode('cp1252')

def owning(ptr,value):
 raw=value.encode('cp1252');target=allocate(len(raw)+1);u.mem_write(target,raw+b'\0');m.wq(ptr,target if raw else 0);m.wi(ptr+8,len(raw));m.wi(ptr+12,len(raw)+1 if raw else 0)

def stored(ptr):return bytes(u.mem_read(m.q(ptr),m.si(ptr+8)&0xffffffff)).decode('cp1252') if m.q(ptr) else ''

def stdstring(ptr,value):
 raw=value.encode('cp1252');capacity=15 if len(raw)<16 else len(raw)|15
 if capacity==15:u.mem_write(ptr,raw+b'\0')
 else:target=allocate(capacity+1);u.mem_write(target,raw+b'\0');m.wq(ptr,target)
 m.wq(ptr+0x10,len(raw));m.wq(ptr+0x18,capacity)

def stdtext(ptr):return bytes(u.mem_read(ptr if m.q(ptr+0x18)<16 else m.q(ptr),m.q(ptr+0x10))).decode('cp1252')

def hook(u,at,n,_):
 global pushed
 if at==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(r)for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
 if at==0x1402861b0:
  calls.append(['popString']);owning(y,c.get('input',''));m.finish(c.get('pop',1));return
 if at==0x140286470:pushed=y&0xffffffff;calls.append(['pushObject',pushed]);m.finish(c.get('push',1));return
 if at==0x14003dc20:stdstring(x,bytes(u.mem_read(y,z)).decode('cp1252'));m.finish(x);return
 if at==0x14003d8c0:owning(x,bytes(u.mem_read(y,z&0xffffffff)).decode('cp1252'));calls.append(['assign',stored(x)]);m.finish(x);return
 if at==0x1401a1130:
  assert ctext(w)=='UUID';calls.append(['read']);owning(y,c.get('input',''));m.wi(m.q(rsp+0x28),c.get('readStatus',1));m.finish(y);return
 if at==0x140506970:
  key=stdtext(z);calls.append(['find',key]);m.wq(y,nodePtr if c.get('found') else sentinelPtr);m.wq(nodePtr+0x30,objectPtr);m.finish(y);return
 if at==0x140504ee0:calls.append(['put',stdtext(y),m.si(objectPtr+8)&0xffffffff]);m.finish(nodePtr+0x30);return
 if at==0x1405067f0:calls.append(['erase',stdtext(y)]);m.finish(1);return
 if at==0x1402f0590:calls.append(['parse',stdtext(y)]);m.finish(x);return
 if at==0x1402f0900:stdstring(y,c.get('roundTrip','00000000-0000-0000-0000-000000000000'));calls.append(['format',stdtext(y)]);m.finish(y);return
 if at==0x140c41f60:
  a=bytes(u.mem_read(x,z));b=bytes(u.mem_read(y,z));m.finish((a>b)-(a<b));return
 if at==0x140115890:
  calls.append(['warning',ctext(m.q(rsp+0x30)).replace('%s',ctext(m.q(rsp+0x38)))]);m.finish();return
 if at in [0x140c10360,0x140c10370]:m.finish();return
 if at==0x140c10410:m.finish(u.reg_read(UC_X86_REG_RAX));return
 if not any(lo<=at<hi for lo,hi in ranges):raise AssertionError(f'Uncaptured UUID dependency {at:x}: {c}')
u.hook_add(UC_HOOK_CODE,hook)

def run(case):
 global c,cursor,calls,pushed
 c=case;cursor=0x10000;calls=[];pushed=None;u.mem_write(m.heap,bytes(0x100000));m.wi(objectPtr+8,c.get('id',99));u.mem_write(objectPtr+12,bytes([c.get('type',12)&255]));m.wq(statePtr+8,objectPtr);owning(statePtr+0x10,c.get('old',''));owning(inputPtr,c.get('input',''));m.wq(0x14141f2c8,sentinelPtr)
 mode=c['mode'];address={'static':0x140505410,'member':0x140505390,'ctor':0x140504d30,'destroy':0x140504df0,'lookup':0x140505ab0,'load':0x140505710,'assign':0x140505cc0,'command':0x14054a330}[mode]
 args=[statePtr,inputPtr,0,0]
 if mode=='static':args=[c['type']&0xffffffff,0,0,0]
 if mode=='ctor':args=[statePtr,objectPtr,0,0]
 if mode=='lookup':args=[inputPtr,0,0,0]
 if mode=='load':args=[statePtr,gffPtr,rootPtr,0]
 if mode=='command':args=[statePtr,0x382,1,0]
 rsp=m.stack+0x1fe08;u.mem_write(rsp-0x600,bytes(0x700));m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],args):u.reg_write(reg,value)
 try:u.emu_start(address,m.stop,count=100000)
 except Exception:print(json.dumps(dict(case=c,calls=calls,rip=hex(u.reg_read(UC_X86_REG_RIP)))));raise
 assert u.reg_read(UC_X86_REG_RIP)==m.stop
 result=u.reg_read(UC_X86_REG_RAX)&(0xffffffff if mode in ['lookup','command'] else 255)
 return dict(case=c,result=result,calls=calls,value=stored(statePtr+0x10),parent=m.q(statePtr+8)==objectPtr,pushed=pushed)

rows=[]
for mode,t in itertools.product(['static','member'],list(range(256))+[-1,256,260,261,268,0x7fffffff]):rows.append(run(dict(mode=mode,type=t)))
for value,found,old in itertools.product(['','0','abc','a\0tail','\0tail','01234567-89ab-cdef-0123-456789abcdef'],[False,True],['','old value']):
 rows.append(run(dict(mode='lookup',input=value,found=found)))
 rows.append(run(dict(mode='destroy',old=value)))
for mode,t,value,found,status,match,old in itertools.product(['load','assign'],[3,4,5,8,11,12,13,14],['','a','a\0tail','\0tail','01234567-89ab-cdef-0123-456789abcdef'],[False,True],[0,1,2],[False,True],['','previous_uuid']):
 rows.append(run(dict(mode=mode,type=t,input=value,found=found,readStatus=status,roundTrip=value.split('\0')[0] if match else '00000000-0000-0000-0000-000000000000',old=old)))
rows.append(run(dict(mode='ctor',old='uninitialized data')))
for value,found,pop,push in itertools.product(['','a','a\0tail','\0tail','01234567-89ab-cdef-0123-456789abcdef'],[False,True],[0,1],[0,1]):rows.append(run(dict(mode='command',input=value,found=found,pop=pop,push=push)))
out=m.root/'backups/animations/native-object-uuid-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2)+'\n');print(json.dumps(dict(rows=len(rows),output=str(out))))
