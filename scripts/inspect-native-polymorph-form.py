"""Full original Polymorph/UnPolymorph coordinators with captured lower
2DA/string/allocation/combat-stat/equipment/effect/area owners. Original AC
snapshot arithmetic and saved-state writes execute. Not a native full-spell,
renderer, saved-game or multiplayer acceptance claim.
"""
import importlib,itertools,json,struct
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
actor,stats,vt,app,rules,twodas,table,equipment,area,path,pool,parent=[m.heap+n*0x2000 for n in range(12)]
ranges=[(0x140399e20,0x14039b3d7),(0x1403a5b50,0x1403a6150),(0x1403aafd0,0x1403aafef),(0x140423fc0,0x140423fcb),(0x140425210,0x14042521c)]

def allocate(size):
 global allocation
 ptr=m.heap+0x30000+allocation;allocation+=(size+15)&~15;assert allocation<0xd0000;return ptr
def wb(a,v):u.mem_write(a,bytes([v&255]))
def ww(a,v):u.mem_write(a,struct.pack('<H',v&65535))
def rw(a):return int.from_bytes(u.mem_read(a,2),'little')
def rb(a):return u.mem_read(a,1)[0]
def cstr(a):return bytes(u.mem_read(a,128)).split(b'\0')[0].decode('cp1252')if a else''
def text(a):return bytes(u.mem_read(m.q(a),m.si(a+8))).decode('cp1252')if m.q(a)else''
def string(a,value):
 b=value.encode('cp1252');p=allocate(len(b)+1);u.mem_write(p,b+b'\0');m.wq(a,p if b else 0);m.wi(a+8,len(b))
def ref(a,value):u.mem_write(a,value.lower().split('\0')[0].encode('cp1252')[:16].ljust(17,b'\0'))
def point(a):return[m.rf(a+i*4)for i in range(3)]
def write_point(a,v):
 for i,x in enumerate(v):m.wf(a+i*4,x)
def effect(a):return dict(type=rw(a+8),durationType=rw(a+10)&7,creatorId=m.si(a+24)&0xffffffff,integers=[m.si(m.q(a+0x48)+i*4)for i in range(8)],id=f'{m.q(a):016x}')
def create_effect(a,new):
 global nextEffect
 nextEffect+=int(new!=0);m.wq(a,100+nextEffect if new else 0);m.wq(a+0x48,allocate(32));m.wi(a+0x40,8);m.wi(a+24,0x7f000000)
def live():return[m.q(pool+n*8)for n in range(m.si(actor+0x158))]
def set_live(values):
 values=sorted(values,key=lambda a:rw(a+8));m.wi(actor+0x158,len(values))
 for n,a in enumerate(values):m.wq(pool+n*8,a)
 ww(stats+0xd90,next((n for n,a in enumerate(values)if rw(a+8)==15),len(values)))
