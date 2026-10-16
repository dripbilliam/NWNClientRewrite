"""Read-only complete original LoadProperties, LoadGrass, ambient ctor/load
and actual grass hash/list/vector allocation/rehash/lookup/insertion owners.
Typed GFF access, new/delete/malloc/free/copy and cookie are captured lower
boundaries. No renderer/transport, original asset copies or live modifications.
"""
import importlib,sys,json,itertools,random,struct
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
g=importlib.import_module('inspect-native-area-message-fields');a=g.a;t=g.t;w=g.w;m=g.m;u=g.u;u.hook_del(g.hook_handle)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
ranges=[(0x140361dd0,0x140362252),(0x140361330,0x14036171b),(0x140358610,0x140358746),(0x1403584a0,0x1403584f0),
 (0x14035ac00,0x14035acc8),(0x140369990,0x140369a3a),(0x1403593d0,0x140359461),(0x1403596b0,0x1403598e0),(0x140368570,0x1403685ba),
 (0x140368aa0,0x140368c28),(0x140368d30,0x140368e13),(0x140368fd0,0x140369044),(0x140369490,0x1403694d2),(0x140359570,0x140359607)]

def context(ptr):return contexts.get(m.si(ptr),{}) if ptr else {}
def text(ptr):return bytes(u.mem_read(ptr,80)).split(b'\0')[0].decode('ascii')
def cbytes(ptr):return bytes(u.mem_read(m.q(ptr),m.si(ptr+8)&0xffffffff)) if m.q(ptr) else b''

