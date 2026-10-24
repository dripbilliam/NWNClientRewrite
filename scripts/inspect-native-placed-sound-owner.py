"""Original client sound frame, selection, interval, time gate and source Play.
Source methods, resource metadata/Demand, tile/clock/object providers, debug
markers and allocator/list-growth boundaries are explicit synthetic adapters.
Native state decisions and pitch/duration arithmetic execute unmodified.
"""
import sys,importlib,json,itertools,struct
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent));t=importlib.import_module('inspect-native-message-text');w=t.w;m=w.m;u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(t.hook_handle)
def dossier(name):
 d=json.loads((m.root/'backups/animations'/name).read_text())
 if d.get('structuredContent',{}).get('raw_result',{}).get('value'):return d['structuredContent']['raw_result']['value']
 e=json.loads(next(c['text']for c in d['content']if c['type']=='text'));return e.get('normalized_result',e.get('raw_result',e))
ranges=[(0x14018de80,0x14018def0)]
for name in ['frame','select','interval','time-gate','shuffle']:
 d=dossier('rea-placed-sound-owner-'+name+'.json');ranges.extend((int(r['start'],16),int(r['end'],16)+1)for r in d['procedure']['body']['ranges'])
play=dossier('rea-native-audio-internal-play-code.json');ranges.extend((int(r['start'],16),int(r['end'],16)+1)for r in play['procedure']['body']['ranges'])
waveInfo=dossier('rea-placed-sound-wave-info.json');ranges.extend((int(r['start'],16),int(r['end'],16)+1)for r in waveInfo['procedure']['body']['ranges']);getData=next(int(c['address'],16)for c in waveInfo['callees']if c['name']=='CRes::GetData')
allocate=next(int(c['address'],16)for c in dossier('rea-placed-sound-owner-shuffle.json')['callees']if c['name']=='CExoArrayList<CResRef>::Allocate')
state,source,listed,refs,client,timer,area,tile,manager,voice,wave,output=[m.heap+n*0x1000 for n in range(0x81,0x8d)]
def ref(ptr):return bytes(u.mem_read(ptr,17)).split(b'\0')[0].decode('cp1252')
def vector(ptr):return list(struct.unpack('<3f',u.mem_read(ptr,12)))
def rand():
 global draw
 value=case.get('random',[17,2,31,127])[draw%len(case.get('random',[17,2,31,127]))];draw+=1;return value