def item(a):return m.si(a+0x50)&0xffffffff
def hook(u,a,n,_):
 global nextItem,deadCount,portraitId
 if a==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(r)for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
 if a in [0x140c10324,0x140c10368]:m.finish(allocate(x))
 elif a in [0x140c10370,0x140c10360,0x1402a2930]:m.finish()
 elif a==0x140c10410:m.finish(u.reg_read(UC_X86_REG_RAX))
 elif a==m.stop+0x10:m.finish(portraitId)
 elif a==m.stop+0x20:portraitId=y&65535;m.finish()
 elif a==m.stop+0x30:m.finish(c.get('maximumHP',23))
 elif a==m.stop+0x40:calls.append(['currentHP',y&0xffffffff]);m.finish(c.get('currentHP',8))
 elif a==m.stop+0x50:calls.append(['destroyItem',item(x)]);items.pop(item(x),None);m.finish(x)
 elif a in closure_dtors:m.finish(x)
 elif a==0x1401a7010:
  column=text(z);entry=c.get('ints',{}).get(column)if (y&0xffffffff)<c.get('rowCount',64)else None;calls.append(['int',column]);m.wi(w,entry if entry is not None else 0);m.finish(int(entry is not None))
 elif a==0x1401a68f0:
  column=text(z);entry=c.get('strings',{}).get(column)if (y&0xffffffff)<c.get('rowCount',64)else None;calls.append(['string',column]);string(w,entry or'');m.finish(int(entry is not None and entry!=''))
 elif a==0x1402a2120:calls.append(['copyCombatInformation']);u.mem_write(x,bytes([0x6a])*0x70);m.finish(x)
 elif a==0x1402ae870:m.finish(0)
 elif a==0x1402a4130:m.finish(c.get('dodgeLimit',20))
 elif a==0x1403f3e90:m.finish(c.get('natural',2))
 elif a==0x14040a7f0:m.finish(c.get('tumble',3))
 elif a==0x1403fd280:m.finish(c.get('dexModifier',4))
 elif a==0x1403f8e90:m.finish(c.get('baseAttack',7))
 elif a in [0x1404024c0,0x140406820,0x14040b7f0]:m.finish(c.get({0x1404024c0:'fortitude',0x140406820:'reflex',0x14040b7f0:'will'}[a],5))
 elif a in [0x1404167d0,0x1404152a0,0x140415530]:
  ability,offset={0x1404167d0:(0,0xd38),0x1404152a0:(2,0xd3c),0x140415530:(1,0xd3a)}[a];calls.append(['setBaseAbility',ability,y&255,z&0xffffffff if ability==2 else 0]);wb(stats+offset,y);m.finish()
 elif a==0x14018de80:u.mem_write(x,bytes(u.mem_read(y,17)));m.finish(x)
 elif a==0x14018dea0:ref(x,text(y));m.finish(x)
 elif a==0x14018ded0:ref(x,cstr(y));m.finish(x)
 elif a==0x14003d8c0:string(x,bytes(u.mem_read(y,z)).decode('cp1252'));m.finish(x)
 elif a==0x14016ab00:string(y,text(x)+text(z));m.finish(y)
 elif a==0x140462bd0:calls.append(['equipped',y&0xffffffff]);m.finish(equipped.get(y&0xffffffff,0))
 elif a==0x1403a6150:
  calls.append(['unequip',item(y),z&0xffffffff,w&0xffffffff]);equipped.pop(next(k for k,v in equipped.items()if v==y),None);m.finish(1)
 elif a==0x14038c1c0:
  calls.append(['equip',y&0xffffffff,item(z),w&0xffffffff,m.si(rsp+0x28),m.si(rsp+0x30)]);equipped[y&0xffffffff]=z;m.finish(1)
 elif a==0x14055b6c0:calls.append(['item',y&0xffffffff]);m.finish(items.get(y&0xffffffff,0))
 elif a==0x140462e90:
  nextItem+=1;ident=2000+nextItem;m.wq(x,vt+0x400);m.wi(x+0x50,ident);items[ident]=x;calls.append(['constructItem',ident]);m.finish(x)
 elif a==0x14046a7c0:
  name=cstr(y);calls.append(['loadItem',item(x),name]);m.finish(int(name not in c.get('failItems',[])))
 elif a==0x14046c420:calls.append(['identified',item(x),y&0xffffffff]);m.finish()
 elif a==0x1404233d0:create_effect(x,y);m.finish(x)
 elif a==0x140423570:
  # Captured copy-constructor0 lower owner (separately verified fixture).
  create_effect(x,0);m.wq(x,m.q(y));m.wi(x+24,m.si(y+24));ww(x+10,rw(y+10));m.finish(x)
 elif a==0x140425110:m.wi(x+24,y);m.finish()
 elif a==0x14048e350:calls.append(['apply',effect(y),z&0xffffffff]);set_live(live()+[y]);m.finish(0)
 elif a==0x140498280:
  calls.append(['remove',f'{y:016x}']);set_live([v for v in live()if m.q(v)!=y]);m.finish(1)
 elif a==0x1403a7c50:calls.append(['personalSpace']);m.finish()
 elif a==0x1403a69f0:calls.append(['appearanceInfo']);m.finish()
 elif a==0x140494e80:m.finish(area if c.get('area',False)and m.si(actor+0xa0)!=0x7f000000 else 0)
 elif a==0x14036aa90:
  calls.append(['safeLocation',point(y),m.xmm(UC_X86_REG_XMM2),m.si(rsp+0x28)]);write_point(m.q(rsp+0x30),c.get('safePoint',[9,8,7]));m.finish(c.get('safeResult',1))
 elif a==0x14049bb40:calls.append(['setPosition',point(y),z&0xffffffff]);write_point(actor+0xa4,point(y));m.finish()
 elif a==0x14039e6b0:calls.append(['removeFromArea',y&0xffffffff]);m.wi(actor+0xa0,0x7f000000);write_point(actor+0xa4,[0,0,0]);m.finish()
 elif a==0x140380470:
  v=[m.xmm(UC_X86_REG_XMM2),m.xmm(UC_X86_REG_XMM3),m.rf(rsp+0x28)];calls.append(['addToArea',v,m.si(rsp+0x30),m.si(rsp+0x38)]);m.wi(actor+0xa0,98);write_point(actor+0xa4,v);m.finish()
 elif a==0x1404953b0:
  calls.append(['dead']);values=c.get('dead',[0,0]);m.finish(values[min(deadCount,len(values)-1)]);deadCount+=1
 elif not any(lo<=a<hi for lo,hi in ranges):raise RuntimeError(f'Unexpected polymorph form dependency {a:x}')
