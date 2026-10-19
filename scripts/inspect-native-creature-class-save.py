"""Read-only complete SaveClassInfo original-code oracle. Native owner,
slot accessors, per-day reads and history skill accessors execute. CResGFF
and CExoString writes are captured; skill-rank/remaining-feat-use owners are
independently verified lower boundaries, not claims about complete export.
"""
import importlib,sys,json,copy,random
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
stats=m.heap+0x2000
actor,rules,gff,root,defs=[m.heap+0x21000+i*0x1000 for i in range(5)]
allocation=m.heap+0x30000
ranges=[(0x140413880,0x140413b3b),(0x140413b40,0x1404145d9)]
for name in ['copy-save-slot-helper-'+str(i) for i in range(4)]+['copy-save-per-day-helper']:
 d=json.loads((m.root/'backups/animations'/('rea-'+name+'.json')).read_text())['structuredContent']['normalized_result']
 ranges.extend((int(r['start'],16),int(r['end'],16)+1)for r in d['procedure']['body']['ranges'])
# Slot ID and per-day owner have their independently checked complete ranges.
ranges.append((0x140404aa0,0x140404b4a))
def alloc(size):
 global cursor
 p=allocation+cursor;cursor+=(size+15)&~15
 assert cursor<0xb0000
 return p
def string(ptr):
 b=bytearray()
 while ptr:
  v=u.mem_read(ptr,1)[0]
  if not v:break
  b.append(v);ptr+=1
 return b.decode('ascii')
def byte(p,v):u.mem_write(p,bytes([v&255]))
def word(p,v):u.mem_write(p,(v&65535).to_bytes(2,'little'))
def exostring(p,s):
 b=s.encode('ascii');ptr=alloc(len(b)+1);u.mem_write(ptr,b+b'\0');m.wq(p,ptr);m.wi(p+8,len(b));m.wi(p+12,len(b)+1)
def arr(p,values,width):
 a=alloc(max(1,len(values))*width);m.wq(p,a);m.wi(p+8,len(values));m.wi(p+12,len(values))
 for i,v in enumerate(values):u.mem_write(a+i*width,(v&((1<<(width*8))-1)).to_bytes(width,'little'))
def node(t):
 n=dict(fields={},type=t);nodes.append(n);return len(nodes)-1
