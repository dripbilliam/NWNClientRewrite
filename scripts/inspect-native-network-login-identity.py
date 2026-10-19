"""Original CBWCMD5 Encrypt/rounds, CDUtil public-key extraction and community
response coordinator. Synthetic credentials only. Community lower MD5/string
storage are captured; the independent original MD5 cases verify that primitive.
"""
import importlib,sys,json,struct,hashlib
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
obj,source,out,length,secondary,third=[m.heap+n*0x1000 for n in range(1,7)]
ranges=[]
for name in ['network-md5-ctor','network-md5-encrypt','network-md5-block','network-key-unscramble','network-community-response']:
 d=json.loads((m.root/'backups/animations'/('rea-'+name+'.json')).read_text())['structuredContent']['normalized_result'];ranges.extend((int(r['start'],16),int(r['end'],16)+1)for r in d['procedure']['body']['ranges'])
def alloc(n):
 global cursor
 p=m.heap+cursor;cursor+=(n+31)&~15;assert cursor<0xf0000;return p
def exo(p,b):
 ptr=alloc(len(b)+1);u.mem_write(ptr,b+b'\0');m.wq(p,ptr);m.wi(p+8,len(b));m.wi(p+12,len(b)+1)
def text(p):return bytes(u.mem_read(m.q(p),m.si(p+8)))if m.q(p)else b''
def hook(u,a,n,_):
 if a==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(r)for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
 if a in [0x140c10324,0x140c10368]:m.finish(alloc(x));return
 if a==0x140c10370:m.finish();return
 if a==0x140c417f0:u.mem_write(x,bytes(u.mem_read(y,z)));m.finish(x);return
 if a==0x1401664c0:exo(y,hashlib.md5(text(z)).hexdigest().encode());m.finish(y);return
 if a==0x14016ab00:exo(y,text(x)+text(z));m.finish(y);return
 if a==0x140c10410:m.finish(u.reg_read(UC_X86_REG_RAX));return
 if not any(lo<=a<hi for lo,hi in ranges):raise RuntimeError(f'Uncaptured native identity dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def call(address,args,extra=[]):
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 for r,v in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],args):u.reg_write(r,v)
 for i,v in enumerate(extra):m.wq(rsp+0x28+i*8,v)
 u.emu_start(address,m.stop,count=200000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
def reset():
 global cursor
 cursor=0x10000;u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000))
rows=[]
for n in [0,1,2,15,16,31,32,41,55,56,57,63,64,65,119,120,127,128,129,255,1024]:
 reset();b=bytes((i*37+19)&255 for i in range(n));u.mem_write(source,b or b'\0');call(0x140112f00,[obj]);call(0x140112f90,[obj,source,n,out],[length,0]);observed=bytes(u.mem_read(out,16)).hex();assert observed==hashlib.md5(b).hexdigest();rows.append(dict(input=b.hex(),digest=observed))
public=[]
for s in ['ABCDE-FGHIJ-KLMNO-PQRST-UVWXY-ZABCD-EFGHI','abcde-fghij-klmno-pqrst-uvwxy-zabcd-efghi','A'*41,'-'*41,'short','X\0'+'Y'*39]:
 reset();u.mem_write(source,s.encode()+b'\0');call(0x14010fab0,[source,out,secondary,third]);b=bytes(u.mem_read(out,9)).split(b'\0')[0];public.append(dict(key=s,public=b.decode()))
community=[]
for password,challenge in [('', ''),('', 'salt'),('secret-fixture','community-salt'),('A\0B','C\0D'),('caf\xe9','nonce')]:
 reset();exo(source,password.encode('cp1252'));exo(secondary,challenge.encode('cp1252'));call(0x140109b80,[obj,out,source,secondary]);community.append(dict(password=password,challenge=challenge,response=text(out).decode()))
path=m.root/'backups/animations/native-network-login-identity-observations.json';path.write_text(json.dumps(dict(target=m.digest,limits=__doc__,md5=rows,publicKeys=public,community=community),indent=2)+'\n');print(json.dumps(dict(md5=len(rows),publicKeys=len(public),community=len(community),output=str(path))))
