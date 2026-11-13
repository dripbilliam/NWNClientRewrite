"""Execute complete original CanChooseFeat7ed040 and its reached prerequisite,
normal/bonus classification, level and ownership helpers. Only malloc/memset/free
are explicit ABI service boundaries. Valid decoded feats, MINSPELL0 and cached
BAB are fixture scope; this is not original 2DA parsing, UI or server acceptance.
"""
import importlib.util,json,random
from pathlib import Path
spec=importlib.util.spec_from_file_location('prerequisites',Path(__file__).with_name('inspect-native-creation-feat-requirements.py'))
q=importlib.util.module_from_spec(spec);spec.loader.exec_module(q)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
q.ranges += [(0x1407ed040,0x1407ed5cc),(0x14029a190,0x14029a244),(0x14029a010,0x14029a05a)]
procedures=[hex(lo)for lo,_ in q.ranges]
services={0x140c10368:'malloc',0x140c42060:'memset',0x140c10370:'free'}
q.ranges += [(address,address+1)for address in services]
original_start=q.u.emu_start
active=None
def memory(u,address,size,_):
 if address not in services:return
 x,y,z=[u.reg_read(reg)for reg in[UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8]]
 if services[address]=='malloc':
  assert x<=1024;ptr=q.m.heap+0x80000;u.mem_write(ptr,bytes([0xa5])*x);q.m.finish(ptr)
 elif services[address]=='memset':
  assert z<=1024;u.mem_write(x,bytes([y&255])*z);q.m.finish(x)
 else:q.m.finish()
q.u.hook_add(UC_HOOK_CODE,memory)
def start(address,until,*args,**kwargs):
 c=active
 for definition in c['definitions']:q.m.wi(q.feats+definition['id']*0x74+0x28,definition['AllClassesCanUse'])
 for cls in c['classes']:
  ptr=q.m.q(q.native_classes+cls['id']*0x530+0x2b0)
  for index,entry in enumerate(cls['feats']):q.byte(ptr+index*16+3,{0:1,1:3,2:2}.get(entry['List']&255,0))
 q.u.reg_write(UC_X86_REG_R8,c['normal']&255);q.u.reg_write(UC_X86_REG_R9,c['bonus']&255);q.m.wq(q.u.reg_read(UC_X86_REG_RSP)+0x28,q.selected)
 return original_start(0x1407ed040,until,*args,**kwargs)
q.u.emu_start=start
if __name__=='__main__':
 rng=random.Random(91260);cases=[]
 out=q.m.root/'backups/animations/native-creation-feat-choice-observations-v1.json';assert not out.exists(),'Preserve prior evidence'
 for index in range(480):
  classes=[]
  for at in range(1+index%3):
   records=[dict(id=id,level=255,List=rng.choice([-1,0,1,2,3,4,256,257,258]))for id in range(16)if rng.randrange(2)]
   classes.append(dict(id=at*2+1,level=1+index%4,skills=[],feats=records))
  feat=dict(MINSPELLLVL=0,MinLevelClass=255,PREREQFEAT1=65535,PREREQFEAT2=65535,REQSKILL=65535,REQSKILL2=65535,ReqSkillMinRanks=0,ReqSkillMinRanks2=0,PreReqEpic=0,OrReqFeats=[65535]*5)
  chosen=[rng.choice([0,1,3,4,5,6,7,8,9,10,11,12,13,14,15])for _ in range(index%8)]
  if index%17==0:chosen.append(2)
  owned=[id for id in range(3,20)if rng.randrange(2)]
  if index%19==0:owned.append(2)
  if index%23==0:feat['MINSTR']=11
  if index%29==0:classes[index%len(classes)]['feats'].insert(0,dict(id=2,level=8,List=1))
  cases.append(dict(featId=2,feat=feat,current=index%len(classes),classes=classes,scores=[10]*6,baseAttack=0,fortitude=0,skills=[],owned=owned,secondary=[2],selected=chosen,normal=[0,1,2,3,127,255,256,-1][index%8],bonus=[0,1,2,3,127,255,256,-1][index//8%8],definitions=[dict(id=id,AllClassesCanUse=rng.choice([0,1,-1]))for id in range(16)]))
 results=[]
 for case in cases:
  active=case;results.append(q.run(case))
 out.write_text(json.dumps(dict(target=q.m.digest,scope=__doc__,procedures=procedures,boundaries=[dict(address=hex(a),service=s)for a,s in services.items()],rows=results),indent=2))
 print(json.dumps(dict(output=str(out),cases=len(results),accepted=sum(row['accepted']for row in results),boundaries=list(services.values()),publicConnections=0,gpu=False)))
