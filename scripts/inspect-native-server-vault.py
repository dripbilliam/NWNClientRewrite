"""Execute original scalar/localized/ResRef writers in the server's observed
17/2 and17/4 field order and original login/CharList readers. Filesystem,
character loading and network send are captured boundaries; synthetic data only.
No claim to executing the full directory/GFF-producing list sender.
"""
import sys,importlib,json
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
t=importlib.import_module('inspect-native-message-text');w=t.w;r=t.r;m=w.m;u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(t.hook_handle)
ranges=[]
ranges.append((0x14018de80,0x14018dea0))
for label in ['server-vault-charlist-receive','server-vault-login-handler']:
 d=json.loads((m.root/'backups/animations'/('rea-'+label+'.json')).read_text())['structuredContent']['normalized_result'];ranges.extend((int(x['start'],16),int(x['end'],16)+1)for x in d['procedure']['body']['ranges'])
calls=[]
def hook(u,a,n,data):
 if a==0x1404e12d0:
  ref=u.reg_read(UC_X86_REG_R9);calls.append(dict(kind='preview',previewType=u.reg_read(UC_X86_REG_R8)&255,resref=bytes(u.mem_read(ref,16)).split(b'\0')[0].decode('cp1252')));m.finish(1);return
 if a==0x14055b6e0:m.finish(m.heap+0x90000);return
 if a==0x14055bb90:
  ref=u.reg_read(UC_X86_REG_R9);calls.append(dict(kind='play',source=u.reg_read(UC_X86_REG_RDX)&255,resref=bytes(u.mem_read(ref,16)).split(b'\0')[0].decode('cp1252')));m.finish(1);return
 if any(lo<=a<hi for lo,hi in ranges):return
 t.hook(u,a,n,data)
u.hook_add(UC_HOOK_CODE,hook)
def reset():
 t.reset(dict(format=1,flag=1,size=128));t.readSource=[];m.wq(0x1412df970,w.app);m.wq(w.app+8,m.heap+0x88000)
def scalar(name,value):w.call(w.addresses[name],[w.message,value,{'bool':0,'byte':8,'word':16,'int':32,'dword':32}[name],1])
def ref(value):
 raw=value.encode('cp1252');assert len(raw)<=16;u.mem_write(t.inputBase,raw+b'\0'*(16-len(raw)));w.call(0x1402dad90,[w.message,t.inputBase,16])
def string(value):
 raw=value.encode('cp1252');u.mem_write(t.inputBase,raw or b'\0');m.wq(t.owned,t.inputBase);m.wi(t.owned+8,len(raw));m.wi(t.owned+12,len(raw)+1);w.call(0x1402dab50,[w.message,t.owned,32])
def localized(value):
 scalar('bool',int(isinstance(value,int)))
 if isinstance(value,int):w.call(w.addresses['byte'],[w.message,0,1,1]);scalar('dword',value)
 else:string(value)
def packet(major,minor):
 raw=bytearray.fromhex(w.snapshot()['hex']);raw[:3]=bytes([80,major,minor]);return bytes(raw).hex()
rows=[]
fixtures=[[],[dict(firstName='Fixture <Hero>',lastName='One',resref='fixtureone',source=17,portrait=65535,portraitRef='custom_portrait',classes=[dict(id=10,level=1)])],
 [dict(firstName=16777216,lastName='',resref='preset',source=2,portrait=1,portraitRef='',classes=[]),dict(firstName='Saved',lastName='Module',resref='0',source=14,portrait=0,portraitRef='',classes=[dict(id=254,level=255),dict(id=100,level=2)])]]
for chars in fixtures:
 reset();scalar('word',len(chars))
 for c in chars:
  localized(c['firstName']);localized(c['lastName']);ref(c['resref']);scalar('byte',c['source']);scalar('word',c['portrait']);ref(c['portraitRef']);scalar('byte',len(c['classes']))
  for cls in c['classes']:scalar('int',cls['id']);scalar('byte',cls['level'])
 rows.append(dict(characters=chars,packet=packet(17,2)))
requests=[]
for source,previewType in [(2,1),(14,4),(17,5)]:
 for name in ['fixture','sixteen_bytes_16']:
  for kind in ['preview','play']:
   reset()
   if kind=='preview':scalar('byte',previewType)
   ref(name);wire=bytearray.fromhex(w.snapshot()['hex']);wire[:3]=bytes([112,17,3]if kind=='preview'else[112,2,source]);body=bytes(wire[3:]);u.mem_write(r.packet,body);m.wi(m.stack+0x1fe30,1);w.call(0x1402da7b0,[w.message,r.packet,len(body),0xffffffff]);calls=[]
   result=w.call(0x140444a00 if kind=='preview'else 0x140457850,[w.message,m.heap+0x80000,3 if kind=='preview'else source]);assert result==1 and len(calls)==1
   requests.append(dict(source=source,resref=name,kind=kind,packet=bytes(wire).hex(),calls=list(calls)))
out=m.root/'backups/animations/native-server-vault-observations.json';out.write_text(json.dumps(dict(target=m.digest,limits=__doc__,lists=rows,requests=requests),indent=2)+'\n');print(json.dumps(dict(output=str(out),lists=len(rows),requests=len(requests))))
