"""Original UUID parser2f0590, formatter numeric-selection2f0900 and equality
504960. C++ string/stream operations are captured generic C-locale hex numeric,
character, setw and string-buffer boundaries. The formatter's final inline
buffer extraction is replaced at0bd5..0c45. Not native CRT/stream/locale parity;
proves native field parsing/selection, widths and exact round-trip admission.
"""
import importlib.util,json,random,re
from pathlib import Path
spec=importlib.util.spec_from_file_location('fixture',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
inputPtr,uuidPtr,outputPtr,vtablePtr,manipPtr=[m.heap+n*0x1000 for n in range(1,6)]

def alloc(size):
 global cursor
 ptr=m.heap+cursor;cursor+=(size+31)&~15;return ptr

def stdstring(ptr,text):
 raw=text.encode('cp1252');capacity=15 if len(raw)<16 else len(raw)|15
 if capacity==15:u.mem_write(ptr,raw+b'\0')
 else:target=alloc(capacity+1);u.mem_write(target,raw+b'\0');m.wq(ptr,target)
 m.wq(ptr+16,len(raw));m.wq(ptr+24,capacity)

def stdtext(ptr):return bytes(u.mem_read(ptr if m.q(ptr+24)<16 else m.q(ptr),m.q(ptr+16))).decode('cp1252')

def ctext(ptr):return bytes(u.mem_read(ptr,256)).split(b'\0')[0].decode('cp1252')

def streamstate(ptr):
 m.wq(ptr,vtablePtr);m.wi(vtablePtr+4,0);m.wi(ptr+16,(4 if failed else 0)|(1 if position==len(incoming) else 0))

def hook(u,at,n,_):
 global incoming,position,failed,width,outgoing
 if at==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(r)for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
 if at==0x1402ef5e0:
  where=stdtext(x).find(ctext(y),z);m.finish(where);return
 if at==0x14003dc20:stdstring(x,bytes(u.mem_read(y,z)).decode('cp1252'));m.finish(x);return
 if at in [0x1402eb200,0x140128fc0,0x14014cce0,0x1402efa60,0x140130e00]:m.finish(x);return
 if at==0x1401a4ec0:incoming=stdtext(y);position=0;failed=False;m.finish(x);return
 if at==0x1402ea810:
  tail=incoming[position:];match=re.match(r'[\t\n\v\f\r ]*([+-]?)(?:0[xX])?([0-9a-fA-F]+)',tail)
  if not match:failed=True;m.wq(y,0)
  else:
   value=int(match[2],16);failed=failed or value>0xffffffffffffffff;value=(-value if match[1]=='-' else value)&0xffffffffffffffff;m.wq(y,value);position+=match.end()
  streamstate(x);m.finish(x);return
 if at==0x1402ea360:
  while position<len(incoming) and incoming[position] in '\t\n\v\f\r ':position+=1
  if position==len(incoming):failed=True
  else:u.mem_write(y,incoming[position].encode('cp1252'));position+=1
  streamstate(x);m.finish(x);return
 if at==0x140be9d38:m.wq(x,m.stop+0x10);m.wq(x+8,y);m.finish(x);return
 if at==m.stop+0x10:width=y&0xffffffff;m.finish(x);return
 if at==0x14012e070:outgoing+=format(y&0xffffffff,'x').rjust(width,'0');width=0;m.finish(x);return
 if at==0x140116f90:outgoing+=chr(y&255);m.finish(x);return
 if at==0x1402f0bd5:
  stdstring(u.reg_read(UC_X86_REG_R15),outgoing);u.reg_write(UC_X86_REG_RIP,0x1402f0c45);return
 if at==0x140c41f60:
  a=bytes(u.mem_read(x,z));b=bytes(u.mem_read(y,z));m.finish((a>b)-(a<b));return
 if not (0x1402f0590<=at<0x1402f08e4 or 0x1402f0900<=at<0x1402f0c6e or 0x140504960<=at<0x1405049a1):raise AssertionError(f'Uncaptured UUID text dependency {at:x}')
u.hook_add(UC_HOOK_CODE,hook)

def call(address,args):
 rsp=m.stack+0x1fe08;u.mem_write(rsp-0x700,bytes(0x800));m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8],args):u.reg_write(reg,value)
 u.emu_start(address,m.stop,count=100000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return u.reg_read(UC_X86_REG_RAX)&255

def run(value):
 global cursor,incoming,position,failed,width,outgoing
 cursor=0x10000;incoming='';position=0;failed=False;width=0;outgoing='';u.mem_write(m.heap,bytes(0x100000));stdstring(inputPtr,value)
 call(0x1402f0590,[uuidPtr,inputPtr,0]);words=[f'{m.q(uuidPtr+n*8):016x}' for n in range(2)];call(0x1402f0900,[uuidPtr,outputPtr,0]);raw=alloc(len(value)+1);u.mem_write(raw,value.encode('cp1252')+b'\0');invalid=call(0x140504960,[outputPtr,raw,0]);return dict(input=value,words=words,formatted=stdtext(outputPtr),invalid=invalid)

values=['','a','0-0','1-1','abc-def','00000000-0000-0000-0000-000000000000','01234567-89ab-cdef-0123-456789abcdef','ffffffff-ffff-ffff-ffff-ffffffffffff','01234567-89AB-CDEF-0123-456789ABCDEF','1-2-3-4-5','01234567-89ab-cdef-0123-456789abcdef\0tail']
rng=random.Random(20261016)
for _ in range(200):
 parts=[''.join(rng.choice('0123456789abcdef')for _ in range(n))for n in [8,4,4,4,12]];value='-'.join(parts);values.extend([value,value.upper(),' '+value,value+' ',value.replace('-','_',1),value[:8]+'0'+value[8:],value[:9]+'+'+value[9:],value+'\n',value+'\r',value+'\t'])
rows=[run(value)for value in values];out=m.root/'backups/animations/native-uuid-text-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2)+'\n');print(json.dumps(dict(rows=len(rows),output=str(out))))
