"""Unchanged original initial skill-budget, rank-up/down, class useability/
class-skill lookup, rank/cache setter and preference allocator instructions.
Reuses original ability/vital instructions. 2DA services, allocation and object
lifetimes are explicit providers; raw table fixtures do not prove parsing,
the full Skills GUI, save/upload or separate level-up owner semantics.
"""
import copy,importlib.util,json,random,struct
from pathlib import Path
spec=importlib.util.spec_from_file_location('vitals',Path(__file__).with_name('inspect-native-creation-vitals.py'))
v=importlib.util.module_from_spec(spec);spec.loader.exec_module(v)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=v.u;m=v.m
extra=[(0x1407ec0c0,0x1407ec22e),(0x1407f7a00,0x1407f7b75),(0x1407ee3e0,0x1407ee4fe),(0x14029a250,0x14029a2f4),(0x14029a300,0x14029a3b9),(0x1407fa8b0,0x1407faa0b),(0x1407f10a0,0x1407f1107),(0x1407fadc0,0x1407faf39),(0x1407eb300,0x1407eb62c)]
providers=[0x14018dea0,0x1401a62b0,0x1401a7010,0x1401a73a0,0x140c10324,0x140c10368,0x140c10370,0x140c10410,0x140115890,m.stop+0x10]
v.ranges +=[(a,b+1)for a,b in extra]+[(a,a+1)for a in providers]
skills,ranks,values,class_entries=[m.heap+n for n in[0x60000,0x64000,0x66000,0x68000]]
def cstring(a):return bytes(u.mem_read(a,128)).split(b'\0')[0].decode('cp1252')if a else''
def string(dest,text):
 global bump
 raw=text.encode('cp1252');p=m.heap+bump;bump+=max(32,len(raw)+1);u.mem_write(p,raw+b'\0');m.wq(dest,p);m.wi(dest+8,len(raw));m.wi(dest+12,len(raw)+1)
