"""Complete original SaveStats/CombatInformation::SaveData coordinators.
Runs original extended GFF writers. GFF storage, strings/localization, class
save and lower stat queries are explicit captured boundaries. Source binary
is hash verified by the shared read-only PE emulator; game install unchanged.
"""
import importlib,sys,json,copy,random,struct
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
stats,actor,cache,savedCache,gff,root,vtable,inventory,rules,baseArray,app=[m.heap+n*0x2000 for n in range(1,12)]
allocation=m.heap+0x30000
ranges=[]
for name in ['copy-save-creature-stats','stats-save-combat-data','stats-save-dword-and-byte','stats-save-word-and-byte']:
 d=json.loads((m.root/'backups/animations'/('rea-'+name+'.json')).read_text())['structuredContent']['normalized_result']
 ranges.extend((int(r['start'],16),int(r['end'],16)+1)for r in d['procedure']['body']['ranges'])
statFields=[('DataMigration',0xe68,'i'),('FirstName',0x48,'l'),('LastName',0x58,'l'),('Description',0x80,'l'),('DescriptionOverride',0x90,'s'),('IsPC',0xb0,'i'),('IsDM',0xac,'i'),('Conversation',0x68,'r'),('Interruptable',0x7c,'b'),('Age',0xa0,'i'),('Gender',0xa4,'b'),('Race',0xd20,'b'),('Subrace',0xd28,'s'),('StartingPackage',0xd4,'i'),('Deity',0xe58,'s'),('MClassLevUpIn',0xc0,'b'),('willbonus',0xe2d,'b'),('fortbonus',0xe2c,'b'),('refbonus',0xe2e,'b'),('OverrideBAB',0xd53,'b'),('Str',0xd38,'b'),('Dex',0xd3a,'b'),('Con',0xd3c,'b'),('Int',0xd3e,'b'),('Wis',0xd40,'b'),('Cha',0xd42,'b'),('NaturalAC',0xd44,'b'),('Experience',0xa8,'i'),('MovementRate',0xe20,'b'),('GoodEvil',0xde4,'b'),('LawfulChaotic',0xde6,'b'),('Color_Skin',0xde8,'b'),('Color_Hair',0xde9,'b'),('Color_Tattoo1',0xdea,'b'),('Color_Tattoo2',0xdeb,'b'),('Phenotype',0xdee,'b'),('Appearance_Type',0xdec,'w'),('Appearance_Head',0xdf0,'w'),('Tail_New',0xe18,'i'),('Wings_New',0xe1c,'i'),('FactionID',0xc4,'w'),('ChallengeRating',0xd0,'f')]
partFields=[('BodyPart_Neck',0xe04),('BodyPart_Torso',0xe00),('BodyPart_Belt',0xe02),('BodyPart_Pelvis',0xdfe),('BodyPart_LShoul',0xe10),('BodyPart_LBicep',0xe0c),('BodyPart_LFArm',0xe08),('BodyPart_LHand',0xe14),('BodyPart_LThigh',0xdfa),('BodyPart_LShin',0xdf8),('BodyPart_LFoot',0xdf4),('BodyPart_RShoul',0xe0e),('BodyPart_RBicep',0xe0a),('BodyPart_RFArm',0xe06),('BodyPart_RHand',0xe12),('BodyPart_RThigh',0xdfc),('BodyPart_RShin',0xdf6),('ArmorPart_RFoot',0xdf2)]
statFields.extend((n,o,'w')for n,o in partFields)
actorFields=[('Tag',0x20,'s'),('Gold',0x898,'i'),('SoundSetFile',0x8a0,'w'),('FootstepType',0x8a4,'i'),('Plot',0xfc,'b'),('NoPermDeath',0x8bc,'b'),('Disarmable',0x714,'b'),('BodyBag',0x8a8,'b'),('HitPoints',0xe4,'w')]
savedFields=[('Race',0x9e2,'b'),('Str',0x9de,'b'),('Dex',0x9e0,'b'),('Con',0x9df,'b'),('SoundSetFile',0x9e4,'w'),('BaseAttackBonus',0xa54,'b'),('RefSaveThrow',0xa5b,'b'),('WillSaveThrow',0xa5c,'b'),('FortSaveThrow',0xa5a,'b'),('ArmorClass',0xa50,'w'),('MaxHitPoints',0xa58,'w'),('PortraitId',0x9da,'w'),('Portrait',0x9c8,'r'),('Appearance_Type',0x9dc,'w')]
def alloc(n):
 global cursor
 p=allocation+cursor;cursor+=(n+15)&~15;assert cursor<0xb0000;return p
def string(p):
 b=bytearray()
 while p:
  v=u.mem_read(p,1)[0]
  if not v:break
  b.append(v);p+=1
 return b.decode('ascii')
