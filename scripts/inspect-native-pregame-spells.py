"""Read-only original pregame spell gain/minimum and complete SetData execution.
Original prestige selection, ability checks, specialization, gain widths and
summary/known-row enumeration execute unchanged. Hash/ruleset, UI row creation,
TLK and spell/active-level lookup services are captured. AddKnownSpell grouping
also executes unchanged. Typed BIC reads and initial score writes are fixture
boundaries; not a complete import/rendering oracle.
"""
import importlib.util,json,random,struct
from pathlib import Path
spec=importlib.util.spec_from_file_location('image',Path(__file__).with_name('inspect-native-intratile-coordinator.py'))
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
actor,rules,classes,races,gain_lists,known_lists,spells,page,string,vtable=[m.heap+n for n in [0x1000,0x10000,0x12000,0x18000,0x20000,0x30000,0x50000,0x60000,0x62000,0x63000]]
text_stub=m.stop+0x100
creature=m.heap+0x75000
ranges=[(0x1407f1110,0x1407f1226),(0x140299710,0x14029978e),(0x1407ec3a0,0x1407ec50b),(0x1407f6b20,0x1407f710a),(0x1407f7130,0x1407f742f),(0x1407f0f60,0x1407f0fc6),(0x1407f1080,0x1407f109f),(0x1407f69a0,0x1407f6a06),(0x1402a4a30,0x1402a4a49),(0x140299e40,0x140299e68),(0x1407f66e0,0x1407f674c),(0x1407f5c50,0x1407f5d00),(0x1409c1b50,0x1409c1e4e),(0x1407ebed0,0x1407ebffa)]
def hook(u,a,n,_):
 global last_ref
 if a==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(r)for r in[UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
 if a==0x1402ae870:
  key=bytes(u.mem_read(x,100)).split(b'\0')[0].decode('ascii');key='C'+key if key.startswith('HARGEN_')else key;keys.append(key);m.finish(len(keys))
 elif a==0x1402a4130:m.finish(settings.get(keys[y-1],z&0xffffffff))
 elif a==0x140800c90:m.finish(creature)
 elif a in[0x140115890,0x140c10370,0x140c10410,0x1401fb540,text_stub]:m.finish()
 elif a==0x1401edf80:captured.clear();m.finish()
 elif a==0x140198c60:last_ref=y&0xffffffff;m.wq(z,string+0x100);m.wi(z+8,0);m.finish(1)
 elif a==0x14018ded0:u.mem_write(x,bytes(u.mem_read(y,17)));m.finish(x)
 elif a==0x1402af4a0:m.finish(spells+(y&0xffffffff)*0x1b0 if 0<=y<len(tables['spells']['orderedRows'])else 0)
 elif a==0x1402af530:
  id=(x-spells)//0x1b0;data=tables['classes']['orderedRows'][y&255]
  m.finish((tables['spells']['orderedRows'][id].get(data['SpellTableColumn'],255)&255)if data['SpellCaster']or not data['PlayerClass']else 255)
 elif a==0x1409c1490:
  id=y&0xffffffff;icon=bytes(u.mem_read(z,17)).split(b'\0')[0].decode('ascii').lower();captured.append(dict(id=-1 if id==0xffffffff else id,nameRef=last_ref,icon=icon));m.finish()
 elif not any(lo<=a<hi for lo,hi in ranges+[(0x1409c1810,0x1409c1b4e)]):raise AssertionError(f'Uncaptured summary spell dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def call(address,args):
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],args):u.reg_write(reg,value)
 u.emu_start(address,m.stop,count=3000000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return u.reg_read(UC_X86_REG_RAX)
def signed(v):return (v&255)-256 if v&128 else v&255
def run(c,live=False):
 global tables,settings,keys,captured,last_ref
 tables=c['tables'];settings=c['settings'];source=c['source'];stats=source['stats'];keys=[];captured=[];last_ref=0
 u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));m.wq(0x1412df8f8,rules);m.wq(0x1412df968,string+0x500);m.wq(rules+0x110,classes);m.wq(rules+0x118,races)
 u.mem_write(rules+0x105,bytes([len(tables['classes']['orderedRows']),len(tables['racialtypes']['orderedRows']),0]));u.mem_write(actor+0x69,bytes([len(stats['classes'])]));u.mem_write(actor+0x50,struct.pack('<H',stats['race']))
 for ability,key in enumerate(['Str','Dex','Con','Int','Wis','Cha']):u.mem_write(actor+0x76+ability,bytes([stats['abilities'][key]&255]));u.mem_write(races+stats['race']*0x68+[0x18,0x19,0x1d,0x1a,0x1c,0x1b][ability],bytes([tables['racialtypes']['orderedRows'][stats['race']][key+'Adjust']&255]))
 for at,data in enumerate(tables['classes']['orderedRows']):
  ptr=classes+at*0x530
  for offset,key in[(0x4d8,'SpellCaster'),(0x4d4,'PlayerClass'),(0x4f0,'SpellbookRestricted'),(0x4f8,'PickSchool'),(0x500,'Arcane')]:m.wi(ptr+offset,int(bool(data[key])))
  u.mem_write(ptr+0x4e8,bytes([['STR','DEX','CON','INT','WIS','CHA'].index(data['SpellcastingAbil'])]));u.mem_write(ptr+0x525,bytes([data['ArcSpellLvlMod']&255,data['DivSpellLvlMod']&255]))
  for level,row in enumerate(tables[data['StatGainTable']]['orderedRows']):
   for ability,key in enumerate(['Str','Dex','Con','Int','Wis','Cha']):u.mem_write(ptr+0x2f6+level*6+ability,bytes([row[key]&255]))
  for level,row in enumerate(tables[data['SpellGainTable']]['orderedRows']):
   p=gain_lists+at*0x1000+level*0x20;m.wq(ptr+0x160+level*8,p);u.mem_write(ptr+0x138+level,bytes([row['NumSpellLevels']&255]))
   for spell_level in range(row['NumSpellLevels']):u.mem_write(p+spell_level,bytes([row['SpellLevel'+str(spell_level)]&255]))
 for index,item in enumerate(stats['classes']):
  u.mem_write(actor+index*0x150+0x295,bytes([item['id'],item['level']]));u.mem_write(actor+index*0x150+0x292,bytes([source['books'][index]['school']]))
  for level in range(10):
   p=known_lists+index*0x4000+level*0x400;m.wq(actor+index*0x150+0x148+level*0x10,p);m.wi(actor+index*0x150+0x150+level*0x10,0);m.wi(actor+index*0x150+0x154+level*0x10,256)
  for id in source['books'][index]['known']:call(0x1407ebed0,[actor,index,id])
 gains=[signed(call(0x1407f1110,[actor,ability]))for ability in range(6)]
 scores=[(stats['abilities'][key]+tables['racialtypes']['orderedRows'][stats['race']][key+'Adjust']+gains[ability])&255 for ability,key in enumerate(['Str','Dex','Con','Int','Wis','Cha'])];u.mem_write(actor+0x70,bytes(scores))
 for id,row in enumerate(tables['spells']['orderedRows']):m.wi(spells+id*0x1b0+0x10,row['Name']);u.mem_write(spells+id*0x1b0+0x18,row['IconResRef'].encode()+b'\0')
 minimums=[[bool(call(0x1407f7130,[actor,index,level])&255)for level in range(10)]for index in range(len(stats['classes']))]
 slots=[[call(0x1407f6b20,[actor,index,level])&255 for level in range(10)]for index in range(len(stats['classes']))]
 m.wq(page+0x188,string);m.wq(string,vtable);m.wq(vtable+0xd0,text_stub);m.wq(creature+0x3b0,actor);call(0x1409c1810 if live else 0x1409c1b50,[page,42 if live else actor])
 levels=[]
 for index in range(len(stats['classes'])):
  book=[]
  for level in range(10):
   count=m.si(actor+index*0x150+0x150+level*0x10);ptr=m.q(actor+index*0x150+0x148+level*0x10)
   book.append(list(struct.unpack('<'+'I'*count,u.mem_read(ptr,count*4))))
  levels.append(dict(school=source['books'][index]['school'],levels=book))
 result=dict(case=c,minimums=minimums,slots=slots,captured=list(captured))
 if live:result['liveBooks']=levels
 return result
