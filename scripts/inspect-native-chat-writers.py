"""Complete native talk/whisper/shout/tell/party/strref writers with original
scalar, string, object-ID and localized-name codecs. Creature lookup and name
virtual getters, locstring lifetime and transport are captured boundaries.
Synthetic memory only; no game process writes or proprietary asset copies.
"""
import sys,importlib,json,itertools,struct
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
t=importlib.import_module('inspect-native-message-text');w=t.w;m=w.m;u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(t.hook_handle)
ranges=[]
for name in ['chat-talk','chat-whisper','chat-shout','chat-tell','chat-party','chat-strref','chat-dm-talk','chat-dm-whisper','chat-dm-shout']:
 d=json.loads((m.root/f'backups/animations/rea-{name}.json').read_text())['structuredContent']['raw_result']['value']
 ranges.extend((int(r['start'],16),int(r['end'],16)+1)for r in d['procedure']['body']['ranges'])
creature,vt,text,raw,first,last=[m.heap+n for n in [0x80000,0x82000,0x83000,0x84000,0x85000,0x87000]]
def loc(ptr,value,reference):
 private,linked,node,entry,buf=[ptr+n for n in [0x100,0x200,0x300,0x400,0x500]]
 m.wq(ptr,private);m.wi(ptr+8,reference);m.wq(private,linked);m.wi(private+8,int(c['nameMode']=='localized'));m.wq(linked,node if c['nameMode']=='localized' else 0)
 m.wq(node+8,0);m.wq(node+0x10,entry);m.wi(entry,0);m.wq(entry+8,buf);m.wi(entry+0x10,len(value));u.mem_write(buf,value)
def hook(u,a,n,data):
 x=u.reg_read(UC_X86_REG_RCX)
 if a==0x14055b3d0:m.finish(0 if c['nameMode']=='missing' else creature);return
 if a==m.stop+0x240:m.finish(first);return
 if a==m.stop+0x260:m.finish(last);return
 if a==0x140169560:
  global constructors
  private=m.heap+0x8a000+constructors*0x800;constructors+=1;m.wq(x,private);m.wi(x+8,0xffffffff);m.wq(private,private+0x100);m.wi(private+8,0);m.wq(private+0x100,0);m.finish(x);return
 if a==0x1401695b0:m.finish();return
 if a==0x1404dc490:
  sp=u.reg_read(UC_X86_REG_RSP);size=m.si(sp+0x30)&0xffffffff;ptr=m.q(sp+0x28)
  packets.append(bytes([80,u.reg_read(UC_X86_REG_R8)&255,u.reg_read(UC_X86_REG_R9)&255])+bytes(u.mem_read(ptr,size))[3:]);m.finish(1);return
 if any(lo<=a<hi for lo,hi in ranges):return
 t.hook(u,a,n,data)
u.hook_add(UC_HOOK_CODE,hook)
rows=[]
for fmt,kind,nameMode in itertools.product([0,1],['talk','whisper','shout','tell','party','strref','dm-talk','dm-whisper','dm-shout'],['localized','strref','custom','missing']):
 c=dict(format=fmt,kind=kind,nameMode=nameMode);packets=[];constructors=0;t.reset(dict(format=fmt));m.wq(creature,vt);m.wq(vt+0x120,m.stop+0x240);m.wq(vt+0x128,m.stop+0x260)
 u.mem_write(creature+0xa4,struct.pack('<3f',12.25,-3.5,1.125));loc(first,b'Remote',123);loc(last,b'Speaker',456)
 data=b'Native chat \x80\xe9 <unsafe>';u.mem_write(raw,data);m.wq(text,raw);m.wi(text+8,len(data))
 if nameMode=='custom':u.mem_write(creature+0x8c0,struct.pack('<QII',raw+0x100,15,16));u.mem_write(raw+0x100,b'Renamed Speaker\0')
 if kind=='strref':
  for channel in [8,9,10,15]:
   packets=[];m.wq(m.stack+0x1fe08+0x28,57779);w.call(0x1404d4660,[w.message,0x80000001,0x13,channel]);rows.append(dict(case=c|dict(channel=channel),result=1,packets=[p.hex()for p in packets]))
 else:
  address={'talk':0x1404d4700,'whisper':0x1404d4a50,'shout':0x1404d4000,'tell':0x1404d47f0,'party':0x1404d3cc0,'dm-talk':0x1404d3800,'dm-whisper':0x1404d3a60,'dm-shout':0x1404d35a0}[kind]
  try:result=w.call(address,[w.message,0x80000001,0x13,text])
  except Exception:print(json.dumps(dict(case=c,rip=hex(u.reg_read(UC_X86_REG_RIP)))));raise
  rows.append(dict(case=c,result=result,packets=[p.hex()for p in packets]))
out=m.root/'backups/animations/native-network-chat-writer-observations.json';out.write_text(json.dumps(dict(target=m.digest,limits=__doc__,cases=rows),indent=2)+'\n');print(json.dumps(dict(cases=len(rows),output=str(out))))