def exo(p):return bytes(u.mem_read(m.q(p),m.si(p+8))).decode('ascii')if m.q(p)else''
def exostring(p,s):
 b=s.encode('ascii');a=alloc(len(b)+1);u.mem_write(a,b+b'\0');m.wq(p,a);m.wi(p+8,len(b));m.wi(p+12,len(b)+1)
def write(p,t,v):
 if t=='s':exostring(p,v)
 elif t=='l':locs[p]=v;u.mem_write(p,bytes(16))
 elif t=='r':u.mem_write(p,v.encode('ascii')[:16].ljust(17,b'\0'))
 elif t=='f':m.wf(p,v)
 else:u.mem_write(p,(v&((1<<({'b':1,'w':2,'i':4}[t]*8))-1)).to_bytes({'b':1,'w':2,'i':4}[t],'little'))
def node(t):nodes.append(dict(fields={},type=t));return len(nodes)-1
def addField(n,label,t,v):
 if label in nodes[n]['fields']:nodes[n]['fields'][label]['value']=v;return
 ptr=alloc(16);nodes[n]['fields'][label]=dict(type=t,value=v);fieldRecords.append((ptr,n,label,t));fieldIds[n,label]=len(fieldRecords)-1
 if t in [0,1,2,3,4,5]:m.wi(ptr+8,v)
types={0x1401a2a80:0,0x1401a2e20:1,0x1401a36f0:2,0x1401a3590:3,0x1401a31d0:4,0x1401a34f0:5,0x1401a3350:8,0x1401a2d30:10,0x1401a2ec0:11,0x1401a2b20:12}
def norm(v,t):
 if t==0:return v&255
 if t==1:return (v&255)-256 if v&128 else v&255
 if t==2:return v&65535
 if t==3:return (v&65535)-65536 if v&32768 else v&65535
 if t==4:return v&0xffffffff
 if t==5:return (v&0xffffffff)-0x100000000 if v&0x80000000 else v&0xffffffff
 return v