types={0x1401a2a80:0,0x1401a36f0:2,0x1401a3590:3,0x1401a34f0:5,0x1401a2d30:10}
def hook(u,a,n,_):
 global wrapped
 if a==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(r)for r in[UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
 if a==0x14019f1e0:
  target=nodes[m.si(z)];label=string(w);entries=[];target['fields'][label]=dict(type=15,value=entries);lists.append(entries);m.wi(y,len(lists)-1);m.finish(1);return
 if a==0x14019f2b0:
  entries=lists[m.si(z)];idx=node(w&0xffffffff);entries.append(nodes[idx]);m.wi(y,idx)
  # Stop the verified BYTE known-list nonprogress without hanging the runner.
  if len(entries)>256 and c.get('wrapKnown'):wrapped=True;u.emu_stop();return
  m.finish(1);return
 if a in types:
  t=types[a];v=z
  if t==0:v&=255
  elif t==2:v&=65535
  elif t==3:v=(v&65535);v=v-65536 if v>32767 else v
  elif t==5:v=(v&0xffffffff);v=v-0x100000000 if v>0x7fffffff else v
  else:v=string(m.q(z))[:m.si(z+8)]
  nodes[m.si(y)]['fields'][string(w)]=dict(type=t,value=v);m.finish(1);return
 if a==0x14016afb0:exostring(x,string(z)+str(w&0xffffffff));m.finish(x);return
 if a==0x140406a40:
  assert z==0 and (w&0xffffffff)==1
  calls.append(['skill',y&255,0,1]);m.finish(c['skills'][y&255]);return
 if a==0x1404012f0:calls.append(['feat',y&65535]);m.finish(c['uses'].get(str(y&65535),100));return
 if a==0x140115890:warnings.append(string(z));m.finish();return
 if a==0x140c10370:m.finish();return
 if a==0x140c10410:m.finish(u.reg_read(UC_X86_REG_RAX));return
 if not any(lo<=a<hi for lo,hi in ranges):raise RuntimeError(f'Uncaptured class-save dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,cursor,nodes,lists,calls,warnings,wrapped
 c=case;cursor=0;nodes=[];lists=[];calls=[];warnings=[];wrapped=False
 u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));m.wq(0x1412df8f8,rules);m.wq(rules+0x110,defs);byte(rules+0x107,len(c['skills']))
 m.wq(stats+0x30,actor);m.wq(actor+0xad0,stats);byte(stats+0xd8,len(c['classes']));m.wi(stats+0xb0,c['isPC']);word(stats+0xdc6,c['skillPoints'])
 for i,cls in enumerate(c['classes']):
  info=stats+0xe0+i*0x188;d=defs+cls['Class']*0x530
  for off,key in [(0x4ec,'MemorizesSpells'),(0x4f4,'PickDomains'),(0x4f8,'PickSchool'),(0x500,'Arcane')]:m.wi(d+off,cls['definition'][key])
  byte(d+0x524,cls['definition']['MinAssociateLevel'])
  for off,key in [(0x25c,'Class'),(0x25d,'ClassLevel'),(0x25f,'School'),(0x260,'Domain1'),(0x261,'Domain2')]:byte(stats+i*0x188+off,cls[key])
  for level in range(10):
   arr(info+level*16,cls['known'][level],4);pool=cls['memorized'][level];ptrs=[]
   for s in pool:
    if s is None:ptrs.append(0);continue
    ptr=alloc(16);ptrs.append(ptr)
    for off,key in [(0,'id'),(4,'ready'),(8,'metamagic'),(12,'domain')]:m.wi(ptr+off,s[key])
   arr(info+0xa0+level*16,ptrs,8);byte(stats+i*0x188+0x248+level,cls['perDay'][level])
 historyPtrs=[]
 for h in c['histories']:
  ptr=alloc(0x170);historyPtrs.append(ptr)
  for off,key in [(0x15a,'LvlStatAbility'),(0x15b,'LvlStatHitDie'),(0x15c,'LvlStatClass'),(0x160,'EpicLevel')]:byte(ptr+off,h[key])
  word(ptr+0x158,h['SkillPoints']);arr(ptr+0x140,h['feats'],2);word(ptr+0x148,len(h['feats']))
  skills=alloc(max(1,len(c['skills'])));m.wq(ptr+0x150,skills)
  for i,v in enumerate(h['skills']):byte(skills+i,v)
  for level in range(10):arr(ptr+level*16,h['KnownList'][level],4);arr(ptr+0xa0+level*16,h['KnownRemoveList'][level],4)
 arr(stats+0x38,historyPtrs,8);arr(stats,c['feats'],2)
 for off,name in [(0xe34,'Familiar'),(0xe30,'Companion')]:m.wi(stats+off,c[name]['type']);exostring(stats+(0xe48 if name=='Familiar'else 0xe38),c[name]['name'])
 abilities=alloc(16);m.wq(stats+0xd88,abilities);ptr=alloc(max(1,len(c['abilities']))*12);m.wq(abilities,ptr);m.wi(abilities+8,len(c['abilities']))
 for i,v in enumerate(c['abilities']):m.wi(ptr+i*12,v['id']);m.wi(ptr+i*12+4,v['remaining']);byte(ptr+i*12+8,v['casterLevel'])
 node(0xffffffff);m.wi(root,0);rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 for reg,v in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8],[stats,gff,root]):u.reg_write(reg,v)
 try:u.emu_start(0x140413880,m.stop,count=2000000)
 except Exception:print(json.dumps(dict(name=c['name'],rip=hex(u.reg_read(UC_X86_REG_RIP)),calls=calls[-5:])));raise
 assert wrapped or u.reg_read(UC_X86_REG_RIP)==m.stop,(c['name'],hex(u.reg_read(UC_X86_REG_RIP)))
 return dict(case=c,output=None if wrapped else nodes[0],calls=calls,warnings=warnings,wrapped=wrapped)
