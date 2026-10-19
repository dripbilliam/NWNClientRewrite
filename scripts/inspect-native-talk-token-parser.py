"""Complete original CRC initializer/hash, ParseStr, InitFromCharArray and
string concatenation. Heap/memcpy/free, strncmp and named-token virtual callback
are captured lowers. Named callbacks are authored fixtures, not the actual game
resolver. Unterminated tokens use known zero padding here; real beyond-buffer
reads are not claimed reproducible. No UI/network/token-vocabulary completion.
"""
import importlib,sys,json,itertools,random,struct
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
table,valuePtr,customArray,namedArray,vtable,hashInput=[m.heap+n*0x1000 for n in range(1,7)];callback=m.stop+0x80
ranges=[(0x140199e20,0x14019a421),(0x14018d1a0,0x14018d1f3),(0x14018d200,0x14018d2bb),(0x14003d8c0,0x14003d9ab),(0x14016ab00,0x14016abe9)]
def alloc(size):
 global cursor
 assert size<0x10000;ptr=m.heap+cursor;cursor+=(size+31)&~15;assert cursor<0xf0000;u.mem_write(ptr,bytes(size));return ptr
def raw(ptr):return bytes(u.mem_read(m.q(ptr),m.si(ptr+8)&0xffffffff))if m.q(ptr)else b''
def set_string(ptr,value,normalize=True):
 if normalize and value[:1]==b'\0':value=b''
 p=alloc(len(value)+65);u.mem_write(p,value+b'\0');m.wq(ptr,p if value else 0);m.wi(ptr+8,len(value));m.wi(ptr+12,len(value)+1)
def hook(u,a,n,_):
 if a==m.stop:u.emu_stop();return
 x,y,z=[u.reg_read(r)for r in[UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8]]
 if a==0x140c10368:m.finish(alloc(x));return
 if a==0x140c10370:m.finish();return
 if a==0x140c417f0:
  if z:u.mem_write(x,bytes(u.mem_read(y,z)))
  m.finish(x);return
 if a==0x140c4ee30:
  result=0
  for i in range(z):
   first,second=u.mem_read(x+i,1)[0],u.mem_read(y+i,1)[0]
   if first!=second:result=first-second;break
   if first==0:break
  m.finish(result);return
 if a==callback:
  kind=m.si(y+24);calls.append(kind)
  if kind in[1,2]:m.wi(table+0x4c,1 if kind==1 else 0);set_string(z,b'')
  else:set_string(z,bytes.fromhex(c['namedValue']))
  m.finish();return
 if not any(lo<=a<hi for lo,hi in ranges):raise RuntimeError(f'Uncaptured token-parser owner{a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def execute(start,args):
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 for reg,v in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],args):u.reg_write(reg,v&0xffffffffffffffff)
 u.emu_start(start,m.stop,count=1000000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return u.reg_read(UC_X86_REG_RAX)&0xffffffff
cursor=0x10000;execute(0x14018d200,[]);crcTable=[m.si(0x14140c510+i*4)&0xffffffff for i in range(256)];assert crcTable[1]==0x77073096
def native_hash(value,count=None):u.mem_write(hashInput,value+b'\0');return execute(0x14018d1a0,[hashInput,len(value)if count is None else count])
nameHashes={name:native_hash(name.encode())for name in['NAME','HIDE','SHOW']}
def run(case):
 global c,cursor,calls
 c=case;cursor=0x10000;calls=[];u.mem_write(m.heap,bytes(0x10000));u.mem_write(m.stack,bytes(0x20000));m.wq(table,vtable);m.wq(vtable,callback);m.wi(table+0x4c,77);m.wq(table+0x40,customArray);m.wi(table+0x48,len(c['tokens']))
 for i,item in enumerate(c['tokens']):m.wi(customArray+i*24,item['id']);set_string(customArray+i*24+8,bytes.fromhex(item['value']))
 names=[dict(name=name,hash=hash,kind=kind)for kind,(name,hash)in enumerate(nameHashes.items())]if c['named']else[]
 if c.get('collision'):names=[dict(name='OTHER',hash=nameHashes['NAME'],kind=0)]
 names.sort(key=lambda r:r['hash']);m.wq(table+0x30,namedArray);m.wi(table+0x38,len(names))
 for i,item in enumerate(names):ptr=namedArray+i*48;m.wi(ptr,item['hash']);set_string(ptr+8,item['name'].encode());m.wi(ptr+24,item['kind'])
 set_string(valuePtr,bytes.fromhex(c['input']),normalize=False);execute(0x140199e20,[table,valuePtr]);return dict(case=c,value=raw(valuePtr).hex(),suppression=m.si(table+0x4c),calls=calls)
if __name__=='__main__':
 d=dict(input='',tokens=[dict(id=0,value='7a65726f'),dict(id=10,value='74656e'),dict(id=42,value='76616c7565')],named=True,namedValue='6e616d6564')
 texts=['','plain','a\0tail','\0head','<CUSTOM0>','<CUSTOM10>','before <CUSTOM42> after','<CUSTOM11>','<custom42>','<CUSTOM>','<CUSTOM-1>','<CUSTOM00042>','<CUSTOM4294967295>','<CUSTOM4294967296>','<CUSTOM4294967338>','<CUSTOM9999999999999999999999999999999999999999999999999999999999999999>','<>','<<','<<CUSTOM42>','<<<CUSTOM42>','<NAME>','<name>','<NAME><CUSTOM42>','head<HIDE> hidden <CUSTOM42><SHOW> tail','<HIDE>hidden<SHOW>shown','head<UNKNOWN>tail','head<bad','<','<NAME>\0tail']
 rows=[run(d|dict(input=text.encode('cp1252').hex(),named=named,namedValue=replacement))for text,named,replacement in itertools.product(texts,[False,True],['','6e616d6564','610062'])]
 for value in['','007461696c','610062','3c435553544f4d31303e','80e9']:rows.append(run(d|dict(input=b'<CUSTOM42>'.hex(),tokens=[dict(id=42,value=value)])))
 rows.append(run(d|dict(input=b'<NAME>'.hex(),collision=True)))
 rng=random.Random(20261016);parts=['a',' b ','<NAME>','<<','<CUSTOM42>','<UNKNOWN>','<HIDE>','<SHOW>','<>']
 for _ in range(400):rows.append(run(d|dict(input=''.join(rng.choices(parts,k=rng.randrange(1,10))).encode().hex())))
 hashRows=[dict(value=bytes([v]).hex(),count=1,result=native_hash(bytes([v])))for v in range(256)]+[dict(value=b'NAME\0tail'.hex(),count=n,result=native_hash(b'NAME\0tail',n))for n in[0,1,4,8,99]]
 target=m.root/'backups/animations/native-talk-token-parser-observations.json';target.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,crcTable=crcTable,nameHashes=nameHashes,hashRows=hashRows,rows=rows),indent=2)+'\n');print(json.dumps(dict(output=str(target),rows=len(rows),hashes=len(hashRows))))