def hook(u,a,n,_):
 global bump
 x,y,z,w=[u.reg_read(r)for r in[UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
 if a in[0x140c10324,0x140c10368]:p=m.heap+bump;bump+=(max(32,x)+15)&~15;m.finish(p)
 elif a in[0x140c10370,0x140c10410,0x140115890]:m.finish()
 elif a==0x14018dea0:u.mem_write(x,cstring(m.q(y)).encode('cp1252')[:16].ljust(17,b'\0'));m.finish(x)
 elif a==0x1401a62b0:m.wq(x,m.heap+0x70000);m.wi(x+0x50,len(current['preferences']));m.finish(x)
 elif a==0x1401a73a0:m.finish(1)
 elif a==0x1401a7010:
  if y<len(current['preferences']):m.wi(w,current['preferences'][y]);m.finish(1)
  else:m.wi(w,0);m.finish(0)
u.hook_add(UC_HOOK_CODE,hook)
def state():return dict(ranks=list(u.mem_read(ranks,8)),values=[v.signed(n)for n in u.mem_read(values,8)],points=v.signed(int.from_bytes(u.mem_read(v.actor+0x10e,2),'little'),16))
def run(c):
 global current,bump
 current=c;bump=0x80000;v.run(c['vital']);m.wq(v.rules+0x120,skills);v.byte(v.rules+0x107,8);m.wq(v.actor+0xd8,ranks);m.wq(v.actor+0xd0,values)
 m.wq(m.heap+0x70000,m.stop+0x10);cls=v.classes+c['vital']['source']['classId']*0x530
 v.byte(cls+0x75,c['classPoints']);m.wq(cls+0x2a0,class_entries);v.word(cls+0x2a8,len(c['classSkills']))
 for at,entry in enumerate(c['classSkills']):v.word(class_entries+at*8,entry['SkillIndex']);m.wi(class_entries+at*8+4,entry['ClassSkill'])
 m.wi(v.races+0x60,c['ability']);v.word(v.races+0x4c,c['extra']);v.word(v.races+0x50,c['multiplier'])
 for at,row in enumerate(c['skills']):
  m.wi(skills+at*0x38+0x20,row['ability']);m.wi(skills+at*0x38+0x28,row['Untrained']);m.wi(skills+at*0x38+0x30,row['AllClassesCanUse'])
 v.word(v.actor+0x10e,c.get('unspent',0));v.call(0x1407ec0c0,[v.actor]);budget=state()['points']
 u.mem_write(ranks,bytes(c['ranks']));v.word(v.actor+0x10e,c['points']);v.call(0x1407fadc0,[v.actor]);initial=state();results=[]
 for op in c['operations']:
  if op['kind']=='up':v.call(0x1407f7a00,[v.actor,op['id']])
  elif op['kind']=='down':v.call(0x1407ee3e0,[v.actor,op['id'],op['baseline']])
  else:
   s=m.heap+0x72000;string(s,'pref')
   try:v.call(0x1407eb300,[v.actor,s])
   except Exception:
    print(json.dumps(dict(operation=op,rip=hex(u.reg_read(UC_X86_REG_RIP)),rax=hex(u.reg_read(UC_X86_REG_RAX)),rsp=hex(u.reg_read(UC_X86_REG_RSP)),state=state())));raise
  results.append(dict(operation=op,state=state()))
 return dict(case=c,budget=budget,scores=list(u.mem_read(v.actor+0x70,6)),initial=initial,results=results)
if __name__=='__main__':
 out=m.root/'backups/animations/native-creation-skills-observations-v1.json';assert not out.exists(),'Preserve previous evidence'
 rng=random.Random(92620);old=json.loads((m.root/'backups/animations/native-creation-vitals-observations-v1.json').read_text());cases=[]
 for at in range(144):
  vital=copy.deepcopy(old['rows'][at%48]['case']);vital['operations']=[];vital['source']['level']=1;vital['source']['classId']=0;vital['tables']['classes']['orderedRows'][0]['SpellCaster']=0
  settings={'CHARGEN_ABILITY_NEUTRAL_VALUE':10,'CHARGEN_ABILITY_MODIFIER_INCREMENT':2,'CHARGEN_SKILL_MAX_LEVEL_1_BONUS':[3,5,8,-1,260][at%5]};vital['settings']=settings;vital['tables']['ruleset']['orderedRows']=[dict(Label=k,Value=str(n))for k,n in settings.items()]
  class_skills=[dict(SkillIndex=i,ClassSkill=int(i%3==0))for i in range(8)if i%2==0];rows=[dict(ability=i%6,Untrained=int(i%2==0),AllClassesCanUse=int(i%3!=1))for i in range(8)]
  legal=at%3==0;ranks0=[0]*8 if legal else[rng.choice([0,1,2,4,127,128,255])for i in range(8)];points0=rng.choice([0,1,2,3,17,32])if legal else rng.choice([-32768,-1,0,1,2,32767])
  ops=[op for i in range(8)for op in[dict(kind='up',id=i),dict(kind='down',id=i,baseline=0 if legal else rng.choice([0,1,255]))]]
  if legal and at%5<3:ops.append(dict(kind='recommend'))
  cases.append(dict(vital=vital,ability=at%7,classPoints=[2,4,8,260][at%4],extra=[0,1,2,65535][at%4],multiplier=[4,1,3,32767][at%4],skills=rows,classSkills=class_skills,ranks=ranks0,points=points0,preferences=[2,0,7,4,1,6],operations=ops))
 rows=[run(c)for c in cases];out.write_text(json.dumps(dict(binarySha256=m.digest,scope=__doc__,procedures=[hex(a)for a,b in extra],rows=rows),indent=2));print(json.dumps(dict(output=str(out),cases=len(rows),operations=sum(len(r['results'])for r in rows))))
