"""Execute the original creation-mode Class prerequisite routine7f5150.
The complete original branch/comparison/grouping instructions execute. C2DA
accessors, allocation/free, CResRef, feat-array Contains, cached BAB, class-slot
lookup and strcmp are explicit providers over supplied raw fixtures. This is
not a table-loader, derived-stat-cache, level-up, GUI or server acceptance test.
"""
import importlib.util,itertools,json,random,struct
from pathlib import Path
spec=importlib.util.spec_from_file_location('image',Path(__file__).with_name('inspect-native-intratile-coordinator.py'))
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
actor,rules,classes,ranks,primary,bonus=[m.heap+n for n in [0x1000,0x10000,0x20000,0x30000,0x31000,0x32000]]
def byte(a,v):u.mem_write(a,bytes([v&255]))
def word(a,v):u.mem_write(a,struct.pack('<H',v&65535))
def cstring(a):return bytes(u.mem_read(a,500)).split(b'\0')[0].decode('cp1252')
def alloc(n):
 global bump
 p=m.heap+bump;bump+=max(32,n);return p
def string(dest,text):
 raw=text.encode('cp1252');ptr=alloc(len(raw)+1);u.mem_write(ptr,raw+b'\0');m.wq(dest,ptr);m.wi(dest+8,len(raw));m.wi(dest+12,len(raw)+1)
def hook(u,a,n,_):
 if a==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(r)for r in[UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
 if a==0x140c10410:m.finish(u.reg_read(UC_X86_REG_RAX)) # Runtime cookie check preserves the pending return value.
 elif a in [0x14018ded0,0x140c10370,0x1401a65a0,0x1401a9b10]:m.finish()
 elif a==0x1401a62b0:m.wi(x+0x50,len(case['requirements']));m.finish(x)
 elif a==0x1401a73a0:m.finish(1)
 elif a==0x140c10368:m.finish(alloc(x))
 elif a==0x1401a6a80:m.finish(['ReqType','ReqParam1','ReqParam2'].index(cstring(m.q(y))))
 elif a in [0x1401a69e0,0x1401a7120]:
  entry=case['requirements'][y];value=entry[['ReqType','ReqParam1','ReqParam2'][z]]
  if a==0x1401a69e0:string(w,value);m.finish(1)
  else:m.wi(w,int(value));m.finish(1)
 elif a==0x140296910:
  ptr=m.q(x);count=m.si(x+8);owned=struct.unpack('<'+'H'*count,bytes(u.mem_read(ptr,count*2)))if count else []
  m.finish(int((y&65535)in owned))
 elif a==0x1407f0900:m.finish(case['source']['bab']&255)
 elif a==0x1407f0f60:m.finish(case['source']['classes'][y]['id']&255)
 elif a==0x140c799d0:m.finish((cstring(x)>cstring(y))-(cstring(x)<cstring(y)))
 elif not 0x1407f5150<=a<=0x1407f5aa4:raise AssertionError(f'Unmapped original Class prerequisite dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(c):
 global case,bump
 case=c;bump=0x40000;u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));m.wq(0x1412df8f8,rules);m.wq(rules+0x110,classes);byte(rules+0x107,len(c['source']['ranks']))
 m.wi(classes+0x30,8 if c['requirements']else 0);m.wq(classes+0x28,m.heap+0x35000);u.mem_write(m.heap+0x35000,b'fixture\0')
 s=c['source'];word(actor+0x50,s['race']);m.wq(actor+0xd8,ranks)
 for at,value in enumerate(s['ranks']):byte(ranks+at,value)
 for offset,ptr,key in[(0x118,primary,'feats'),(0x128,bonus,'bonusFeats')]:
  m.wq(actor+offset,ptr);m.wi(actor+offset+8,len(s[key]))
  for at,value in enumerate(s[key]):word(ptr+at*2,value)
 for at,value in enumerate(s['saves']):byte(actor+[0x9c,0x9e,0x9d][at],value)
 byte(actor+0x69,len(s['classes']))
 for at,value in enumerate(s['classes']):
  id=value['id']&255;byte(actor+at*0x150+0x295,id);byte(actor+at*0x150+0x296,value['level']);m.wi(classes+id*0x530+0x4d8,value['caster']);m.wi(classes+id*0x530+0x500,value['arcane'])
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8],[actor,0,0]):u.reg_write(reg,value)
 u.emu_start(0x1407f5150,m.stop,count=1000000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(input=c,result=u.reg_read(UC_X86_REG_RAX)&0xffffffff)
if __name__=='__main__':
 out=m.root/'backups/animations/native-creation-class-prerequisite-observations-v2.json';assert not out.exists(),'Preserve previous evidence'
 rng=random.Random(79351);rows=[]
 types=['SKILL','FEAT','RACE','FEATOR','BAB','SPELL','ARCSPELL','CLASSNOT','CLASSOR','SAVE','UNKNOWN','VAR','race']
 for index in range(600):
  source=dict(race=rng.choice([0,6,65535]),ranks=[rng.choice([0,1,5,127,255])for _ in range(4)],feats=rng.choice([[],[1],[65535]]),bonusFeats=rng.choice([[],[2],[65535]]),saves=[rng.choice([0,1,3,127,255])for _ in range(3)],bab=rng.choice([0,1,5,255]),classes=rng.choice([[],[dict(id=4,level=1,caster=0,arcane=0)],[dict(id=10,level=3,caster=1,arcane=1)],[dict(id=2,level=2,caster=1,arcane=0),dict(id=4,level=1,caster=0,arcane=0)]]))
  requirements=[]
  for _ in range(rng.randrange(0,7)):
   kind=rng.choice(types);a=rng.choice([0,1,2,3,4,6,10,65535]);b=rng.choice([-1,0,1,3,128])
   requirements.append(dict(ReqType=kind,ReqParam1=a,ReqParam2=b))
  rows.append(run(dict(source=source,requirements=requirements)))
 out.write_text(json.dumps(dict(binarySha256=m.digest,scope=__doc__,procedure='0x1407f5150',rows=rows),indent=2));print(json.dumps(dict(output=str(out),cases=len(rows))))

