"""Read-only original pregame skill arithmetic, class gains and eligibility.
Executes unchanged1407f1110/140299710,1407fadc0,14029a300,1407f0bf0/1407f6ae0
and the BIC import mask block1407f8ba8..1407f8d89. Hash/ruleset lookup services
are captured. BIC field reads and effective-score writes are fixture boundaries;
this is not a full GFF-import or rendered/original-client input oracle.
"""
import importlib.util,json,struct,random
from pathlib import Path
spec=importlib.util.spec_from_file_location('image',Path(__file__).with_name('inspect-native-intratile-coordinator.py'))
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
actor,rules,skills,classes,ranks,values,skill_lists=[m.heap+n for n in [0x1000,0x10000,0x12000,0x20000,0x40000,0x41000,0x50000]]
ranges=[(0x1407f1110,0x1407f1226),(0x140299710,0x14029978e),(0x1407fadc0,0x1407faf3a),(0x1407ec3a0,0x1407ec50b),(0x14029a300,0x14029a3ba),(0x1407f0bf0,0x1407f0c26),(0x1407f6ae0,0x1407f6b16),(0x1407f8ba8,0x1407f8d89)]
def hook(u,a,n,_):
 if a in[m.stop,0x1407f8d89]:u.emu_stop();return
 x,y,z=[u.reg_read(r)for r in[UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8]]
 if a==0x1402ae870:
  key=bytes(u.mem_read(x,100)).split(b'\0')[0].decode('ascii');key='C'+key if key.startswith('HARGEN_')else key;keys.append(key);m.finish(len(keys))
 elif a==0x1402a4130:m.finish(case['settings'].get(keys[y-1],z&0xffffffff))
 elif a==0x140115890:m.finish()
 elif not any(lo<=a<hi for lo,hi in ranges):raise AssertionError(f'Uncaptured pregame skill dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def call(address,args):
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],args):u.reg_write(reg,value)
 u.emu_start(address,m.stop,count=2000000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return u.reg_read(UC_X86_REG_RAX)
def signed(value):return (value&255)-256 if value&128 else value&255
def run(c):
 global case,keys
 case=c;keys=[];u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));m.wq(0x1412df8f8,rules);m.wq(rules+0x120,skills);m.wq(rules+0x110,classes)
 tables=c['tables'];source=c['source'];skill_rows=tables['skills']['orderedRows'];class_rows=tables['classes']['orderedRows'];count=len(skill_rows)&255
 u.mem_write(rules+0x105,bytes([len(class_rows)&255,0,count]));m.wq(actor+0xd0,values);m.wq(actor+0xd8,ranks)
 u.mem_write(actor+0x69,bytes([len(source['classes'])]));u.mem_write(actor+0x7c,bytes([source['dexterityAdjustment']&255]))
 for at,item in enumerate(source['classes']):u.mem_write(actor+at*0x150+0x295,bytes([item['id']&255,item['level']&255]))
 for at,data in enumerate(class_rows):
  for level,row in enumerate(tables.get(data.get('StatGainTable',''),dict(orderedRows=[]))['orderedRows'][:60]):
   for ability,key in enumerate(['Str','Dex','Con','Int','Wis','Cha']):u.mem_write(classes+at*0x530+0x2f6+level*6+ability,bytes([int(row.get(key,0))&255]))
  ids=[int(row['SkillIndex'])&65535 for row in tables.get(data.get('SkillsTable',''),dict(orderedRows=[]))['orderedRows']]
  ptr=skill_lists+at*0x1000;m.wq(classes+at*0x530+0x2a0,ptr);u.mem_write(classes+at*0x530+0x2a8,struct.pack('<H',len(ids)))
  for index,id in enumerate(ids):u.mem_write(ptr+index*8,struct.pack('<H',id))
 gains=[signed(call(0x1407f1110,[actor,ability]))for ability in range(6)]
 scores=[(source['abilities'][key]+int(tables['racialtypes']['orderedRows'][source['race']].get(key+'Adjust',0))+gains[ability])&255 for ability,key in enumerate(['Str','Dex','Con','Int','Wis','Cha'])]
 u.mem_write(actor+0x70,bytes(scores))
 for at,data in enumerate(skill_rows[:count]):
  m.wi(skills+at*0x38+0x20,max(0,['STR','DEX','CON','INT','WIS','CHA'].index(data['KeyAbility'])if data['KeyAbility']in['STR','DEX','CON','INT','WIS','CHA']else 0));m.wi(skills+at*0x38+0x28,data['Untrained']);m.wi(skills+at*0x38+0x30,data['AllClassesCanUse'])
  u.mem_write(ranks+at,bytes([source['ranks'][at]&255]))
 call(0x1407fadc0,[actor]);u.reg_write(UC_X86_REG_R15,actor);u.reg_write(UC_X86_REG_RBP,m.stack+0x10000);u.reg_write(UC_X86_REG_RSP,m.stack+0x1fd00);u.emu_start(0x1407f8ba8,0x1407f8d89,count=2000000);assert u.reg_read(UC_X86_REG_RIP)==0x1407f8d89
 entries=[dict(id=id,value=signed(call(0x1407f6ae0,[actor,id])),lostAbilities=False)for id in range(count)if call(0x1407f0bf0,[actor,id])&0xffffffff]
 return dict(case=c,classGains=gains,scores=scores,values=[signed(v)for v in bytes(u.mem_read(values,count))],mask=m.si(actor+0xe0)&0xffffffff,entries=entries)
