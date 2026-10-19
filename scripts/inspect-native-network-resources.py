"""Original status/resource coordinator, advertisement and scalar serialization.

Allocation, settings/module lookup, advertisement-vector ownership, final send,
CRT strspn and hex conversion are captured. Original field/branch/byte/bit,
SHA1 validity, language-selection and build decisions execute unchanged.
Synthetic modules/manifests only; no credentials or game assets.
"""
import importlib,sys,json,itertools
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
t=importlib.import_module('inspect-native-message-text');r=t.r;w=t.w;m=w.m;u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
from capstone import Cs,CS_ARCH_X86,CS_MODE_64,CS_OP_MEM
from capstone.x86_const import X86_REG_RIP
u.hook_del(t.hook_handle)
module,settings,server,vtable=[m.heap+n*0x1000 for n in [5,6,8,9]]
ranges=[]
for name in ['network-server-status-response','network-module-resource-pack','network-advertisement-write','network-resource-resref-assign','network-sha1-constructor-a','network-advertisement-should-load','network-peer-build-compare-v2']:
 d=json.loads((m.root/'backups/animations'/('rea-'+name+'.json')).read_text())['structuredContent']['normalized_result']
 ranges.extend((int(x['start'],16),int(x['end'],16)+1)for x in d['procedure']['body']['ranges'])
def alloc(size):
 p=m.heap+w.cursor;w.cursor+=(size+31)&~15;assert w.cursor<0xb0000;u.mem_write(p,bytes(size));return p
def exo(p,value):
 b=value.encode('cp1252');data=alloc(len(b)+1);u.mem_write(data,b+b'\0');m.wq(p,data);m.wi(p+8,len(b));m.wi(p+12,len(b)+1)
def hook(u,a,n,data):
 x,y,z=[u.reg_read(reg)for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8]]
 if a==m.stop+0x100:m.finish(settings);return
 if a==0x14055b810:m.finish(w.message);return
 if a==0x14055b980:m.finish(c['serverMode']);return
 if a==0x14055b6e0:m.finish(module);return
 if a==0x1401b0640:u.mem_write(x,bytes(u.mem_read(y,24)));m.finish(x);return
 if a==0x140c10360:m.finish();return  # captured sized allocation cleanup
 if a==0x140672ce0:
  count=u.reg_read(UC_X86_REG_R9);u.mem_write(x,bytes(u.mem_read(z,count)).hex().encode()+b'\0');m.finish(x);return
 if a==0x1406731c0:
  count=u.reg_read(UC_X86_REG_R9);raw=bytes(u.mem_read(z,count)).decode();decoded=bytes.fromhex(raw);u.mem_write(x,decoded);m.finish(len(decoded));return
 if a==0x140c8b6a0:
  allowed=set(cstring(y));span=0
  for value in cstring(x):
   if value not in allowed:break
   span+=1
  m.finish(span);return
 if a==0x1401994c0:m.finish(native_language);return
 if a==0x1404dc490:
  rsp=u.reg_read(UC_X86_REG_RSP);size=m.si(rsp+0x30);p=m.q(rsp+0x28)
  raw=bytearray(u.mem_read(p,size))if size else bytearray(3);raw[:3]=bytes([80,z&255,u.reg_read(UC_X86_REG_R9)&255]);packets.append(bytes(raw).hex());m.finish(1);return
 if a==0x140115890:m.finish();return  # empty manifest hash warning, not field decoding
 if any(lo<=a<hi for lo,hi in ranges):return
 t.hook(u,a,n,data)
u.hook_add(UC_HOOK_CODE,hook)
rows=[]
base=dict(serverMode=2,customTlk='',nwmResourceName='Fixture',forceLegacy=0,haks=[],advertisement=None)
cases=[base,base|dict(serverMode=0),base|dict(serverMode=1),base|dict(customTlk='custom_dialog',nwmResourceName='',haks=['hak_one','HAK_TWO']),
 base|dict(customTlk='caf\xe9',nwmResourceName='Campaign\0tail')]
advert=dict(hash='1234567890abcdef1234567890abcdef12345678',url='https://owned.invalid/nwsync',manifests=[dict(hash='abcdef1234567890abcdef1234567890abcdef12',flags=3,language=255),dict(hash='',flags=129,language=2)])
for legacy in [0,1]:
 for haks in [[],['supplement']]:cases.append(base|dict(advertisement=advert,forceLegacy=legacy,haks=haks))