def hook(u,at,n,_):
 if at==m.stop:u.emu_stop();return
 x,y,z,q=[u.reg_read(reg)for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
 if at==0x140c10360:m.finish();return
 if at==0x1401a04e0:
  key=text(q);value=context(z).get(key);found=isinstance(value,dict);token=nextToken[0];nextToken[0]+=1
  if found:contexts[token]=value;m.wi(y,token)
  m.finish(int(found));return
 if at==0x1401a02c0:
  value=context(z).get(text(q));found=isinstance(value,list);token=nextToken[0];nextToken[0]+=1
  if found:contexts[token]=value;m.wi(y,token)
  m.finish(int(found));return
 if at==0x1401a0370:m.finish(len(context(y)));return
 if at==0x1401a03f0:
  values=context(z);found=q<len(values)
  if found:token=nextToken[0];nextToken[0]+=1;contexts[token]=values[q];m.wi(y,token)
  m.finish(int(found));return
 if at in g.getters:
  kind=g.getters[at];name=text(z);data=context(y);default=m.rf(rsp+0x28) if kind=='float' else m.si(rsp+0x28)&0xffffffff
  if kind=='byte':default&=255
  if kind=='word':default&=65535
  if kind=='int' and default>=1<<31:default-=1<<32
  found=name in data and data[name] is not None;value=data[name] if found else default;reads.append([kind,name,default,value,int(found)]);m.wi(q,int(found))
  if kind=='float':u.reg_write(UC_X86_REG_XMM0,int.from_bytes(struct.pack('<f',value),'little'));m.finish()
  else:m.finish(value)
  return
 if at==0x1401a1130:
  name=text(q);data=context(z);found=name in data and data[name] is not None;raw=data[name].encode('latin1') if found else cbytes(m.q(rsp+0x30));a.owning(y,raw);m.wi(m.q(rsp+0x28),int(found));reads.append(['string',name,raw.hex(),int(found)]);m.finish(y);return
 if any(lo<=at<hi for lo,hi in ranges):return
 g.hook(u,at,n,_)
hook_handle=u.hook_add(UC_HOOK_CODE,hook)

def call(address,args):
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],args):u.reg_write(reg,value&0xffffffffffffffff)
 u.emu_start(address,m.stop,count=5000000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return u.reg_read(UC_X86_REG_RAX)&0xffffffff

def snapshot(previous):
 values={str(o):u.mem_read(a.area+o,1)[0]for o in [0xe0,0xe4,0xa4,0xc4]};values.update({str(o):m.si(a.area+o)&0xffffffff for o in [0x98,0x9c,0xa0,0xb8,0xbc,0xc0]});values.update({str(o):m.si(a.area+o)for o in [0x34c,0x368]});values.update({str(o):m.rf(a.area+o)for o in g.floatOffsets if o!=0x108})
 ambient={str(o):m.si(a.ambient+o)for o in [8,0xc,0x10,0x14,0x18,0x1c,0x20,0x24,0x28]};ambient.update({str(o):u.mem_read(a.ambient+o,1)[0]for o in [0x2c,0x2d]});ambient['48']=m.si(a.ambient+0x30)&0xffffffff
 entries=[];pointers={};grassMap=a.area+0x370;head=m.q(grassMap+8);node=m.q(head)
 while node!=head:
  key=m.si(node+0x10)&0xffffffff;pointers[key]=node;entry={str(0x10):key};entry.update({str(o):m.rf(node+o)for o in range(0x28,0x48,4)});entries.append(dict(fields=entry,name=cbytes(node+0x18).hex()));node=m.q(node);assert len(entries)<2048
 assert len(entries)==m.q(grassMap+0x10)
 return dict(fields=values,ambient=ambient,name=cbytes(a.area+0x358).hex(),nameLength=m.si(a.area+0x360),grass=entries,buckets=m.q(grassMap+0x38),retained=[key for key,node in pointers.items() if previous.get(key)==node]),pointers

def run(c):
 global contexts,nextToken,reads
 contexts={};nextToken=[10];reads=[];g.reset({});m.wq(a.area+0x328,a.ambient);m.wi(a.area+0x140,c.get('id',4));m.wq(a.area+0x358,0);m.wq(a.area+0x360,0)
 a.fields(a.area,c.get('initial',{}));call(0x1403584a0,[a.ambient,c.get('id',4),0,0]);a.fields(a.ambient,c.get('ambient',{}))
 if c.get('name'):a.owning(a.area+0x358,bytes.fromhex(c['name']))
 grassMap=a.area+0x370;m.wf(grassMap,1.);u.mem_write(grassMap+8,bytes(0x38));head=call(0x140368570,[grassMap+8,0,0,0]);head=u.reg_read(UC_X86_REG_RAX);m.wq(grassMap+8,head);call(0x140368aa0,[grassMap,8,0,0])
 observations=[];previous={}
 for step in c['steps']:
  contexts={1:step};nextToken=[10];m.wi(a.client,1);reads=[];result=call(0x140361dd0,[a.area,a.array,a.client,0]);value,previous=snapshot(previous);observations.append(dict(result=result,value=value,reads=reads))
 return dict(case=c,observations=observations)

if __name__=='__main__':
 cases=[];names=['EnvAudio','SkyBox','MoonFogColor','SunFogColor','MoonFogAmount','SunFogAmount','MoonAmbientColor','MoonDiffuseColor','SunAmbientColor','SunDiffuseColor','MusicDelay','MusicDay','MusicNight','MusicBattle','AmbientSndDay','AmbientSndNight','AmbientSndDayVol','AmbientSndNitVol'];floatNames=['WindDirectionX','WindDirectionY','WindDirectionZ','WindMagnitude','WindYaw','WindPitch','MoonDirectionX','MoonDirectionY','MoonDirectionZ','SunDirectionX','SunDirectionY','SunDirectionZ'];rng=random.Random(361330)
 for value,wind,name in itertools.product([0,1,-1,256,0x12345678],[False,True],['','Fixture','\0ABC','A\0B\xff\x80']):
  props={key:value for key in names};props.update({key:float(value)+.25 for key in floatNames if key!='WindPitch' or wind});props['DisplayName']=name;cases.append(dict(steps=[dict(AreaProperties=props)],initial={'e0':['byte',77],'98':['dword',0x88776655]},name='4f6c64'))
 for _ in range(32):cases.append(dict(steps=[dict(AreaProperties={name:rng.choice([0,1,-1,256])for name in names+floatNames if rng.random()<.3})]))
 for keys in [[],[0],[0,8,16],[8,0,8,16,0],list(range(8)),list(range(9)),list(range(64)),list(range(65)),list(range(256)),list(reversed(range(256))),[i*8%256 for i in range(60)],[rng.randrange(0,256)for i in range(180)]]:
  entries=[dict(GrassMaterialId=key,GrassTexture=f'grass_{i}',GrassDensity=i+.25,GrassHeight=-i-.5,GrassAmbientX=.5)for i,key in enumerate(keys)];cases.append(dict(steps=[dict(AreaProperties=dict(GrassDefDisabled=2,GrassOverrides=dict(GrassOvrList=entries))),dict(AreaProperties=dict(GrassOverrides=dict(GrassOvrList=[dict(GrassMaterialId=8,GrassTexture='updated'),dict(GrassMaterialId=0,GrassDiffuseZ=3.)]))),dict(AreaProperties={})]))
 cases.extend([dict(steps=[{}]),dict(steps=[dict(AreaProperties={})]),dict(steps=[dict(AreaProperties={'WindPitch':0}),dict(AreaProperties={})]),dict(steps=[dict(AreaProperties={'DisplayName':'New'}),dict(AreaProperties={}),dict(AreaProperties={'DisplayName':''})])])
 rows=[]
 for i,c in enumerate(cases):
  try:rows.append(run(c))
  except Exception:print(json.dumps(dict(index=i,case=c,rip=hex(u.reg_read(UC_X86_REG_RIP)))));raise
 out=m.root/'backups/animations/native-area-properties-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2));print(json.dumps(dict(output=str(out),rows=len(rows),executions=sum(len(row['observations'])for row in rows))))