closure_dtors={m.q(v+0x20)for v in [0x140ddf138,0x140ddf170]}
u.hook_add(UC_HOOK_CODE,hook)

def run(case):
 global c,calls,allocation,nextEffect,nextItem,items,equipped,deadCount,portraitId
 c=case;calls=[];allocation=nextEffect=nextItem=deadCount=0;items={};equipped={};u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));portraitId=c.get('portraitId',65535)
 m.wq(actor,vt);m.wq(vt+0x1a8,m.stop+0x10);m.wq(vt+0x1b0,m.stop+0x20);m.wq(vt+0x130,m.stop+0x30);m.wq(vt+0x138,m.stop+0x40);m.wq(vt+0x400,m.stop+0x50);m.wi(actor+8,99);m.wq(actor+0xad0,stats);m.wq(actor+0x950,equipment);m.wq(actor+0x530,path);m.wq(actor+0x150,pool);m.wi(actor+0xa0,98);write_point(actor+0xa4,[1,2,3]);m.wi(actor+0xe0,8)
 m.wq(0x1412df8f8,rules);m.wq(rules+0x130,twodas);m.wq(twodas+0x3c0,0 if c.get('noTable',False)else table);m.wi(table+0x50,c.get('rowCount',64));m.wq(0x1412df970,app);m.wq(app+8,app)
 m.wi(actor+0x97c,c.get('locked',0));m.wi(actor+0x9f4,0);m.wi(actor+0x9fc,c.get('reuse',0));ww(actor+0xa74,5);ww(stats+0xdec,5);ww(stats+0xd20,2);ww(actor+0x8a0,3);ref(stats+0xdd2,'po_original_')
 for offset,v in [(0xd38,11),(0xd3c,13),(0xd3a,12)]:wb(stats+offset,v)
 for offset,v in zip(range(0xd45,0xd51),c.get('cache',[2,3,4,1,5,2,6,1,7,2,8,3])):wb(stats+offset,v)
 m.wq(stats+0xd70,allocate(0x70));m.wq(actor+0xa48,allocate(0x70))
 for n in range(18):
  for offset,key in [(0x980,'saved'),(0xa00,'shape')]:
   ident=c.get(key,{}).get(str(n),0x7f000000);m.wi(actor+offset+n*4,ident)
   if ident!=0x7f000000 and ident not in items:
    p=allocate(0x470);m.wq(p,vt+0x400);m.wi(p+0x50,ident);items[ident]=p
 for ns,ident in c.get('equipped',{}).items():
  p=allocate(0x470);m.wq(p,vt+0x400);m.wi(p+0x50,ident);items[ident]=p;equipped[1<<int(ns)]=p
 for offset,v in [(0x9dc,17),(0x9da,c.get('savedPortraitId',65535)),(0x9e2,6),(0x9e4,7)]:ww(actor+offset,v)
 for offset,v in [(0x9de,21),(0x9df,23),(0x9e0,22)]:wb(actor+offset,v)
 ref(actor+0x9c8,'po_saved_')
 create_effect(parent,0);m.wq(parent,77);m.wi(parent+24,98);ww(parent+8,62);ww(parent+10,9)
 values=[]
 for n,spec in enumerate(c.get('effects',[])):
  e=allocate(0x110);create_effect(e,0);m.wq(e,n+500);ww(e+8,spec['type']);ww(e+10,spec.get('durationType',2));m.wi(m.q(e+0x48)+4,spec.get('integer1',0));values.append(e)
 set_live(values)
 mode=c.get('mode','transform');args=[actor,c.get('form',3),parent if c.get('parent',True)else 0,c.get('loading',0)]if mode=='transform'else[actor,parent if c.get('parent',True)else 0]
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 for r,v in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],args):u.reg_write(r,v&0xffffffffffffffff)
 try:u.emu_start(0x140399e20 if mode=='transform'else 0x1403a5b50,m.stop,count=200000)
 except Exception:print(json.dumps(dict(case=c,rip=hex(u.reg_read(UC_X86_REG_RIP)),calls=calls)));raise
 assert u.reg_read(UC_X86_REG_RIP)==m.stop
 state=dict(appearance=rw(actor+0xa74),race=rw(stats+0xd20),sound=rw(actor+0x8a0),portraitId=portraitId,portrait=cstr(stats+0xdd2),base=[rb(stats+v)for v in [0xd38,0xd3a,0xd3c]],locked=m.si(actor+0x97c),transition=m.si(actor+0x9f4),reuse=m.si(actor+0x9fc),natural=rb(stats+0xd51),overrides=[m.si(actor+v)for v in [0x9e8,0x9ec,0x9f0]],saved=[m.si(actor+0x980+n*4)&0xffffffff for n in range(18)],shape=[m.si(actor+0xa00+n*4)&0xffffffff for n in range(18)],savedAppearance=rw(actor+0x9dc),savedPortraitId=rw(actor+0x9da),savedPortrait=cstr(actor+0x9c8),savedBase=[rb(actor+v)for v in [0x9de,0x9e0,0x9df]],savedRace=rw(actor+0x9e2),savedSound=rw(actor+0x9e4),armor=struct.unpack('<h',u.mem_read(actor+0xa50,2))[0],baseAttack=m.si(actor+0xa54),maximumHP=struct.unpack('<h',u.mem_read(actor+0xa58,2))[0],saves=[rb(actor+v)for v in [0xa5a,0xa5b,0xa5c]],hp=m.si(actor+0xe0),position=point(actor+0xa4),equipped={str(k):item(v)for k,v in equipped.items()},items=sorted(items),effects=[effect(v)for v in live()])
 return dict(case=c,result=u.reg_read(UC_X86_REG_RAX)&0xffffffff,calls=calls,state=state)

