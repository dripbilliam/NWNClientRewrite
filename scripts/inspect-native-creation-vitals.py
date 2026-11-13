"""Execute original class OK8e36d0 and live-stat class/ability/vital getters.
The complete creation branch of Class OK executes; GUI deactivation/destruction,
object lookup, ruleset hash/value services, feat-array Contains, unarmed attack
cache and memorized-slot refresh are explicit boundaries. Raw active table/stat
fixtures are not an original catalog/GFF parser or full creator/pixel oracle.
No running process, GPU, server or character save is used.
"""
import copy,importlib.util,json,random,struct
from pathlib import Path
spec=importlib.util.spec_from_file_location('image',Path(__file__).with_name('inspect-native-intratile-coordinator.py'))
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
actor,rules,classes,races,primary,bonus,panel,creature,vtable,choices=[m.heap+n for n in [0x1000,0x10000,0x20000,0x40000,0x45000,0x46000,0x50000,0x54000,0x55000,0x56000]]
setters=[0x1407fa760,0x1407f9ba0,0x1407f96d0,0x1407f9e70,0x1407fab40,0x1407f9670]
keys=['Str','Dex','Con','Int','Wis','Cha']
race_offsets=[0x18,0x19,0x1d,0x1a,0x1c,0x1b]
ranges=[(0x1408e36d0,0x1408e3f70),(0x1407f9820,0x1407f99ea),(0x1407f4df0,0x1407f5017),(0x1407ec3a0,0x1407ec50c),(0x1407f1110,0x1407f1226),(0x140299710,0x14029978f),(0x1407f0f60,0x1407f0fc7),(0x1407f5d70,0x1407f5e12),(0x1407f5e20,0x1407f5e28),(0x1407ef9c0,0x1407efa32),(0x1407f1ed0,0x1407f1f5a),(0x1407fa760,0x1407fa7ba),(0x1407f9ba0,0x1407f9c37),(0x1407f96d0,0x1407f97ae),(0x1407f9e70,0x1407f9ecd),(0x1407fab40,0x1407fabb7),(0x1407f9670,0x1407f96cd)]
def byte(a,v):u.mem_write(a,bytes([v&255]))
def word(a,v):u.mem_write(a,struct.pack('<H',v&65535))
def signed(v,bits=8):return (v&((1<<bits)-1))-(1<<bits) if v&(1<<(bits-1)) else v&((1<<bits)-1)
def hook(u,a,n,_):
 if a==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(r)for r in[UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
 if a==0x140800c90:m.finish(creature)
 elif a in[0x1407f7b80,0x1407faf60,m.stop+0x10]:m.finish()
 elif a==0x1401fc440:deactivated.append(y&0xffffffff);m.finish()
 elif a==0x140296910:
  ptr=m.q(x);count=m.si(x+8);m.finish(int((y&65535)in struct.unpack('<'+'H'*count,bytes(u.mem_read(ptr,count*2)))if count else False))
 elif a==0x1402ae870:
  key=bytes(u.mem_read(x,100)).split(b'\0')[0].decode('ascii')
  key=('C'+key)if key.startswith('HARGEN_')else('F'+key)if key.startswith('EAT_')else key
  hashes.append(key);m.finish(len(hashes))
 elif a==0x1402a4130:m.finish(case['settings'].get(hashes[y-1],z&0xffffffff))
 elif not any(lo<=a<hi for lo,hi in ranges):raise AssertionError(f'Uncaptured original creation-vital dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def call(address,args):
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],args):u.reg_write(reg,value&0xffffffffffffffff)
 u.emu_start(address,m.stop,count=1000000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return u.reg_read(UC_X86_REG_RAX)
def snapshot():
 return dict(classId=int(u.mem_read(actor+0x295,1)[0]),abilities=dict(zip(keys,list(u.mem_read(actor+0x76,6)))),scores=list(u.mem_read(actor+0x70,6)),baseHP=signed(int.from_bytes(u.mem_read(actor+0x84,2),'little'),16),temporaryHP=signed(int.from_bytes(u.mem_read(actor+0x86,2),'little'),16),currentHP=signed(int.from_bytes(u.mem_read(actor+0x88,2),'little'),16),maximumHP=call(0x1407f5e20,[actor]),armorBase=signed(call(0x1407ef9c0,[actor,0]),16),armorModeBonus=signed(call(0x1407f1ed0,[actor,creature]),32))
def run(c):
 global case,hashes,deactivated
 case=copy.deepcopy(c);hashes=[];deactivated=[];u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));m.wq(0x1412df8f8,rules)
 m.wq(rules+0x110,classes);m.wq(rules+0x118,races);byte(rules+0x105,len(c['tables']['classes']['orderedRows']));m.wq(creature+0x3b0,actor)
 source=c['source'];byte(actor+0x69,1);byte(actor+0x6a,0);byte(actor+0x295,source['classId']);byte(actor+0x296,source.get('level',1));byte(actor+0x7c,source['dexterityAdjustment']);m.wi(actor+0x94,source.get('experience',0));word(actor+0x50,0)
 word(actor+0x84,source['baseHP']);word(actor+0x86,source['temporaryHP'])
 for offset,ptr,ids in[(0x118,primary,source['primaryFeats']),(0x128,bonus,source['bonusFeats'])]:
  m.wq(actor+offset,ptr);m.wi(actor+offset+8,len(ids))
  for at,id in enumerate(ids):word(ptr+2*at,id)
 for ability,key in enumerate(keys):byte(races+race_offsets[ability],c['tables']['racialtypes']['orderedRows'][0].get(key+'Adjust',0))
 for at,row in enumerate(c['tables']['classes']['orderedRows']):
  ptr=classes+at*0x530;byte(ptr+0x74,row['HitDie']);m.wi(ptr+0x4d8,row.get('SpellCaster',0));byte(ptr+0x4e8,keys.index(row.get('SpellcastingAbil','Str')))
  for level,gains in enumerate(c['tables'][row['StatGainTable']]['orderedRows']):
   for ability,key in enumerate(keys):byte(ptr+0x2f6+level*6+ability,gains.get(key,0))
 for ability,key in enumerate(keys):call(setters[ability],[actor,source['abilities'][key]])
 initial=snapshot();results=[]
 m.wq(panel,vtable);m.wq(vtable,m.stop+0x10);m.wi(panel+0xe28,42);m.wi(panel+0x6e8,0);m.wq(panel+0xa78,choices)
 for operation in c['operations']:
  if operation['kind']=='class':
   m.wi(choices,operation['id']);before=len(deactivated);call(0x1408e36d0,[panel,0,0,0]);assert deactivated[before:]==[0x8004]
  elif operation['kind']=='ability':call(setters[keys.index(operation['key'])],[actor,operation['value']])
  else:raise AssertionError(operation)
  results.append(dict(operation=operation,state=snapshot()))
 return dict(case=c,initial=initial,results=results,settingsRead=sorted(set(hashes)))
