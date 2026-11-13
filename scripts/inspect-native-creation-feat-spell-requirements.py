"""Execute original FeatRequirementsMet7ee690 with positive MINSPELLLVL for
non-memorizing classes, including complete GetSpellsKnownPerLevel299e70,
GetSpellGain299e40, racial ability and class gain helpers. Class levels1..40,
decoded valid rule/stat storage and cached BAB are explicit. The memorizing
7f6b20 branch and original table parsing remain outside this corpus. No reached
helper is substituted; no live process, GPU or server is used.
"""
import copy,importlib.util,json,random
from pathlib import Path
spec=importlib.util.spec_from_file_location('prerequisites',Path(__file__).with_name('inspect-native-creation-feat-requirements.py'))
q=importlib.util.module_from_spec(spec);spec.loader.exec_module(q)
q.ranges += [(0x140299e70,0x140299fe8),(0x140299e40,0x140299e68),(0x1402a1460,0x1402a149d),(0x140299710,0x14029978e),(0x1407f0f60,0x1407f0fc6)]
original_start=q.u.emu_start
active=None
def start(address,until,*args,**kwargs):
 c=active;race=q.m.heap+0x70000;q.m.wq(q.rules+0x118,race);q.word(q.actor+0x50,0)
 for offset,value in zip([0x18,0x19,0x1d,0x1a,0x1c,0x1b],c['raceAdjust']):q.byte(race+offset,value)
 q.u.mem_write(q.actor+0x76,bytes(v&255 for v in c['baseAbilities']))
 for index,entry in enumerate(c['classes']):
  cp=q.native_classes+entry['id']*0x530;definition=entry['spell'];q.m.wi(cp+0x4d8,definition['SpellCaster']);q.m.wi(cp+0x4ec,0);q.m.wi(cp+0x4f0,definition['SpellbookRestricted']);q.m.wi(cp+0x4fc,definition['LearnScroll']);q.byte(cp+0x4e8,definition['ability'])
  known_array=q.m.heap+0x71000+index*0x1000;known_rows=q.m.heap+0x75000+index*0x1000;gain_rows=q.m.heap+0x79000+index*0x1000;q.m.wq(cp+0x130,known_array if definition['knownPresent']else 0)
  for level in range(40):
   count=definition['NumSpellLevels']&255;q.byte(cp+0x138+level,count);q.m.wq(known_array+level*8,known_rows+level*16 if count else 0);q.m.wq(cp+0x160+level*8,gain_rows+level*16 if count else 0)
   q.u.mem_write(known_rows+level*16,bytes(v&255 for v in definition['known']));q.u.mem_write(gain_rows+level*16,bytes(v&255 for v in definition['gain']))
   for ability,value in enumerate(definition['statGain']):q.byte(cp+0x2f6+level*6+ability,value)
 return original_start(address,until,*args,**kwargs)
q.u.emu_start=start
if __name__=='__main__':
 rng=random.Random(91003);cases=[]
 for index in range(288):
  classes=[]
  for at in range(1+index%3):
   definition=dict(SpellCaster=int((index+at)%5!=0),SpellbookRestricted=int((index+at)%3!=0),LearnScroll=int((index+at)%4==0),ability=(index+at)%6,knownPresent=(index+at)%7!=0,NumSpellLevels=[0,1,2,5,10][(index//3+at)%5],known=[rng.choice([0,0,1,2,255])for _ in range(10)],gain=[rng.choice([0,1,2,255])for _ in range(10)],statGain=[rng.choice([-2,0,0,1,2,127])for _ in range(6)])
   classes.append(dict(id=at*2+1,level=[1,2,3,20,40][(index+at)%5],skills=[],feats=[],spell=definition))
  feat=dict(MINSPELLLVL=[1,2,3,5,9,255][index%6],MinLevelClass=255,PREREQFEAT1=65535,PREREQFEAT2=65535,REQSKILL=65535,REQSKILL2=65535,ReqSkillMinRanks=0,ReqSkillMinRanks2=0,PreReqEpic=0,OrReqFeats=[65535]*5)
  cases.append(dict(featId=2,feat=feat,current=index%len(classes),classes=classes,scores=[10]*6,baseAttack=0,fortitude=0,skills=[],owned=[],secondary=[],selected=[],baseAbilities=[rng.choice([0,3,8,11,18,127,128,255])for _ in range(6)],raceAdjust=[rng.choice([-128,-2,0,2,127])for _ in range(6)]))
 results=[]
 for case in cases:
  active=case;results.append(q.run(case))
 out=q.m.root/'backups/animations/native-creation-feat-spell-requirements-observations-v1.json';assert not out.exists(),'Preserve prior evidence'
 out.write_text(json.dumps(dict(target=q.m.digest,scope=__doc__,procedures=[hex(lo)for lo,_ in q.ranges],rows=results),indent=2))
 print(json.dumps(dict(output=str(out),cases=len(results),accepted=sum(row['accepted']for row in results),boundaries=[],publicConnections=0,gpu=False)))
