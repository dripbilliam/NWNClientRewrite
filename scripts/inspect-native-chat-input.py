"""Complete original player chat senders, real strings/scalars and captured
transport7c25c0. No game process writes, server changes or copied assets.
"""
import sys,importlib,json,itertools
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
t=importlib.import_module('inspect-native-message-text');w=t.w;m=w.m;u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(t.hook_handle);ranges=[];addresses={}
for kind in ['talk','shout','whisper','party','dm','tell-id','tell-name']:
 d=json.loads((m.root/f'backups/animations/rea-chat-send-{kind}.json').read_text())['structuredContent']['raw_result']['value']
 ranges.extend((int(r['start'],16),int(r['end'],16)+1)for r in d['procedure']['body']['ranges']);addresses[kind]=int(d['procedure']['address'],16)
text,name,raw,nameRaw=[m.heap+n for n in [0x90000,0x91000,0x92000,0x93000]]
def hook(u,a,n,data):
 if a==0x1407c25c0:
  sp=u.reg_read(UC_X86_REG_RSP);size=m.si(sp+0x28)&0xffffffff;ptr=u.reg_read(UC_X86_REG_R9)
  packets.append(bytes([112,u.reg_read(UC_X86_REG_RDX)&255,u.reg_read(UC_X86_REG_R8)&255])+bytes(u.mem_read(ptr,size))[3:]);m.finish(1);return
 if any(lo<=a<hi for lo,hi in ranges):return
 t.hook(u,a,n,data)
u.hook_add(UC_HOOK_CODE,hook);rows=[]
for fmt,kind,data in itertools.product([0,1],addresses,[b'',b'Hello original clients',b'Native \x80\xe9',b'<img src=x>']):
 for playerId in ([0,1,0x80000001,0xffffffff]if kind=='tell-id'else[0]):
  packets=[];t.reset(dict(format=fmt));u.mem_write(raw,data or b'\0');m.wq(text,raw);m.wi(text+8,len(data));u.mem_write(nameRaw,b'Remote Hero');m.wq(name,nameRaw);m.wi(name+8,11)
  args=[w.message,playerId,text]if kind=='tell-id'else[w.message,name,text]if kind=='tell-name'else[w.message,text]
  w.call(addresses[kind],args);assert len(packets)==1;rows.append(dict(format=fmt,kind=kind,textHex=data.hex(),recipient='Remote Hero'if kind=='tell-name'else playerId,packet=packets[0].hex()))
out=m.root/'backups/animations/native-network-chat-input-observations.json';out.write_text(json.dumps(dict(target=m.digest,limits=__doc__,cases=rows),indent=2)+'\n');print(json.dumps(dict(cases=len(rows),output=str(out))))