def cls(id=0,level=1):return dict(Class=id,ClassLevel=level,School=0,Domain1=0,Domain2=1,definition=dict(MemorizesSpells=1,PickDomains=0,PickSchool=0,Arcane=0,MinAssociateLevel=255),known=[[]for _ in range(10)],memorized=[[]for _ in range(10)],perDay=[0]*10)
def history(id=0):return dict(LvlStatAbility=6,LvlStatHitDie=8,LvlStatClass=id,EpicLevel=0,SkillPoints=3,skills=[0,1,255],feats=[42,1],KnownList=[[]for _ in range(10)],KnownRemoveList=[[]for _ in range(10)])
def base(name):return dict(name=name,classes=[cls()],histories=[],isPC=0,skillPoints=8,skills=[0,3,255],feats=[42,1,99],uses={'42':100,'1':0,'99':257},abilities=[],Familiar=dict(type=-1,name='Test Familiar'),Companion=dict(type=3,name='Test Companion'))
cases=[base('empty-npc')]
c=base('all-fields');c['classes']=[cls(0,2),cls(1,1)];c['isPC']=1;c['histories']=[history()for _ in range(3)];c['histories'][0]['LvlStatAbility']=255;c['histories'][1]['LvlStatAbility']=2
c['histories'][1]['KnownList'][1]=[0x12345678,3];c['histories'][1]['KnownRemoveList'][2]=[65537]
for i,cl in enumerate(c['classes']):
 cl['definition'].update(MemorizesSpells=i,PickSchool=1,PickDomains=1,Arcane=i,MinAssociateLevel=1);cl['School']=5;cl['known'][0]=[0x12345678,0,65537];cl['perDay']=list(range(10));cl['memorized'][2]=[None,dict(id=77,ready=258,metamagic=257,domain=256),dict(id=0xffffffff,ready=1,metamagic=1,domain=1),dict(id=0,ready=-1,metamagic=0,domain=0)]
c['abilities']=[dict(id=0x12345678,remaining=258,casterLevel=257),dict(id=9,remaining=-1,casterLevel=0)];cases.append(c)
for n in [0,1,255,256,257,32768]:
 c=base('known-count-'+str(n));c['classes'][0]['known'][0]=list(range(n));c['wrapKnown']=n==256 or n==257;cases.append(c)
for n in [0,1,255,256,257]:
 c=base('memorized-count-'+str(n));c['classes'][0]['memorized'][4]=[None]*n
 if n:c['classes'][0]['memorized'][4][-1]=dict(id=55,ready=1,metamagic=0,domain=0)
 cases.append(c)
c=base('npc-history-more-than-one');c['classes'][0]['ClassLevel']=2;c['histories']=[history(),history()];cases.append(c)
c=base('no-feats-skills-abilities');c.update(feats=[],skills=[]);cases.append(c)
c=base('pc-zero-level');c['classes']=[];c['isPC']=1;cases.append(c)
c=base('eight-inline-class-records');c['classes']=[cls(0,0)for _ in range(8)]
for cl in c['classes']:cl['definition'].update(PickSchool=1,PickDomains=1)
c['classes'][7]['memorized'][0]=[dict(id=1,ready=1,metamagic=255,domain=0)];cases.append(c)
rng=random.Random(413880)
for i in range(80):
 c=base('random-'+str(i));cl=c['classes'][0];cl['definition'].update(MemorizesSpells=rng.choice([0,1,-1]),PickSchool=rng.randrange(2),PickDomains=rng.randrange(2),Arcane=rng.choice([0,1,-1]),MinAssociateLevel=rng.choice([-1,0,1,127,128,255]));cl['School']=rng.randrange(256)
 for level in range(10):
  cl['known'][level]=[rng.randrange(0x100000000)for _ in range(rng.randrange(4))];cl['perDay'][level]=rng.randrange(256)
  cl['memorized'][level]=[None if rng.randrange(4)==0 else dict(id=rng.choice([0,0xffffffff,rng.randrange(0x100000000)]),ready=rng.choice([0,1,2,-1,256]),metamagic=rng.randrange(512),domain=rng.choice([0,1,-1,256]))for _ in range(rng.randrange(6))]
 c['abilities']=[dict(id=rng.randrange(0x100000000),remaining=rng.choice([0,1,-1,256,257]),casterLevel=rng.randrange(256))for _ in range(rng.randrange(4))];cases.append(c)
observations=[run(c)for c in cases]
out=m.root/'backups/animations/native-creature-class-save-observations.json';out.write_text(json.dumps(dict(target=m.digest,cases=observations),indent=2)+'\n')
print(json.dumps(dict(cases=len(cases),nativeWraps=sum(x['wrapped']for x in observations),output=str(out))))
