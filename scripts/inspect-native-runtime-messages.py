"""Complete original echo request/reply, login waypoint reply and TLK writers;
client TLK2/3 parser with captured SetOverride. Real scalar/string/opaque codecs.
Transport, allocation/copy/free, profiling and final override application are
lower boundaries. Synthetic memory only; no original process or asset writes.
"""
import sys,importlib,json,itertools
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
t=importlib.import_module('inspect-native-message-text');w=t.w;r=t.r;m=w.m;u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(t.hook_handle);ranges=[]
for name in ['startup-write-opaque','startup-read-opaque','startup-gui-disable-sender','startup-client-echo-reply','startup-login-waypoint-reply','startup-tlk-update-sender','startup-runtime-config-sender','startup-client-tlk-handler','startup-server-device-reader']:
 d=json.loads((m.root/f'backups/animations/rea-{name}.json').read_text())['structuredContent']['raw_result']['value'];ranges.extend((int(b['start'],16),int(b['end'],16)+1)for b in d['procedure']['body']['ranges'])
raw,owned,player,table,sentinel,nodes,values=[m.heap+n for n in [0x80000,0x81000,0x82000,0x83000,0x84000,0x85000,0x88000]]
def string(p):
 n=m.si(p+8)&0xffffffff;q=m.q(p);return bytes(u.mem_read(q,n)).hex()if q else ''
def hook(u,a,n,data):
 x,y,z,k=[u.reg_read(reg)for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];sp=u.reg_read(UC_X86_REG_RSP)
 if a==0x1404dc490:
  size=m.si(sp+0x30)&0xffffffff;p=m.q(sp+0x28);packets.append((bytes([80,z&255,k&255])+bytes(u.mem_read(p,size))[3:]).hex());m.finish(1);return
 if a==0x1407c25c0:
  size=m.si(sp+0x28)&0xffffffff;packets.append((bytes([112,y&255,z&255])+bytes(u.mem_read(k,size))[3:]).hex());m.finish(1);return
 if a==0x1404baa90:serverEcho.append(dict(dataHex=bytes(u.mem_read(y,z)).hex(),length=z));m.finish();return
 if a==0x14019a800:applied.append(dict(strRef=y&0xffffffff,textHex=string(z)));m.finish();return
 if any(lo<=a<hi for lo,hi in ranges):return
 t.hook(u,a,n,data)
u.hook_add(UC_HOOK_CODE,hook)
def reset(fmt):
 global packets,applied,serverEcho
 packets=[];applied=[];serverEcho=[];t.reset(dict(format=fmt));m.wi(player+0x48,0x80000001);m.wq(0x1412df968,table);m.wq(table+0x78,sentinel);m.wq(sentinel,sentinel);m.wi(table+0x80,0)
def putstr(ptr,buf,data):u.mem_write(buf,data or b'\0');m.wq(ptr,buf);m.wi(ptr+8,len(data));m.wi(ptr+12,len(data)+1)
def readbody(hex):
 data=bytes.fromhex(hex)[3:];u.mem_write(r.packet,data);m.wi(m.stack+0x1fe30,1);w.call(0x1402da7b0,[w.message,r.packet,len(data),0xffffffff])
rows=[]
for fmt,kind,count in itertools.product([0,1],['echo-server','echo-client'],[0,1,7,125,130,1024]):
 reset(fmt);data=bytes((i*127+37)&255 for i in range(count));u.mem_write(raw,data or b'\0')
 if kind=='echo-server':w.call(0x1404d5ef0,[w.message,player,raw,count])
 else:w.call(0x1407bbba0,[w.message,raw,count])
 assert len(packets)==1;packet=packets[0];readbody(packet);length=w.call(r.addresses['dword'],[w.message,32]);w.call(0x1402da400,[w.message,length]);ptr=u.reg_read(UC_X86_REG_RAX);decoded=bytes(u.mem_read(ptr,length)).hex()if ptr else None
 overflow=w.call(r.addresses['overflow']);underflow=w.call(r.addresses['underflow']);accepted=None
 if kind=='echo-client':readbody(packet);accepted=w.call(0x140448710,[w.message,player,3])
 rows.append(dict(format=fmt,kind=kind,dataHex=data.hex(),packet=packet,decodedHex=decoded,overflow=overflow,underflow=underflow,serverAccepted=accepted,serverEcho=list(serverEcho)))
for fmt,data in itertools.product([0,1],[b'',b'SpawnTag',b'Spawn_\x80\xe9']):
 reset(fmt);putstr(owned,raw,data);w.call(0x1407c21f0,[w.message,owned]);assert len(packets)==1;rows.append(dict(format=fmt,kind='waypoint',textHex=data.hex(),packet=packets[0]))
sets=[[],[dict(strRef=123,textHex=b'Server text'.hex())],[dict(strRef=0xffffffff,textHex=b'\x80\xe9'.hex()),dict(strRef=123,textHex=''),dict(strRef=123,textHex=b'Replacement'.hex())]]
for fmt,entries in itertools.product([0,1],sets):
 reset(fmt);m.wi(table+0x80,len(entries));m.wq(sentinel,nodes if entries else sentinel)
 for i,entry in enumerate(entries):
  p=nodes+i*0x40;m.wq(p,p+0x40 if i+1<len(entries)else sentinel);m.wi(p+16,entry['strRef']);putstr(p+24,values+i*0x100,bytes.fromhex(entry['textHex']))
 w.call(0x1404e02e0,[w.message,0x80000001]);assert len(packets)==1;packet=packets[0]
 if fmt==1:readbody(packet);w.call(0x1407ab2f0,[w.message,3])
 rows.append(dict(format=fmt,kind='tlk-list',entries=entries,packet=packet,applied=list(applied)))
for fmt,ref,data in itertools.product([0,1],[0,123,0xffffffff],[b'',b'New value',b'\x80\xe9']):
 reset(fmt);putstr(owned,raw,data);w.call(0x1404e0210,[w.message,0x80000001,ref,owned]);assert len(packets)==1;packet=packets[0]
 if fmt==1:readbody(packet);w.call(0x1407ab2f0,[w.message,2])
 rows.append(dict(format=fmt,kind='tlk-update',entries=[dict(strRef=ref,textHex=data.hex())],packet=packet,applied=list(applied)))
out=m.root/'backups/animations/native-network-runtime-message-observations.json';out.write_text(json.dumps(dict(target=m.digest,limits=__doc__,cases=rows),indent=2)+'\n');print(json.dumps(dict(cases=len(rows),output=str(out))))
