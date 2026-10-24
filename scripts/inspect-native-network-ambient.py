"""Complete original eight packet40 server writers and ambient play owners.
Real CNWMessage codecs and CResRef copy execute. Transport, output streams,
table resolution, world-clock reads and virtual owner callbacks are explicit
synthetic boundaries. These cases do not prove live playback or mixer parity.
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
writers={1:0x1404cd460,2:0x1404cd4f0,3:0x1404cd3c0,4:0x1404cd330,5:0x1404cd290,6:0x1404cd630,7:0x1404cd590,8:0x1404cd6c0}
files={1:'music-play',2:'music-delay',3:'music-change',4:'battle-play',5:'battle-change',7:'loop-change',8:'loop-volume'}
ownerFiles={1:'music-play',4:'battle-play',6:'loop-play'}
ranges=[(0x14018dea0,0x14018decd)]
for minor in writers:
 d=dossier('rea-network-audio-ambient-play.json'if minor==6 else 'rea-ambient-server-'+files[minor]+'.json')
 ranges.extend((int(r['start'],16),int(r['end'],16)+1)for r in d['procedure']['body']['ranges'])
for name in ownerFiles.values():
 d=dossier('rea-ambient-owner-'+name+'.json');ranges.extend((int(r['start'],16),int(r['end'],16)+1)for r in d['procedure']['body']['ranges'])
for lo,hi in [(0x140877640,0x140878064),(0x140878070,0x1408780e7),(0x140878240,0x1408783cf),(0x1408783d0,0x140878711)]:ranges.append((lo,hi))
state,streamMusic,streamAmbient,vt,raw,clock=[m.heap+n*0x1000 for n in range(0x81,0x87)]
compare=next(int(c['address'],16)for c in dossier('rea-ambient-owner-battle-play.json')['callees']if c['name']=='CExoString::CompareNoCase')
def cstring(ptr):
 if not ptr:return ''
 b=bytes(u.mem_read(ptr,256));return b.split(b'\0')[0].decode('cp1252')
def stream(ptr):return 'music'if ptr==streamMusic else 'ambient'
def hook(u,a,n,data):
 x,y,z,k=[u.reg_read(q)for q in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];sp=u.reg_read(UC_X86_REG_RSP)
 if a==0x1404dc490:
  size=m.si(sp+0x30)&0xffffffff;packets.append((bytes([80,z&255,k&255])+bytes(u.mem_read(m.q(sp+0x28),size))[3:]).hex());m.finish(1);return
 if mode=='owner':
  if a==0x1401d9c10:m.finish(case.get('playingMusic'if x==streamMusic else 'playingAmbient',case.get('playing',0)));return
  if a==0x1401d9cc0:calls.append(dict(op='play',stream=stream(x),resRef=bytes(u.mem_read(y,16)).split(b'\0')[0].decode(),type=z));m.finish(case['success']);return
  if a==0x1401d9850:calls.append(dict(op='fade',stream=stream(x),duration=y));m.finish();return
  if a==0x1401da2d0:calls.append(dict(op='volume',stream=stream(x),volume=y&255));m.finish();return
  if a==0x1401d99d0:u.mem_write(raw,case.get('currentMusic'if x==streamMusic else 'currentAmbient',case.get('current','')).encode()+b'\0');m.finish(raw);return
  if a==compare:m.finish(int(cstring(m.q(x)).lower()==cstring(m.q(y)).lower()));return
  if a==0x140876cd0:calls.append(dict(op='stinger'));m.finish();return
  if a==0x140877600:calls.append(dict(op='clock'));m.finish();return
  if a==0x1408771a0:
   name='new_track';ptr=raw+0x400;u.mem_write(ptr,name.encode()+b'\0');m.wq(k,ptr);m.wi(k+8,len(name));m.wi(k+12,len(name)+1);calls.append(dict(op='resolve',music=y,id=z&0xffffffff,key=hex(k-state)));m.finish();return
  if a in [0x1406ab9b0,0x1406abea0]:m.finish(clock+0x800);return
  if a==0x1406ac330:m.finish(clock+0x900);return
  if a==0x140597180:m.wi(y,0);m.wi(z,60000);m.finish();return
  if a==0x140597a20:m.wi(m.q(sp+0x30),0);m.wi(m.q(sp+0x38),case['elapsed']);m.finish();return
  if a in [m.stop+0x40,m.stop+0x48,m.stop+0x50]:calls.append(dict(op='owner',slot=(a-m.stop-0x40)//8,play=y));m.finish();return
 if any(lo<=a<hi for lo,hi in ranges):return
 t.hook(u,a,n,data)
u.hook_add(UC_HOOK_CODE,hook);rows=[]
for minor,fmt,value,day in itertools.product(writers,[0,1],[-2147483648,-1,0,1,255,256,90000,2147483647],[0,1]):
 mode='writer';packets=[];calls=[];t.reset(dict(format=fmt))
 args=[w.message,0x80000001,day,value]if minor in [3,7,8]else [w.message,0x80000001,value]
 w.call(writers[minor],args);rows.append(dict(kind='wire',minor=minor,format=fmt,value=value,day=day,packets=packets))
for minor,play,enabled,single,playing,success,day,battle,ambient,category in itertools.product([1,4,6],[0,1],[0,1],[0,1],[0,1],[0,1],[0,1],[0,1],[0,1],[0,1,2,3,4]):
 mode='owner';calls=[];case=dict(minor=minor,play=play,enabled=enabled,single=single,playing=playing,success=success,day=day,battle=battle,ambient=ambient,category=category,current='other')
 t.reset(dict(format=1));m.wq(state,vt);m.wq(vt,m.stop+0x40);m.wq(vt+0x20,m.stop+0x48);m.wq(vt+0x30,m.stop+0x50);m.wq(state+0x188,streamMusic);m.wq(state+0x190,streamAmbient)
 for offset,value in {8:1,0x18:battle,0x20:ambient,0x170:30000,0x174:0,0x1a0:1,0x1a4:1,0x1a8:enabled,0x1ac:day,0x1b8:single,0x1bc:category,0x1c0:0,0x1c4:0}.items():m.wi(state+offset,value)
 u.mem_write(state+0x2c,bytes([48,49]))
 for i,(offset,name)in enumerate([(0x30,'music_day'),(0x70,'music_night'),(0xb0,'battle'),(0xf0,'ambient_day'),(0x130,'ambient_night')]):
  ptr=clock+i*0x100;u.mem_write(ptr,name.encode()+b'\0');m.wq(state+offset,ptr);m.wi(state+offset+8,len(name));m.wi(state+offset+12,len(name)+1)
 w.call({1:0x140876990,4:0x140876530,6:0x1408761a0}[minor],[state,play]);fields={hex(o):m.si(state+o)for o in [8,0x18,0x20,0x174,0x1bc,0x1c0]};rows.append(dict(kind='owner',case=case,calls=calls,fields=fields))
def prepare(c):
 global mode,calls,case
 mode='owner';case=c;calls=[];t.reset(dict(format=1));m.wq(state,vt);m.wq(vt,m.stop+0x40);m.wq(vt+0x20,m.stop+0x48);m.wq(vt+0x30,m.stop+0x50);m.wq(state+0x188,streamMusic);m.wq(state+0x190,streamAmbient)
 for offset,value in {8:1,0x18:0,0x20:1,0x170:30000,0x174:0,0x1a0:1,0x1a4:1,0x1a8:1,0x1ac:1,0x1b8:0,0x1c0:0}.items():m.wi(state+offset,value)
 for key,value in c.get('fields',{}).items():m.wi(state+int(key,16),value)
 u.mem_write(state+0x2c,bytes([48,49]))
 for i,(offset,name)in enumerate([(0x30,'music_day'),(0x70,'music_night'),(0xb0,'battle'),(0xf0,'ambient_day'),(0x130,'ambient_night')]):
  ptr=clock+i*0x100;u.mem_write(ptr,name.encode()+b'\0');m.wq(state+offset,ptr);m.wi(state+offset+8,len(name));m.wi(state+offset+12,len(name)+1)
def observe(c,kind):
 return dict(kind=kind,case=c,calls=list(calls),fields={hex(o):m.si(state+o)for o in [8,0x18,0x20,0x10,0x14,0x1c,0x24,0x28,0x170,0x174,0x1ac,0x1a8,0x1b8]},volumes=list(u.mem_read(state+0x2c,2)))
for op,playing,current,value,day in itertools.product([2,3,5,7,8],[0,1],['','other','music_day','music_night','battle','ambient_day','ambient_night'],[-2147483648,-1,0,1,48,49,255,256,90000,2147483647],[0,1]):
 c=dict(operation=op,playing=playing,current=current,value=value,day=day);prepare(c)
 if op==2:w.call(0x140877ee0,[state,value])
 elif op==3:w.call(0x140877d60 if day else 0x140877ef0,[state,value])
 elif op==5:w.call(0x140877be0,[state,value])
 elif op==7:w.call(0x140877640 if day else 0x140877910,[state,value])
 else:w.call(0x1408777b0 if day else 0x140877a80,[state,value])
 rows.append(observe(c,'command'))
for tod,day,currentMusic,currentAmbient in itertools.product([0,1,2,3,4,5],[0,1],['','other','music_day','music_night'],['','other','ambient_day','ambient_night']):
 c=dict(timeOfDay=tod,fields={'1ac':day},currentMusic=currentMusic,currentAmbient=currentAmbient);prepare(c);u.mem_write(clock+0x800+0x170,bytes([tod]));w.call(0x1408783d0,[state]);rows.append(observe(c,'day-night'))
for playingMusic,playingAmbient,retry,elapsed,battle in itertools.product([0,1],[0,1],[0,1,1000,30000],[0,1,999,1000,30001],[0,1]):
 c=dict(playingMusic=playingMusic,playingAmbient=playingAmbient,fields={'174':retry,'18':battle},elapsed=elapsed);prepare(c);w.call(0x140878240,[state]);rows.append(observe(c,'frame'))
out=m.root/'backups/animations/native-network-ambient-observations.json';out.write_text(json.dumps(dict(target=m.digest,limits=__doc__,cases=rows),indent=2)+'\n');print(json.dumps(dict(cases=len(rows),output=str(out))))
