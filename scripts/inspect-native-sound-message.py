"""Original selected sound constructor block, scalar/list loader blocks,
actual BYTEasBOOL, ResRef constructors/copy and sound-list allocation/growth.
Typed GFF/resource getters and SetPosition are captured lower boundaries;
base-object lifecycle, resource playback and full Load aren't claimed here.
"""
import importlib,sys,json,itertools,struct,random
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
p=importlib.import_module('inspect-native-area-properties');g=p.g;a=p.a;w=p.w;m=p.m;u=p.u;u.hook_del(p.hook_handle)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
sound=a.objectBase
ranges=[(0x1404f3637,0x1404f36ad),(0x1404f4c3e,0x1404f50d8),(0x1404f3a40,0x1404f3b17),(0x14018de80,0x14018de91),(0x1401e30f0,0x1401e3100)]

def hook(u,at,n,_):
 x,y,z,q=[u.reg_read(reg)for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
 if at==0x14049bb40:
  assert x==sound and z==0;u.mem_write(sound+0xa4,bytes(u.mem_read(y,12)));m.finish();return
 if at==0x1401a12d0:
  data=p.context(z);found='Sound'in data and data['Sound'] is not None
  if found:
   raw=data['Sound'].encode('latin1').split(b'\0')[0][:16];u.mem_write(y,raw.ljust(17,b'\0'))
  else:u.mem_write(y,bytes(u.mem_read(m.q(rsp+0x30),17)))
  m.wi(m.q(rsp+0x28),int(found));m.finish(y);return
 if any(lo<=at<hi for lo,hi in ranges):return
 p.hook(u,at,n,_)
u.hook_add(UC_HOOK_CODE,hook)

def snapshot():
 fields={str(offset):m.si(sound+offset)for offset in [0x308,0x30c,0x310,0x314,0x318,0x31c,0x358,0x35c,0x32c]};fields.update({str(offset):m.si(sound+offset)&0xffffffff for offset in [0x324,0x348,0x34c]});fields['808']=u.mem_read(sound+0x328,1)[0];fields.update({str(offset):m.rf(sound+offset)for offset in [0x320,0x350,0x354,0x330,0x334]});count=m.si(sound+0x340);fields[str(0x340)]=count;ptr=m.q(sound+0x338)
 refs=[bytes(u.mem_read(ptr+i*17,17)).hex()for i in range(count)];return dict(fields=fields,capacity=m.si(sound+0x344),refs=refs,position=[m.rf(sound+o)for o in [0xa4,0xa8,0xac]])
def run(c):
 g.reset({});u.reg_write(UC_X86_REG_RSP,m.stack+0x1fc00);u.reg_write(UC_X86_REG_RBX,sound);u.emu_start(0x1404f3637,0x1404f36ad,count=100000);observations=[]
 for step in c['steps']:
  p.contexts={1:step};p.reads=[];p.nextToken=[10];m.wi(a.client,1);u.reg_write(UC_X86_REG_RSP,m.stack+0x1fa00);u.reg_write(UC_X86_REG_RBP,m.stack+0x1fb00);u.reg_write(UC_X86_REG_R15,sound);u.reg_write(UC_X86_REG_R12,a.client);u.reg_write(UC_X86_REG_RSI,a.array);u.reg_write(UC_X86_REG_RDI,0)
  u.emu_start(0x1404f4c3e,0x1404f50d8,count=1000000);assert u.reg_read(UC_X86_REG_RIP)==0x1404f50d8;observations.append(snapshot())
 return dict(case=c,observations=observations)

if __name__=='__main__':
 rows=[];names=['Active','Positional','Looping','Volume','VolumeVrtn','Times','Hours','GeneratedType','Interval','IntervalVrtn','Continuous','Random','RandomPosition'];floats=['PitchVariation','MinDistance','MaxDistance','RandomRangeX','RandomRangeY','XPosition','YPosition','ZPosition'];rng=random.Random(493600)
 for value in [0,1,2,255,256,-1,0x12345678]:rows.append(run(dict(steps=[{**{name:value for name in names},**{name:float(value)+.25 for name in floats}},{}])))
 for i in range(48):rows.append(run(dict(steps=[{**{name:rng.choice([0,1,2,-1,256])for name in names if rng.random()<.4},**{name:rng.uniform(-100,100)for name in floats if rng.random()<.4}}])))
 for count in [0,1,15,16,17,32,33,65,130]:
  entries=[dict(Sound=['','Sound_UPPER','abcdefghijklmnopq','A\0B','\xff\x80'][i%5]) if i%7!=0 else {}for i in range(count)];rows.append(run(dict(steps=[dict(Sounds=entries),{},dict(Sounds=[dict(Sound='append'),{}])])) )
 out=m.root/'backups/animations/native-sound-message-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2));print(json.dumps(dict(output=str(out),rows=len(rows),executions=sum(len(row['observations'])for row in rows))))