if __name__=='__main__':
 rng=random.Random(701);cases=[]
 for index in range(72):
  count=[0,1,6,33,40,255,256,27][index%8];settings=[{},dict(CHARGEN_ABILITY_NEUTRAL_VALUE=11,CHARGEN_ABILITY_MODIFIER_INCREMENT=3),dict(CHARGEN_ABILITY_NEUTRAL_VALUE=8,CHARGEN_ABILITY_MODIFIER_INCREMENT=-2)][index%3]
  tables=dict(skills=dict(orderedRows=[dict(KeyAbility=rng.choice(['STR','DEX','CON','INT','WIS','CHA','dex','???']),Untrained=rng.randrange(2),AllClassesCanUse=rng.randrange(2))for _ in range(count)]),classes=dict(orderedRows=[dict(SkillsTable='sk'+str(at),StatGainTable='sg'+str(at))for at in range(3)]),racialtypes=dict(orderedRows=[{key+'Adjust':rng.choice([-2,0,2,120])for key in ['Str','Dex','Con','Int','Wis','Cha']}]),ruleset=dict(orderedRows=[dict(Label=key,Value=str(value))for key,value in settings.items()]))
  for at in range(3):
   tables['sk'+str(at)]=dict(orderedRows=[dict(SkillIndex=id,ClassSkill=0)for id in range(count)if rng.randrange(3)==0]);tables['sg'+str(at)]=dict(orderedRows=[{key:rng.choice([-128,-3,0,0,2,127])if level<3 else 0 for key in ['Str','Dex','Con','Int','Wis','Cha']}for level in range(60)])
  source=dict(abilities={key:rng.choice([3,8,10,12,18,127,255])for key in ['Str','Dex','Con','Int','Wis','Cha']},race=0,classes=[dict(id=rng.choice([0,1,2,250]),level=rng.choice([0,1,2,3,60]))for _ in range(1+index%3)],ranks=[rng.choice([0,0,1,5,127,128,255])for _ in range(count)],dexterityAdjustment=rng.choice([-3,0,2]),lostAbilities=False,native_only=True)
  cases.append(dict(settings=settings,source=source,tables=tables))
 rows=[run(c)for c in cases];out=m.root/'backups/animations/native-pregame-skill-observations-v1.json';assert not out.exists(),'Preserve prior evidence';out.write_text(json.dumps(dict(target=m.digest,scope=__doc__,rows=rows),indent=2));print(json.dumps(dict(output=str(out),cases=len(rows))))