def hook(u,a,n,_):
 if a==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(r)for r in[UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
 if a in types:
  t=types[a]
  if t==8:v=struct.unpack('<f',struct.pack('<I',u.reg_read(UC_X86_REG_XMM2)&0xffffffff))[0]
  elif t==10:v=exo(z)
  elif t==11:v=string(z)[:16]
  elif t==12:v=locs[z]
  else:v=norm(z,t)
  addField(m.si(y),string(w)[:16],t,v);m.finish(1);return
 if a==0x14019f4f0:
  idx=node(m.si(rsp+0x28)&0xffffffff);addField(m.si(z),string(w)[:16],14,nodes[idx]);m.wi(y,idx);m.finish(1);return
 if a==0x14019f1e0:
  entries=[];lists.append(entries);addField(m.si(z),string(w)[:16],15,entries);m.wi(y,len(lists)-1);m.finish(1);return
 if a==0x14019f2b0:
  idx=node(w&0xffffffff);lists[m.si(z)].append(nodes[idx]);m.wi(y,idx);m.finish(1);return
 if a==0x14019fcc0:m.finish(fieldIds.get((m.si(y),string(z)[:16]),0xffffffff));return
 if a==0x14019fc20:m.finish(fieldRecords[z][0]if z<len(fieldRecords)else 0);return
 if a==0x14019edb0:
  addField(m.si(y),string(z)[:16],w&0xffffffff,0);m.finish(fieldRecords[fieldIds[m.si(y),string(z)[:16]]][0]);return
 if a==0x140085bd0:
  assert string(z)=='%s%s';b=(string(w)+string(m.q(rsp+0x28))).encode('ascii');u.mem_write(x,b[:y-1]+b'\0');m.finish(len(b));return
 if a==0x1401693c0:locs[x]=copy.deepcopy(locs[y]);u.mem_write(x,bytes(16));m.finish(x);return
 if a==0x14016c810:exostring(x,str(y&0xffffffff));m.finish(x);return
 if a==0x14016ab00:exostring(y,exo(x)+exo(z));m.finish(y);return
 if a==0x14016afb0:
  assert string(y)=='%s (%s)';exostring(x,string(z)+' ('+string(w)+')');m.finish(x);return
 if a==0x140169920:
  key=itemLocs[x];assert y==0 and w==0 and m.si(rsp+0x28)==1;calls.append(['name',key,exo(z),0,0,True]);name=c['items'][key]['name']
  if name is not None:exostring(z,name)
  m.finish(0 if name is None else 1);return
 lower={0x1403f8e90:'baseAttack',0x140406820:'reflex',0x14040b7f0:'will',0x1404024c0:'fortitude',0x140390070:'armor',0x140402f80:'isDM',m.stop+0x100:'maximumHP',m.stop+0x110:'currentHP',m.stop+0x120:'portraitId'}
 if a in lower:
  name=lower[a];calls.append([name]if name in ['armor','isDM','portraitId']else[name,y&0xffffffff]);m.finish(c['lower'][name]);return
 if a==m.stop+0x130:calls.append(['portrait']);write(y,'r',c['portrait']);m.finish(y);return
 if a==0x140413880:calls.append(['classInfo']);addField(m.si(z),'ClassSaveMarker',5,42);m.finish();return
 if a==0x14055b6c0:
  id=y&0xffffffff;calls.append(['item',id]);m.finish(itemPtrs.get(str(id),0));return
 if a==0x14029ca00:
  id=y&0xffffffff;calls.append(['base',id]);m.finish(basePtrs[id]);return
 if a==0x140462bd0:
  slot=y&0xffffffff;calls.append(['equipped',slot]);m.finish(itemPtrs.get(str(c['equipment'].get(str(slot))),0));return
 if a==0x140c10368:m.finish(alloc(x));return
 if a==0x140c10370:m.finish();return
 if a==0x140c10410:m.finish(u.reg_read(UC_X86_REG_RAX));return
 if not any(lo<=a<hi for lo,hi in ranges):raise RuntimeError(f'Uncaptured stats-save dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def fillCache(ptr,value):
 u.mem_write(ptr,bytes(value['scalars']));m.wi(ptr+0x40,value['weaponIds'][0]);m.wi(ptr+0x44,value['weaponIds'][1]);write(ptr+0x68,'w',value['flags']);exostring(ptr+0x48,value['text'][0]);exostring(ptr+0x58,value['text'][1])
 for off,key in [(0x20,'attackNodes'),(0x30,'damageNodes')]:
  entries=value[key];array=alloc(max(1,len(entries))*8);m.wq(ptr+off,array);m.wi(ptr+off+8,len(entries))
  for i,b in enumerate(entries):n=alloc(6);u.mem_write(n,bytes(b));m.wq(array+i*8,n)
def run(case):
 global c,cursor,nodes,lists,locs,fieldIds,fieldRecords,calls,itemPtrs,basePtrs,itemLocs
 c=case;cursor=0;nodes=[];lists=[];locs={};fieldIds={};fieldRecords=[];calls=[];itemPtrs={};basePtrs={};itemLocs={}
 u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));m.wq(stats+0x30,actor);m.wq(stats+0xd70,cache);m.wq(actor+0xa48,savedCache)
 m.wq(actor,vtable);m.wq(vtable+0x130,m.stop+0x100);m.wq(vtable+0x138,m.stop+0x110);m.wq(vtable+0x1a8,m.stop+0x120);m.wq(vtable+0x198,m.stop+0x130)
 m.wq(0x1412df8f8,rules);m.wq(rules+0x20,baseArray);m.wq(0x1412df970,app);m.wq(app+8,app);m.wq(actor+0x950,inventory);m.wi(actor+0x97c,c['locked'])
 for fields,ptr,values in [(statFields,stats,c['stats']),(actorFields,actor,c['creature']),(savedFields,actor,c['saved'])]:
  for name,offset,t in fields:write(ptr+offset,t,values[name])
 fillCache(cache,c['cache']);fillCache(savedCache,c['savedCache'])
 for id,base in c['bases'].items():
  ptr=alloc(0x200);basePtrs[int(id)]=ptr
  for off,key,t in [(4,'equipableSlots','i'),(8,'weaponWield','b'),(0x18,'ranged','b'),(0x1a,'numDice','b'),(0x1b,'die','b')]:write(ptr+off,t,base[key])
 for key,item in c['items'].items():
  ptr=alloc(0x500);itemPtrs[key]=ptr;itemLocs[ptr+0x420]=key;m.wi(ptr+0x40,item['base'])
 node(0xffffffff);m.wi(root,0);rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 entry=0x1402ad6d0 if c.get('combatOnly')else 0x1404145e0
 for reg,v in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8],[cache if c.get('combatOnly')else stats,gff,root]):u.reg_write(reg,v)
 try:u.emu_start(entry,m.stop,count=300000)
 except Exception:print(json.dumps(dict(case=c['name'],rip=hex(u.reg_read(UC_X86_REG_RIP)),calls=calls[-8:])));raise
 assert u.reg_read(UC_X86_REG_RIP)==m.stop,(c['name'],hex(u.reg_read(UC_X86_REG_RIP)))
 for ptr,n,label,t in fieldRecords:
  if t in [0,1,2,3,4,5]:nodes[n]['fields'][label]['value']=norm(m.si(ptr+8)&0xffffffff,t)
 def saved(ptr):return dict(text=[exo(ptr+0x48),exo(ptr+0x58)],flags=int.from_bytes(u.mem_read(ptr+0x68,2),'little'))
 return dict(case=c,output=nodes[0],calls=calls,cache=saved(cache),savedCache=saved(savedCache))
