"""Read-only original portal sender, client parser and download request.
Real CNWMessage codecs execute unchanged in synthetic memory. Transport and
the portal-controller/character-download application boundaries are captured.
No live process changes, server joins or proprietary assets are retained.
"""
import sys,importlib,json,itertools
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
t=importlib.import_module('inspect-native-message-text');w=t.w;r=t.r;m=w.m;u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(t.hook_handle);ranges=[]
for name in ['portal-native-sender-v1','portal-message-body-v1','portal-success-sender-v1','portal-success-receiver-v1','portal-character-failure-v1']:
 d=json.loads((m.root/f'backups/animations/rea-{name}.json').read_text())['structuredContent']['normalized_result']['procedure']
 ranges.extend((int(b['start'],16),int(b['end'],16)+1)for b in d['body']['ranges'])

def string(p):
 n=m.si(p+8)&0xffffffff;q=m.q(p);return bytes(u.mem_read(q,n)).decode('cp1252')if q else ''
def hook(u,a,n,data):
 x,y,z,k=[u.reg_read(reg)for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];sp=u.reg_read(UC_X86_REG_RSP)
 if a==0x1404dc490:
  size=m.si(sp+0x30)&0xffffffff;p=m.q(sp+0x28);packets.append((bytes([80,z&255,k&255])+bytes(u.mem_read(p,size))[3:]).hex());m.finish(1);return
 if a==0x1407c25c0:
  size=m.si(sp+0x28)&0xffffffff;packets.append((bytes([112,y&255,z&255])+bytes(u.mem_read(k,size))[3:]).hex());m.finish(1);return
 if a==0x1406ac1e0:m.finish(m.heap+0x70000);return
 if a==0x1408422d0:
  applied.append(dict(host=string(y),password=string(z),waypoint=string(k),seamless=m.si(sp+0x28)));m.finish();return
 if a==0x1404bd740:m.finish(1);return
 if a==0x1406ac7c0:
  downloads.append(dict(dataHex=bytes(u.mem_read(z,y)).hex(),accountVault=k));m.finish();return
 if any(lo<=a<hi for lo,hi in ranges):return
 t.hook(u,a,n,data)
u.hook_add(UC_HOOK_CODE,hook)
rows=[]
for host,password,waypoint,seamless in itertools.product(['127.0.0.1:5122','localhost'],['','fixture-only'],['','Arrival'],[0,1]):
 packets=[];applied=[];t.reset(dict(format=1));sp=m.stack+0x1fe08
 for i,value in enumerate([host,password,waypoint]):
  p=m.heap+0x80000+i*0x100;buf=p+0x40;raw=value.encode('cp1252');u.mem_write(buf,raw or b'\0');m.wq(p,buf);m.wi(p+8,len(raw));m.wi(p+12,len(raw)+1)
 m.wq(sp+0x28,m.heap+0x80200);m.wi(sp+0x30,seamless)
 w.call(0x1404cd0d0,[w.message,0x80000001,m.heap+0x80000,m.heap+0x80100]);assert len(packets)==1
 packet=packets[0];body=bytes.fromhex(packet)[3:];u.mem_write(r.packet,body);m.wi(sp+0x28,1);assert w.call(0x1402da7b0,[w.message,r.packet,len(body),0xffffffff])==1
 assert w.call(0x1407aa6a0,[w.message])==1;assert applied==[dict(host=host,password=password,waypoint=waypoint,seamless=seamless)]
 rows.append(dict(packet=packet,fields=applied[0]))
packets=[];w.call(0x1407ba520,[w.message]);assert packets==['702b01'];downloadRequest=packets[0]
characters=[]
for account,resref in itertools.product([False,True],['yrs','fifteencharname1']):
 packets=[];downloads=[];t.reset(dict(format=1));player=m.heap+0x90000;m.wi(player+0x48,0x80000001);u.mem_write(player+0xb4,bytes([4 if account else 3]));raw=resref.encode('ascii');u.mem_write(player+0xb5,raw+b'\0')
 assert w.call(0x1404d21d0,[w.message,player])==1;assert len(packets)==1;packet=packets[0]
 body=bytes.fromhex(packet)[3:];u.mem_write(r.packet,body);m.wi(m.stack+0x1fe30,1);assert w.call(0x1402da7b0,[w.message,r.packet,len(body),0xffffffff])==1
 assert w.call(0x14077b270,[w.message,3])==1;assert downloads==[dict(dataHex=raw.hex(),accountVault=int(account))],dict(resref=resref,account=account,downloads=downloads)
 characters.append(dict(packet=packet,resref=resref,accountVault=account,downloads=downloads))
out=m.root/'backups/animations/native-network-portal-v1.json';out.write_text(json.dumps(dict(target=m.digest,limits=__doc__,cases=rows,characters=characters,downloadRequest=downloadRequest),indent=2)+'\n');print(json.dumps(dict(cases=len(rows),characters=len(characters),output=str(out))))