def hook(u,a,n,data):
 x,y,z,k=[u.reg_read(q)for q in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];sp=u.reg_read(UC_X86_REG_RSP)
 # Sized/free thunk10360 jumps to the same1148c target as free10370;
 # it is not the allocation thunk10368. Both deallocations are observed noops.
 if a==0x140c10360:m.finish();return
 if a==0x140c7ed00:m.finish(rand());return
 if mode in ['pitch','wave-play']:
  if a==0x1401db740:m.finish(1);return
  if a==0x1401a5940 and mode=='pitch':
   channels=case['channels'];rate=case['sampleRate'];u.mem_write(y,struct.pack('<HHIIHH',1,channels,rate,rate*channels*2,channels*2,16));m.wi(z,rate//4*channels*2);m.finish(1);return
  if a==0x1401dc500:m.finish(0);return
  if a==0x1401e0550:m.finish();return
  if a==getData:m.finish(wave+0x200);return
 if mode not in ['pitch','wave-play']:
  if a==0x1401d9c00:m.finish(case.get('playing',0));return
  if a==0x1401d9a80:m.finish(case.get('loop',0));return
  if a==0x1401da1c0:calls.append(dict(op='resref',value=ref(y)));m.finish();return
  if a==0x1401da2a0:calls.append(dict(op='volume',value=y&255));m.finish();return
  if a==0x1401d9fe0:calls.append(dict(op='pitch',value=struct.unpack('<f',u.reg_read(UC_X86_REG_XMM1).to_bytes(16,'little')[:4])[0]));m.finish();return
  if a==0x1401da020:calls.append(dict(op='position',value=vector(y)));m.finish();return
  if a==0x1401da320:calls.append(dict(op='stop'));m.finish();return
  if a==0x1401d9ca0:calls.append(dict(op='play'));m.finish(case.get('duration',250));return
  if a==0x14098a260 and mode=='frame':u.mem_write(y,case.get('ref','stub_ref').encode().ljust(17,b'\0'));m.finish(y);return
  if a==0x14018dfd0:m.finish(int(ref(x)=='0'));return
  if a==0x140762990:m.finish();return
  if a==0x1407658c0:u.mem_write(x+0x38,bytes(u.mem_read(y,12)));m.finish();return
  if a==0x1407db200:m.finish(tile);return
  if a==0x1407ee540:
   count=m.si(x+8);ptr=m.q(x)
   if y<count:
    if y+1<count:u.mem_write(ptr+y*17,bytes(u.mem_read(ptr+(y+1)*17,(count-y-1)*17)))
    m.wi(x+8,count-1)
   m.finish();return
  if a==allocate:
   count=m.si(x+8);old=m.q(x);size=y*17;ptr=m.heap+w.cursor;w.cursor+=(size+15)&~15
   if old and count:u.mem_write(ptr,bytes(u.mem_read(old,count*17)))
   m.wq(x,ptr);m.wi(x+12,y);m.finish();return
  if a==0x1406abea0:m.finish(client);return
  if a==0x1406ac330:m.finish(timer);return
  if a==0x140597180:m.wi(y,0);m.wi(z,case.get('elapsed',0));m.finish();return
  if a==0x140597a20:m.wi(m.q(sp+0x30),0);m.wi(m.q(sp+0x38),case.get('elapsed',0));m.finish();return
 if any(lo<=a<hi for lo,hi in ranges):return
 t.hook(u,a,n,data)
u.hook_add(UC_HOOK_CODE,hook);rows=[]
def setup(c):
 global calls,case,draw
 case=c;calls=[];draw=0;t.reset(dict(format=1));m.wq(state+0x170,source);m.wq(state+0x30,area);m.wq(state+0x1b0,listed);m.wq(listed,refs);m.wi(listed+8,c.get('count',2));m.wi(listed+12,16);m.wi(client+0x16c,c.get('hour',6));u.mem_write(client+0x170,bytes([c.get('timeOfDay',1)]));m.wi(area+0xc,12);m.wi(area+0x10,10);m.wi(tile+0x18,2)
 for i in range(c.get('count',2)):u.mem_write(refs+i*17,('sound_'+str(i)).encode().ljust(17,b'\0'))
 for offset,value in {0x178:c.get('active',1),0x17c:c.get('volume',27),0x180:c.get('volumeVariation',0),0x184:c.get('times',3),0x188:c.get('allowed',1),0x194:c.get('hours',0),0x198:c.get('loopPending',1),0x1a0:c.get('randomPosition',0),0x1b8:c.get('index',0),0x1bc:c.get('interval',1000),0x1c0:c.get('variation',0),0x1c4:c.get('gap',0),0x1c8:c.get('remaining',0),0x1cc:c.get('continuous',1),0x1d0:c.get('randomList',0),0x1d4:c.get('first',1)}.items():m.wi(state+offset,int(value))
 for offset,value in {0x18c:1.8,0x190:.2,0x1a4:c.get('rangeX',10),0x1a8:c.get('rangeY',10)}.items():m.wf(state+offset,value)
 u.mem_write(state+0x38,struct.pack('<3f',3.25,8.5,1.8))
def observation(c,kind):return dict(kind=kind,case=c,calls=calls,draws=draw,fields={hex(o):m.si(state+o)&0xffffffff for o in [0x178,0x188,0x198,0x1b8,0x1c4,0x1c8,0x1d4]},refs=[ref(m.q(listed)+i*17)for i in range(m.si(listed+8))],position=vector(state+0x38))
mode='frame'
for active,allowed,loop,playing,pending,waits,elapsed,duration in itertools.product([0,1],[0,1],[0,1],[0,1],[0,1],[(0,0),(100,0),(0,120),(100,120)],[0,99,100,250,1000],[0,250]):
 c=dict(active=active,allowed=allowed,loop=loop,playing=playing,loopPending=pending,remaining=waits[0],gap=waits[1],elapsed=elapsed,duration=duration);setup(c);w.call(0x140989610,[state]);rows.append(observation(c,'frame'))
for volume,variation,rng,rpos,rangeX in itertools.product([-1,0,27,127,255,2147483647],[0,1,127],[[0],[1],[32767],[17,2,31,127]],[0,1],[0,10]):
 c=dict(volume=volume,volumeVariation=variation,random=rng,randomPosition=rpos,rangeX=rangeX);setup(c);w.call(0x140989610,[state]);rows.append(observation(c,'frame'))
mode='gate'
for times,hours,hour,tod,allowed in itertools.product([0,1,2,3,255],[0,1,0xffffffff],[0,6,23,31,32],[0,1,2,3,4,5],[0,1]):
 c=dict(times=times,hours=hours,hour=hour,timeOfDay=tod,allowed=allowed);setup(c);w.call(0x14098af90,[state]);rows.append(observation(c,'gate'))
mode='interval'
for base,variation,rng in itertools.product([0,1,1000,0x7fffffff,0xffffffff],[0,1,5000,0x7fffffff],[[0],[1],[32767]]):
 c=dict(interval=base,variation=variation,random=rng,gap=12);setup(c);w.call(0x14098ad10,[state]);rows.append(observation(c,'interval'))
mode='select'
for count,first,continuous,randomList,rng in itertools.product([1,2,3,17],[0,1],[0,1],[0,1],[[0],[1],[32767]]):
 for index in [0,count-1]:
  c=dict(count=count,first=first,continuous=continuous,randomList=randomList,random=rng,index=index);setup(c);w.call(0x14098a260,[state,output]);row=observation(c,'select');row['selected']=ref(output);row['refs']=[ref(m.q(m.q(state+0x1b0))+i*17)for i in range(count)];rows.append(row)
mode='pitch'
for positional,channels,rate,variation,rng in itertools.product([0,1],[1,2],[8000,22050,44100],[0,.1,.2,1,2],[[0],[1],[127],[32767]]):
 c=dict(positional=positional,channels=channels,sampleRate=rate,variation=variation,random=rng);setup(c);m.wq(source+0x70,manager);m.wi(manager+0x48,1);m.wq(source+8,wave);m.wi(source+0x30,positional);m.wf(source+0x44,variation);result=w.call(0x1401df2e0,[source,0,0]);rows.append(dict(kind='pitch',case=c,duration=result,sampleRate=m.si(source+0x48)&0xffffffff,draws=draw))
mode='wave-play'
for bits,rate,channels,size,fact,odd in itertools.product([4,8,16,24,32],[8000,22050,44100],[1,2],[0,1,100,1024],[0,17,10000],[False,True]):
 c=dict(bits=bits,sampleRate=rate,channels=channels,dataBytes=size,fact=fact,odd=odd);setup(c)
 def chunk(tag,data):return tag+struct.pack('<I',len(data))+data+(b'\0'if len(data)&1 else b'')
 fmt=struct.pack('<HHIIHH',17 if bits==4 else 1,channels,rate,rate*channels*bits//8,max(1,channels*bits//8),bits)
 body=b'WAVE'+chunk(b'fmt ',fmt)+chunk(b'fact',struct.pack('<I',fact))+(chunk(b'JUNK',b'odd')if odd else b'')+chunk(b'data',bytes(size));packet=b'RIFF'+struct.pack('<I',len(body))+body;u.mem_write(wave+0x200,packet)
 m.wq(source+0x70,manager);m.wi(manager+0x48,1);m.wq(source+8,wave);result=w.call(0x1401df2e0,[source,0,0]);rows.append(dict(kind='wave-play',case=c,hex=packet.hex(),duration=result))
out=m.root/'backups/animations/native-placed-sound-owner-observations.json';out.write_text(json.dumps(dict(target=m.digest,limits=__doc__,cases=rows),indent=2)+'\n');print(json.dumps(dict(cases=len(rows),output=str(out))))