rows=[]
base=dict(AppearanceType=14,RacialType=5,SoundSet=12,STR=20,CON=18,DEX=16,NATURALACBONUS=5,HPBONUS=10,Spell1=123,Spell2=-1,Spell3=456)
for loading,reuse,equipped,area_,safe,parent_ in itertools.product([0,1],[0,1],[{},dict(Equipped='sword'),dict(CreatureWeapon1='claw',CreatureWeapon2='bite',CreatureWeapon3='talon',HideItem='hide')],[False,True],[0,1],[False,True]):
 rows.append(run(dict(loading=loading,reuse=reuse,strings=equipped,area=area_,safeResult=safe,parent=parent_,ints=base,equipped={'1':1001,'4':1004,'11':1011,'17':1017},shape={'0':1100,'17':1117},effects=[dict(type=68)])))
for form,locked,noTable,appearance in itertools.product([-1,0,63,64],[0,1],[False,True],[None,0,-1,65536]):rows.append(run(dict(form=form,locked=locked,noTable=noTable,ints={}if appearance is None else dict(AppearanceType=appearance))))
for portraitId,portrait,values,hp in itertools.product([None,0,65534,65535,65536,-1],[None,'tiny','abcdefghijklmnopqrst'],[{},dict(STR=256,CON=-1,DEX=65536,NATURALACBONUS=-2,HPBONUS=-5)],[-1,0,1]):
 ints=dict(AppearanceType=12,**values);strings={}
 if portraitId is not None:ints['PortraitId']=portraitId
 if portrait is not None:strings['Portrait']=portrait
 rows.append(run(dict(ints=ints,strings=strings,currentHP=hp)))
for locked,portraitId,parent_,area_,safe,dead,hp in itertools.product([0,1],[0,65533,65534,65535],[False,True],[False,True],[0,1],[[0,0],[0,1],[1,0],[1,1]],[-1,0,1]):
 rows.append(run(dict(mode='restore',locked=locked,savedPortraitId=portraitId,parent=parent_,area=area_,safeResult=safe,dead=dead,currentHP=hp,equipped={'4':2001,'14':2002,'17':2003},saved={'1':1001,'11':1011},effects=[dict(type=15,integer1=2),dict(type=15,integer1=0,durationType=4),dict(type=15,integer1=1),dict(type=68)])))
rows.append(run(dict(ints=base,strings=dict(Equipped='broken',CreatureWeapon1='ignored',HideItem='hide'),failItems=['broken','hide'])))
out=m.root/'backups/animations/native-polymorph-form-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2)+'\n');print(json.dumps(dict(rows=len(rows),output=str(out))))
