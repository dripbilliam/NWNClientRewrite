"""Complete original packet23 server writers and packed sound-object records.
Real ID/scalar/ResRef codecs and PackIntoMessage execute. Area lookup and
transport are synthetic boundaries; no playback or live client is emulated.
"""
import sys,importlib,json,itertools,struct
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
t=importlib.import_module('inspect-native-message-text');w=t.w;m=w.m;u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(t.hook_handle)
def dossier(name):
 d=json.loads((m.root/'backups/animations'/name).read_text())
 if d.get('structuredContent',{}).get('raw_result',{}).get('value'):return d['structuredContent']['raw_result']['value']
 e=json.loads(next(c['text']for c in d['content']if c['type']=='text'));return e.get('normalized_result',e.get('raw_result',e))
names={2:'play',3:'stop',4:'volume',5:'position',6:'create',7:'destroy'};addresses={2:0x1404e0780,3:0x1404e0810,4:0x1404e0590,5:0x1404e04b0,6:0x1404e0630,7:0x1404e06f0};ranges=[]
for name in names.values():
 d=dossier('rea-network-audio-sound-create.json'if name=='create'else 'rea-placed-sound-server-'+name+'.json');ranges.extend((int(r['start'],16),int(r['end'],16)+1)for r in d['procedure']['body']['ranges'])
d=dossier('rea-placed-sound-server-pack.json');ranges.extend((int(r['start'],16),int(r['end'],16)+1)for r in d['procedure']['body']['ranges'])
source,player,area,point,refs=[m.heap+n*0x1000 for n in range(0x81,0x86)]
def hook(u,a,n,data):
 x,y,z,k=[u.reg_read(q)for q in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];sp=u.reg_read(UC_X86_REG_RSP)
 if a==0x140494e80:m.finish(area);return
 if a==0x1404dc490:
  size=m.si(sp+0x30)&0xffffffff;packets.append((bytes([80,z&255,k&255])+bytes(u.mem_read(m.q(sp+0x28),size))[3:]).hex());m.finish(1);return
 if any(lo<=a<hi for lo,hi in ranges):return
 t.hook(u,a,n,data)
u.hook_add(UC_HOOK_CODE,hook)
rows=[]
for op,fmt,oid,value in itertools.product(names,[0,1],[0x13,0x7fffffff,0x7f000000,0x80000021],[-2147483648,-1,0,1,127,255,256,2147483647]):
 packets=[];t.reset(dict(format=fmt));m.wi(player+0x48,7);m.wi(area+0x140,0x47);m.wi(source+8,oid);position=[3.25,-8.5,1.8];u.mem_write(point,struct.pack('<3f',*position));u.mem_write(source+0xa4,struct.pack('<3f',*position));fields={}
 for offset in [0x308,0x30c,0x310,0x314,0x318,0x31c,0x324,0x328,0x348,0x34c,0x358,0x35c,0x32c]:m.wi(source+offset,value);fields[hex(offset)]=value
 for offset in [0x320,0x350,0x354,0x330,0x334]:m.wf(source+offset,1.25);fields[hex(offset)]=1.25
 resources=['case_Sound','abcdefghijklmnopq','a\0b',''];m.wq(source+0x338,refs);m.wi(source+0x340,len(resources))
 for i,ref in enumerate(resources):u.mem_write(refs+i*17,ref.encode('cp1252')[:16].ljust(17,b'\0'))
 args=[w.message,player,source]if op==6 else [w.message,player,oid,point if op==5 else value]
 result=w.call(addresses[op],args);rows.append(dict(operation=op,format=fmt,objectId=oid,value=value,fields=fields,position=position,refs=resources,packets=packets,result=result))
out=m.root/'backups/animations/native-network-sound-objects-observations.json';out.write_text(json.dumps(dict(target=m.digest,limits=__doc__,cases=rows),indent=2)+'\n');print(json.dumps(dict(cases=len(rows),output=str(out))))