if __name__=='__main__':
 rng=random.Random(9123);cases=[]
 for index in range(72):
  settings=[{},dict(CHARGEN_BASE_ABILITY_MIN_PRIMARY=9,CHARGEN_ABILITY_NEUTRAL_VALUE=11,CHARGEN_ABILITY_MODIFIER_INCREMENT=3),dict(CHARGEN_BASE_ABILITY_MIN_PRIMARY=12)][index%3]
  tables=dict(classes=dict(orderedRows=[]),racialtypes=dict(orderedRows=[{key+'Adjust':rng.choice([-2,0,2])for key in ['Str','Dex','Con','Int','Wis','Cha']}]),skills=dict(orderedRows=[]),ruleset=dict(orderedRows=[dict(Label=k,Value=str(v))for k,v in settings.items()]),spells=dict(orderedRows=[]))
  for at in range(5):
   tables['classes']['orderedRows'].append(dict(SpellCaster=int(at!=4),PlayerClass=1,SpellbookRestricted=int(at in[0,1]),PickSchool=int(at==0),Arcane=int(at<2),SpellcastingAbil=['INT','CHA','WIS','WIS','STR'][at],SpellTableColumn='Book'+str(at),ArcSpellLvlMod=(index%3)+1 if at==4 else 0,DivSpellLvlMod=(index%2)+1 if at==4 else 0,StatGainTable='sg'+str(at),SkillsTable='',SpellGainTable='sp'+str(at)))
   tables['sg'+str(at)]=dict(orderedRows=[{key:rng.choice([-2,0,2])if level<2 else 0 for key in ['Str','Dex','Con','Int','Wis','Cha']}for level in range(60)])
   tables['sp'+str(at)]=dict(orderedRows=[dict(NumSpellLevels=10,**{'SpellLevel'+str(level):(rng.choice([0,1,2,255])if level<min(10,1+class_level//2)else 255)for level in range(10)})for class_level in range(40)])
  for id in range(24):tables['spells']['orderedRows'].append(dict(Name=1000+id,SpellDesc=2000+id,IconResRef='testspell'+str(id),**{'Book'+str(at):rng.choice([0,1,2,3,4,9,255])for at in range(5)}))
  ids=[[2],[3],[0],[0,1,4],[2,3,4],[0,2,4],[0,1,2,3,4],[4]][index%8];stats=dict(abilities={key:rng.choice([3,8,10,14,18,24,127,255])for key in ['Str','Dex','Con','Int','Wis','Cha']},race=0,classes=[dict(id=id,level=rng.choice([1,2,4,8,20,40]))for id in ids],ranks=[],dexterityAdjustment=0,lostAbilities=False,native_only=True)
  if index%8 in[3,4]:stats['classes'][0]['level']=stats['classes'][1]['level']=8
  source=dict(stats=stats,books=[dict(school=index%3,known=[rng.randrange(24)for _ in range(12)]+[65535])for _ in ids],native_only=True);cases.append(dict(settings=settings,tables=tables,source=source))
 rows=[run(c)for c in cases];out=m.root/'backups/animations/native-pregame-spell-observations-v2.json';assert not out.exists(),'Preserve prior evidence';out.write_text(json.dumps(dict(target=m.digest,scope=__doc__,rows=rows),indent=2));print(json.dumps(dict(output=str(out),cases=len(rows))))