def cacheValue():return dict(scalars=list(range(32)),initialized=[1]*32,weaponIds=[0x7f000000,0x7f000000],text=['old right','old left'],flags=0x604,attackNodes=[[255,99,1,2,3,28]],damageNodes=[[128,4,5,6,7,8]])
def base(name):
 s={n:({'strRef':0xffffffff,'entries':[dict(languageId=0,text=n)]}if t=='l'else n if t=='s'else'conversation'if t=='r'else 1.25 if t=='f'else 10)for n,o,t in statFields}
 s['IsPC']=1;s['IsDM']=0
 a={n:n if t=='s'else 250 for n,o,t in actorFields};a['HitPoints']=100
 b={n:'oldportrait'if t=='r'else 20 for n,o,t in savedFields};b['MaxHitPoints']=150;b['PortraitId']=65535
 return dict(name=name,stats=s,creature=a,saved=b,locked=0,lower=dict(baseAttack=17,reflex=-2,will=129,fortitude=3,armor=27,isDM=0,maximumHP=120,currentHP=80,portraitId=65535),portrait='newportrait',cache=cacheValue(),savedCache=cacheValue(),items={},bases={},equipment={})
cases=[base('unlocked-pc'),base('locked-pc')];cases[1]['locked']=1
for lock in [0,1]:
 for pc,dm in [(0,0),(1,0),(1,1),(-1,0)]:
  for hp in [-32768,80,150,32767]:
   c=base(f'hp-plot-{lock}-{pc}-{dm}-{hp}');c['locked']=lock;c['stats']['IsPC']=pc;c['lower']['isDM']=dm;c['lower']['currentHP']=hp;c['stats']['IsDM']=dm;cases.append(c)
for lock in [0,1]:
 for portrait in [0,65534,65535]:
  c=base(f'portrait-{lock}-{portrait}');c['locked']=lock;c['lower']['portraitId']=portrait;c['saved']['PortraitId']=portrait;cases.append(c)
for n in [0,255,256,65535,0xffffffff]:
 c=base('extended-'+str(n));c['stats']['StartingPackage']=n;c['stats']['Appearance_Head']=n&65535
 for name,o in partFields:c['stats'][name]=n&65535
 cases.append(c)
for lock in [0,1]:
 for mode in ['left','right','ammo','no-ammo','wield11','missing-name']:
  c=base(f'weapon-{lock}-{mode}');c['locked']=lock;c['bases']={'1':dict(equipableSlots=16,weaponWield=1,ranged=0,numDice=2,die=6),'2':dict(equipableSlots=2048,weaponWield=1,ranged=0,numDice=1,die=8)}
  c['items']={'152':dict(name='Right Weapon',base=1),'153':dict(name='Left Weapon',base=1),'154':dict(name='Ammo',base=2)};dest=c['savedCache']if lock else c['cache']
  if mode=='left':dest['weaponIds'][1]=153
  else:dest['weaponIds'][0]=152;dest['weaponIds'][1]=153
  if mode in ['ammo','no-ammo','wield11']:c['bases']['1']['ranged']=2
  if mode in ['ammo','wield11']:c['equipment']['2048']=154
  if mode=='wield11':c['bases']['1']['weaponWield']=11
  if mode=='missing-name':c['items']['152']['name']=None;c['items']['153']['name']=None
  cases.append(c)
rng=random.Random(4145)
for i in range(32):
 c=base('random-'+str(i));c['locked']=rng.randrange(2)
 for name,o,t in statFields:
  if t not in ['s','r','l','f']:c['stats'][name]=rng.randrange(1<<({'b':8,'w':16,'i':32}[t]))
 c['lower']['currentHP']=rng.randrange(-32768,32768);c['lower']['maximumHP']=rng.randrange(-32768,32768)
 for key in ['cache','savedCache']:c[key]['scalars']=[rng.randrange(256)for _ in range(32)];c[key]['flags']=rng.randrange(65536)
 cases.append(c)
for i in range(12):
 c=base('combat-only-'+str(i));c['combatOnly']=True;c['cache']['scalars']=[rng.randrange(256)for _ in range(32)]
 c['cache']['attackNodes']=[[rng.randrange(256)for _ in range(6)]for _ in range(i%5)];c['cache']['damageNodes']=[[rng.randrange(256)for _ in range(6)]for _ in range(i%4)];cases.append(c)
observations=[run(c)for c in cases]
out=m.root/'backups/animations/native-creature-stats-save-observations.json';out.write_text(json.dumps(dict(target=m.digest,cases=observations),indent=2)+'\n')
print(json.dumps(dict(cases=len(cases),output=str(out))))