if __name__=='__main__':
 rng=random.Random(8181);cases=[]
 for index in range(48):
  settings=[{},dict(CHARGEN_ABILITY_NEUTRAL_VALUE=11,CHARGEN_ABILITY_MODIFIER_INCREMENT=3),dict(CHARGEN_ABILITY_NEUTRAL_VALUE=8,CHARGEN_ABILITY_MODIFIER_INCREMENT=-2,CHARGEN_BASE_ABILITY_MIN=6,CHARGEN_BASE_ABILITY_MIN_PRIMARY=12,FEAT_DRAGON_HD12=260,FEAT_DRAGON_HD10=23,FEAT_DRAGON_HD8=17,FEAT_DRAGON_HD6=9)][index%3]
  table=dict(orderedRows=[dict(HitDie=[4,6,8,10,12][at%5],StatGainTable='gain'+str(at%2),SpellCaster=int(at in[3,10]or at==37 and index%2==1),SpellcastingAbil='Wis'if at==3 else'Int'if at==10 else'Con')for at in range(38)])
  tables=dict(classes=table,racialtypes=dict(orderedRows=[{key+'Adjust':rng.choice([-4,0,2,120])for key in keys}]),gain0=dict(orderedRows=[dict(zip(keys,[0,0,0,0,0,0]))]),gain1=dict(orderedRows=[{key:rng.choice([-128,-2,0,2,127])for key in keys}]),ruleset=dict(orderedRows=[dict(Label=k,Value=str(v))for k,v in settings.items()]))
  old=[0,3,10,37][index%4];target=[0,3,10,37][index//4%4];feats=[[],[0x412],[0x413],[0x414],[0x3db],[0x412,0x414,0x3db]][index%6]
  source=dict(classId=old,abilities={key:rng.choice([3,8,12,18,127,255])for key in keys},baseHP=[0,0,17,255][index%4],temporaryHP=index%4,dexterityAdjustment=[0,-3,2,127][index%4],primaryFeats=feats if index%2 else[],bonusFeats=[]if index%2 else feats,level=1,experience=0)
  operations=[dict(kind='class',id=target),dict(kind='ability',key='Dex',value=[3,12,255][index%3]),dict(kind='ability',key='Con',value=[3,14,127][index%3]),dict(kind='class',id=target),dict(kind='class',id=(target+1)%38)]
  cases.append(dict(settings=settings,tables=tables,source=source,operations=operations))
 out=m.root/'backups/animations/native-creation-vitals-observations-v1.json';assert not out.exists(),'Preserve prior evidence'
 rows=[run(c)for c in cases];out.write_text(json.dumps(dict(target=m.digest,scope=__doc__,procedures=['0x1408e36d0','0x1407f9820','0x1407f9ba0','0x1407f96d0','0x1407f4df0','0x1407ec3a0'],rows=rows),indent=2))
 print(json.dumps(dict(output=str(out),cases=len(rows),operations=sum(len(r['results'])for r in rows))))
