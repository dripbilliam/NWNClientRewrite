"""Execute original FeatRequirementsMet7ee690 with complete owned/selected-feat,
class-grant, cached-BAB, skill-usability and level helpers. Fixtures set
MINSPELLLVL=0 and a non-sentinel cached BAB, so spell-capacity and BAB-rebuild
branches are explicitly outside this corpus. No helper is substituted, no live
process/GPU/server is used, and decoded fixtures do not prove 2DA parsing or UI.
"""
import importlib.util,json,random,struct
from pathlib import Path
spec=importlib.util.spec_from_file_location('image',Path(__file__).with_name('inspect-native-intratile-coordinator.py'))
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
actor,rules,native_classes,feats,skills,ranks,primary,secondary,selected,selected_ids=[m.heap+n for n in [0x1000,0x10000,0x20000,0x40000,0x50000,0x51000,0x52000,0x53000,0x54000,0x55000]]
ranges=[(0x1407ee690,0x1407eec74),(0x140299a40,0x140299a85),(0x1407ee620,0x1407ee686),(0x1407ee5b0,0x1407ee616),(0x1407f0900,0x1407f0ad5),(0x1407f0c30,0x1407f0d44),(0x14029a300,0x14029a3ba),(0x140296910,0x14029699a),(0x1407f10a0,0x1407f1108),(0x1402a3bd0,0x1402a3bf3),(0x1407f5d70,0x1407f5e11)]
def byte(a,v):u.mem_write(a,bytes([v&255]))
def word(a,v):u.mem_write(a,struct.pack('<H',v&65535))
def hook(u,a,n,_):
 if a==m.stop:u.emu_stop();return
 if not any(lo<=a<hi for lo,hi in ranges):raise AssertionError(f'Uncaptured original feat-requirement dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def array(base,offset,ptr,values):
 m.wq(base+offset,ptr);m.wi(base+offset+8,len(values))
 for at,value in enumerate(values):word(ptr+2*at,value)
def run(c):
 u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));m.wq(0x1412df8f8,rules)
 m.wq(rules+0x110,native_classes);m.wq(rules+0xd8,feats);word(rules+0x100,16);m.wq(rules+0x120,skills);byte(rules+0x107,len(c['skills']))
 for index in range(16):m.wi(feats+index*0x74+0x68,1)
 f=feats+c['featId']*0x74;row=c['feat']
 for key,offset in dict(MINATTACKBONUS=0x34,MINSTR=0x35,MINDEX=0x36,MININT=0x37,MINWIS=0x38,MINCON=0x39,MINCHA=0x3a,MINSPELLLVL=0x3b,MinLevel=0x59,MaxLevel=0x5a,MinLevelClass=0x5b,MinFortSave=0x5c).items():byte(f+offset,row.get(key,0))
 for key,offset in dict(PREREQFEAT1=0x3c,PREREQFEAT2=0x3e,REQSKILL=0x4a,ReqSkillMinRanks=0x4c,REQSKILL2=0x4e,ReqSkillMinRanks2=0x50).items():word(f+offset,row.get(key,0))
 for at,value in enumerate(row['OrReqFeats']):word(f+0x40+at*2,value)
 m.wi(f+0x6c,row['PreReqEpic']);byte(actor+0x69,len(c['classes']));byte(actor+0x6a,c['current']);byte(actor+0x98,c['fortitude']);byte(actor+0x9b,c['baseAttack']);u.mem_write(actor+0x70,bytes(v&255 for v in c['scores']))
 for at,cl in enumerate(c['classes']):
  cp=native_classes+cl['id']*0x530;byte(actor+0x295+at*0x150,cl['id']);byte(actor+0x296+at*0x150,cl['level'])
  skill_list=m.heap+0x60000+at*0x1000;feat_list=m.heap+0x68000+at*0x1000;m.wq(cp+0x2a0,skill_list);word(cp+0x2a8,len(cl['skills']));m.wq(cp+0x2b0,feat_list);word(cp+0x2b8,len(cl['feats']))
  for j,id in enumerate(cl['skills']):word(skill_list+j*8,id)
  for j,entry in enumerate(cl['feats']):word(feat_list+j*16,entry['id']);byte(feat_list+j*16+2,entry['level'])
 m.wq(actor+0xd8,ranks)
 for at,sk in enumerate(c['skills']):byte(ranks+at,sk['rank']);m.wi(skills+at*0x38+0x28,sk['Untrained']);m.wi(skills+at*0x38+0x30,sk['AllClassesCanUse'])
 array(actor,0x118,primary,c['owned']);array(actor,0x128,secondary,c['secondary']);array(selected,0,selected_ids,c['selected'])
 owned_before=bytes(u.mem_read(primary,2*len(c['owned'])));rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8],[actor,c['featId'],selected]):u.reg_write(reg,value)
 u.emu_start(0x1407ee690,m.stop,count=100000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 assert bytes(u.mem_read(primary,2*len(c['owned'])))==owned_before,'Original Contains sentinel must restore the owned array'
 return dict(case=c,accepted=bool(u.reg_read(UC_X86_REG_RAX)&0xff))
if __name__=='__main__':
 rng=random.Random(27110);cases=[]
 for index in range(360):
  mode=index%12;count=1+index%3;classes=[dict(id=at*2+1,level=[1,2,3,20,127,255][(index+at)%6],skills=[j for j in range(6)if rng.randrange(2)],feats=[])for at in range(count)]
  row=dict(MINSPELLLVL=0,MinLevelClass=255,PREREQFEAT1=65535,PREREQFEAT2=65535,REQSKILL=65535,REQSKILL2=65535,ReqSkillMinRanks=0,ReqSkillMinRanks2=0,PreReqEpic=0,OrReqFeats=[65535]*5)
  c=dict(featId=2,feat=row,current=index%count,classes=classes,scores=[rng.choice([3,8,10,16,127,128,255])for _ in range(6)],baseAttack=rng.choice([0,1,3,20,127,128,254]),fortitude=rng.choice([0,1,3,20,127,128,255]),skills=[dict(rank=rng.choice([0,1,2,3,127,128,255]),Untrained=rng.randrange(2),AllClassesCanUse=rng.randrange(2))for _ in range(6)],owned=[j for j in range(32)if rng.randrange(2)],secondary=[1001,41],selected=[40,42])
  if mode==0:classes[c['current']]['feats']=[dict(id=2,level=[0,1,2,255][index//12%4]),dict(id=2,level=0)]
  if mode==1:row[['MINSTR','MINDEX','MINCON','MININT','MINWIS','MINCHA'][index//12%6]]=rng.choice([0,3,10,18,127,128,255,256])
  if mode==2:row['MINATTACKBONUS']=rng.choice([0,1,3,20,127,255,256])
  if mode==3:row['MinFortSave']=rng.choice([0,1,3,20,127,255,256])
  if mode==4:row['MinLevel']=rng.choice([0,1,3,20,127,255]);row['MinLevelClass']=rng.choice([255,1,3,7,21])
  if mode==5:row['MaxLevel']=rng.choice([0,1,3,20,127,255])
  if mode==6:row['PREREQFEAT1']=rng.choice([65535,0,8,20,40,41]);row['PREREQFEAT2']=rng.choice([65535,1,9,21,42])
  if mode==7:row['OrReqFeats']=[rng.choice([65535,3,14,40,41,42])for _ in range(5)]
  if mode in[8,9]:row['REQSKILL' if mode==8 else 'REQSKILL2']=rng.choice([0,1,3,5,6,65535]);row['ReqSkillMinRanks' if mode==8 else 'ReqSkillMinRanks2']=rng.choice([0,1,2,3,127,128,255,256])
  if mode==10:
   row['PreReqEpic']=1
   if index//12%3==0:c['owned'].append(1001)
   elif index//12%3==1:c['selected'].append(1001)
  if mode==11:row.update(MINSTR=10,MinLevel=3,PREREQFEAT1=8,REQSKILL=1,ReqSkillMinRanks=1)
  cases.append(c)
 out=m.root/'backups/animations/native-creation-feat-requirements-observations-v1.json';assert not out.exists(),'Preserve prior evidence'
 results=[run(c)for c in cases];out.write_text(json.dumps(dict(target=m.digest,scope=__doc__,procedures=[hex(lo)for lo,_ in ranges],rows=results),indent=2))
 print(json.dumps(dict(output=str(out),cases=len(results),accepted=sum(row['accepted']for row in results),boundaries=[],publicConnections=0,gpu=False)))