for c in cases:
 w.cursor=0x10000;t.sizes={};t.readSource=[];r.diagnostics=[];u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));m.wq(0x1412df970,w.app);m.wi(w.app+0x28,1);m.wq(w.app+8,server);m.wq(server,vtable);m.wq(vtable+0x68,m.stop+0x100)
 w.call(0x1402d4830);exo(module+0x88,c['customTlk']);exo(module+0x450,c['nwmResourceName']);m.wi(settings+0x230,c['forceLegacy'])
 haks=alloc(len(c['haks'])*16+16);m.wq(module+0x148,haks);m.wi(module+0x150,len(c['haks']))
 for i,name in enumerate(c['haks']):exo(haks+i*16,name)
 ad=settings+0x1c8;u.mem_write(ad,bytes([0 if c['advertisement']else 1]));exo(ad+0x58,'')
 if c['advertisement']:
  a=c['advertisement'];u.mem_write(ad+0x15,a['hash'].encode()+b'\0');exo(ad+0x58,a['url']);manifests=alloc(len(a['manifests'])*64);m.wq(ad+0x40,manifests);m.wq(ad+0x48,manifests+len(a['manifests'])*64);m.wq(ad+0x50,manifests+len(a['manifests'])*64)
  for i,entry in enumerate(a['manifests']):
   p=manifests+i*64;u.mem_write(p,bytes([int(not entry['hash'])]));u.mem_write(p+0x15,entry['hash'].encode()+b'\0');u.mem_write(p+0x3e,bytes([entry['flags'],entry['language']]))
 packets=[];result=w.call(0x1404df850,[w.message,123]);assert result==1 and len(packets)==1
 rows.append(dict(case=c,packet=packets[0]))
def cstring(pointer):
 result=bytearray()
 for i in range(4096):
  value=u.mem_read(pointer+i,1)[0]
  if not value:return bytes(result)
  result.append(value)
 raise RuntimeError('Unterminated captured CRT fixture')
def first_rip_reference(address):
 decoder=Cs(CS_ARCH_X86,CS_MODE_64);decoder.detail=True
 for ins in decoder.disasm(m.pe.get_data(address-m.base,64),address):
  for op in ins.operands:
   if op.type==CS_OP_MEM and op.mem.base==X86_REG_RIP:return ins.address+ins.size+op.mem.disp
 raise RuntimeError('Native global reference is unavailable')
hashes=[]
for value in ['', '0'*40, '1'*39, '1'*40, '1'*41, 'ABCDEF'*6+'1234', '1'*40+'Ztail', '1'*40+'\0tail', '0'*40+'Z', '1'*40+'f', 'g'+'1'*40]:
 exo(module,value);w.call(0x140187d00,[module+0x100,module]);empty=bool(u.mem_read(module+0x100,1)[0]);hashes.append(dict(value=value,hash=None if empty else bytes(u.mem_read(module+0x115,40)).decode()))
languages=[];tlk_global=first_rip_reference(0x1401b3c10)
for present,native_language,language in itertools.product([False,True],[0,2,258],[0,2,255]):
 m.wq(tlk_global,server if present else 0);m.wq(server+0x18,settings);u.mem_write(module+0x3f,bytes([language]));result=w.call(0x1401b3c10,[module]);languages.append(dict(present=present,nativeLanguage=native_language,language=language,result=result&255))
builds=[];old_global=first_rip_reference(0x14024ff10)
for mode,old,number,revision,postfix in itertools.product([0,1],[0,1],[8192,8193,9000],[0,33,34,35],[-1,0,17]):
 m.wi(w.app+0x28,mode);m.wi(old_global,old)
 for offset,value in [(0xdc,number),(0xe0,revision),(0xe4,postfix)]:m.wi(module+offset,value)
 result=w.call(0x14024ff10,[module,8193,34,0]);builds.append(dict(formatMode=mode,pretendOldBuild=old,number=number,revision=revision,postfix=postfix,result=result&255))
output=m.root/'backups/animations/native-network-resource-observations.json';output.write_text(json.dumps(dict(target=m.digest,limits=__doc__,cases=rows,hashCases=hashes,languageCases=languages,buildCases=builds),indent=2)+'\n');print(json.dumps(dict(cases=len(rows),hashCases=len(hashes),languageCases=len(languages),buildCases=len(builds),output=str(output))))
