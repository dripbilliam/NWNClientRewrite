"""Original polymorph apply/remove, racial effect apply/remove, race feat loader
and membership. Original copy constructor/assignment and world seconds/addition
instructions execute. Captured lower base/allocation/string/2DA/object/HP/client
and nested effect providers. Full form transform/restoration are captured HERE,
not validated by this upper-owner fixture; no casting/render acceptance claim.
"""
import importlib,itertools,json,struct
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
actor,effect,ints,pool,vt,app,rules,timer,race,featpool,tvt,text=[m.heap+n*0x2000 for n in range(12)]
classarray=m.heap+0xa0000;stats=m.heap+0x1a000
ranges=[(0x1405180b0,0x140518a6e),(0x1403fa4a0,0x1403fa4d0),(0x140430950,0x140430bd8),(0x140437c80,0x140437efe),(0x140430be0,0x140430d74),(0x140437f00,0x140437f06),(0x1402a19e0,0x1402a1c39),(0x1402a19a0,0x1402a19d2),(0x140423570,0x140423768),(0x140423ce0,0x140423f86),(0x140423fc0,0x140423fcb),(0x140425210,0x14042521c),(0x1404251f0,0x14042520c),(0x140597010,0x14059703c),(0x140597140,0x140597177),(0x140596b40,0x140596b80)]
def allocate(size):
 global allocation
 ptr=m.heap+0x30000+allocation;allocation+=(size+15)&~15;assert allocation<0xc0000;return ptr
def string_at(ptr):
 value=m.q(ptr);return bytes(u.mem_read(value,m.si(ptr+8))).decode('cp1252')if value else''
def string(ptr,value):
 value=value.encode('cp1252');target=allocate(len(value)+1);u.mem_write(target,value+b'\0');m.wq(ptr,target if value else 0);m.wi(ptr+8,len(value))
def snapshot(ptr):
 flags=int.from_bytes(u.mem_read(ptr+10,2),'little')
 return dict(id=f'{m.q(ptr):016x}',type=int.from_bytes(u.mem_read(ptr+8,2),'little'),subtype=flags&~7,durationType=flags&7,duration=m.rf(ptr+12),expiryDay=m.si(ptr+16)&0xffffffff,expiryTime=m.si(ptr+20)&0xffffffff,creatorId=m.si(ptr+24)&0xffffffff,spellId=m.si(ptr+28),casterLevel=m.si(ptr+40),showIcon=m.si(ptr+36),exposed=m.si(ptr+32),bypassImmunity=m.si(ptr+0x108),propertyId=f'{m.q(ptr+0xf0):016x}',customTag=string_at(ptr+0xf8),integers=[m.si(m.q(ptr+0x48)+i*4)for i in range(m.si(ptr+0x40))],strings=[string_at(ptr+0x60+i*16)for i in range(6)],floats=[m.rf(ptr+0x50+i*4)for i in range(4)],objectIds=[m.si(ptr+0xc0+i*4)&0xffffffff for i in range(4)],vectors=[[m.rf(ptr+0xd0+j*12+i*4)for i in range(3)]for j in range(2)])
def live():return[m.q(pool+i*8)for i in range(m.si(actor+0x158))]
def set_live(values):
 m.wi(actor+0x158,len(values))
 for i,value in enumerate(values):m.wq(pool+i*8,value)
def base_construct(ptr,new):
 global ids
 ids+=int(new!=0);m.wq(ptr,100+ids if new else 0);m.wq(ptr+0x48,allocate(32));m.wi(ptr+0x40,8);m.wi(ptr+32,int(new!=0));m.wi(ptr+36,1);m.wi(ptr+24,0x7f000000);m.wi(ptr+28,-1);m.wi(ptr+40,-1)
 for i in range(4):m.wi(ptr+0xc0+i*4,0x7f000000)
def hook(u,a,n,_):
 global table,pops,output
 if a==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(r)for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
 if a==m.stop+0x10:m.finish(actor if c.get('creature',True)else 0)
 elif a==0x140286110:
  args=c.get('args',[]);ok=pops<len(args)and pops!=c.get('failPop',-1);calls.append(['pop',pops,int(ok)])
  if ok:m.wi(y,args[pops])
  pops+=1;m.finish(int(ok))
 elif a==0x140286330:output=snapshot(z);calls.append(['push']);m.finish(c.get('push',1))
 elif a==0x14055b3d0:calls.append(['creature',y&0xffffffff]);m.finish(actor if c.get('creature',True)else 0)
 elif a==0x1403fa4a0:calls.append(['classType',y&255])
 elif a==0x140401b30:calls.append(['featSource',y&65535]);m.finish(c.get('featSource',255))
 elif a in [0x14051872f,0x140518790,0x1405187e2]:calls.append(['classInfo',((y if a!=0x140518790 else x)-classarray)//0x530])
 elif a==m.stop+0x20:m.finish()
 elif a==0x1404953b0:calls.append(['dead']);m.finish(c.get('dead',0))
 elif a==0x140495620:calls.append(['dying']);m.finish(c.get('dying',0))
 elif a==0x1403d54d0:calls.append(['possessed']);m.finish(c.get('possessed',0))
 elif a in [0x140c10324,0x140c10368]:m.finish(allocate(x))
 elif a==0x1404233d0:base_construct(x,y);m.finish(x)
 elif a==0x140425110:m.wi(x+24,y);m.finish()
 elif a==0x140498280:
  calls.append(['remove',f'{y:016x}',[snapshot(p)for p in live()]]);set_live([p for p in live()if m.q(p)!=y]);m.finish(1)
 elif a==0x14048e350:calls.append(['apply',snapshot(y),z&0xffffffff]);m.finish(0)
 elif a==0x140399e20:
  calls.append(['transform',y&0xffffffff,snapshot(z),w&0xffffffff])
  if 'transformOverride'in c:m.wi(m.q(z+0x48)+8,c['transformOverride'])
  m.finish(c.get('transformResult',1))
 elif a==0x1403a5b50:calls.append(['untransform',snapshot(y)]);m.finish(c.get('transformResult',1))
 elif a==0x14055b390:calls.append(['client',y&0xffffffff]);m.finish(app if c.get('client',False)else 0)
 elif a==0x14055b810:m.finish(app)
 elif a==0x1404dede0:calls.append(['notify',z&0xffffffff,w&0xffffffff,m.si(rsp+0x28)]);m.finish()
 elif a==0x14055ba10:m.finish(timer)
 elif a==0x140597180:calls.append(['time']);m.wi(y,c.get('day',2));m.wi(z,c.get('time',100));m.finish()
 elif a==0x140596b40:calls.append(['addTime',y&0xffffffff,z&0xffffffff,w&0xffffffff,m.si(rsp+0x28)&0xffffffff])
 elif a==0x14018dea0:u.mem_write(x,bytes(17));m.finish(x)
 elif a==0x1401a62b0:table=x;m.wq(x,tvt);m.wi(x+0x50,c.get('count',len(c.get('entries',[]))));m.finish(x)
 elif a==0x1401a73a0:m.finish(1)
 elif a==0x1401a7010:
  column=string_at(z);assert column=='FeatIndex';rows=c.get('entries',[]);value=rows[y]if y<len(rows)else None;calls.append(['int',y,column,value is not None]);m.wi(w,value if value is not None else 0);m.finish(int(value is not None))
 elif a==0x14003d8c0:string(x,bytes(u.mem_read(y,z)).decode('cp1252'));m.finish(x)
 elif a==0x140c42060:u.mem_write(x,bytes(z));m.finish(x)
 elif a==0x140047300:u.mem_write(x,bytes(12));m.finish(x)
 elif a==0x140169e90:m.finish(int(string_at(x)!=string_at(y)))
 elif a==0x140c10410:m.finish(u.reg_read(UC_X86_REG_RAX))
 elif a in [0x140c10370,0x140c10360,0x140423770,0x140c11414]:m.finish()
 elif not any(lo<=a<hi for lo,hi in ranges):raise RuntimeError(f'Unexpected polymorph effect dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,calls,allocation,ids,table,pops,output
 c=case;calls=[];allocation=ids=pops=0;table=0;output=None;u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));m.wq(actor,vt);m.wq(vt+0x60,m.stop+0x10);m.wq(tvt,m.stop+0x20);m.wi(actor+8,99);m.wi(actor+0x97c,c.get('locked',0));m.wi(actor+0x9f8,c.get('overrideFlag',0));m.wi(actor+0x89c,c.get('pc',0));m.wi(actor+0xf0,c.get('destroyable',1));u.mem_write(actor+0x908,struct.pack('<H',c.get('associate',0)&65535));m.wq(actor+0x150,pool);m.wq(0x1412df970,app);m.wq(app+8,app);m.wq(0x1412df8f8,rules);m.wq(rules+0x118,race);m.wi(timer+0x30,c.get('dayLength',7200000));m.wi(timer+0x34,c.get('dayLength',7200000)//1000)
 base_construct(effect,0);m.wq(effect,77);m.wq(effect+0x48,ints);m.wi(effect+40,7);m.wi(effect+28,11);m.wi(effect+24,98);m.wi(effect+32,1);m.wi(effect+36,c.get('icon',1));m.wf(effect+12,3.25);m.wi(effect+16,2);m.wi(effect+20,100);m.wi(effect+0x108,1);m.wq(effect+0xf0,123);string(effect+0xf8,'fixture');u.mem_write(effect+8,struct.pack('<HH',68 if c['mode']=='racial'else 62,c.get('subtype',8)|c.get('durationType',2)))
 for i,value in enumerate(c.get('integers',[0,0,0,0,0,1,255,0])):m.wi(ints+i*4,value)
 previous=[]
 for v in c.get('effects',[]):
  p=allocate(0x110);u.mem_write(p,bytes(u.mem_read(effect,0x110)));m.wq(p,v.get('id',78));u.mem_write(p+8,struct.pack('<H',v.get('type',62)));m.wq(p+0x48,allocate(32));previous.append(p)
 set_live(previous)
 feats=c.get('feats',[]);m.wq(race+0x28,0 if c.get('nullList',False)else featpool);u.mem_write(race+0x24,struct.pack('<H',len(feats)&65535))
 for i,value in enumerate(feats):u.mem_write(featpool+i*2,struct.pack('<H',value&65535))
 mode=c['mode'];entry={'constructor':0x1405180b0,'apply':0x140430950,'remove':0x140437c80,'racial':0x140430be0,'racialRemove':0x140437f00,'loader':0x1402a19e0,'query':0x1402a19a0}[mode];args=[app,actor,effect,c.get('loading',0)]
 if mode=='loader':args=[race,text]
 elif mode=='query':args=[race,c.get('feat',228)]
 elif mode=='constructor':
  args=[text,463,c.get('argc',len(c.get('args',[])))];m.wi(text+12,99);m.wq(actor+0xad0,stats);u.mem_write(actor+0x22c,bytes([c.get('classIndex',0)&255]));u.mem_write(actor+0x23c,struct.pack('<H',c.get('feat',65535)&65535));m.wq(rules+0x110,classarray)
  values=c.get('classes',[10,5]);u.mem_write(stats+0xd8,bytes([len(values)&255]))
  for i,value in enumerate(values):u.mem_write(stats+0x25c+i*0x188,bytes([value&255]))
  for i in range(256):
   info=c.get('classInfo',{}).get(str(i),{});u.mem_write(classarray+i*0x530+0x4e8,bytes([info.get('casting',3)&255]));u.mem_write(classarray+i*0x530+0x49a,bytes([info.get('primary',0)&255]))
 before=snapshot(effect);initial=[snapshot(p)for p in live()];rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],args):u.reg_write(reg,value&0xffffffffffffffff)
 try:u.emu_start(entry,m.stop,count=100000)
 except Exception:print(json.dumps(dict(case=c,rip=hex(u.reg_read(UC_X86_REG_RIP)),calls=calls)));raise
 assert u.reg_read(UC_X86_REG_RIP)==m.stop
 result=u.reg_read(UC_X86_REG_RAX)&0xffffffff
 return dict(case=c,before=before,initial=initial,result=None if mode=='loader'else result,calls=calls,effect=snapshot(effect),effects=[snapshot(p)for p in live()],overrideFlag=m.si(actor+0x9f8),feats=[int.from_bytes(u.mem_read(m.q(race+0x28)+i*2,2),'little')for i in range(int.from_bytes(u.mem_read(race+0x24,2),'little'))]if mode=='loader'else None,output=output)
rows=[]
for creature,loading,dead,dying,duration,associate,locked,override in itertools.product([False,True],[0,1],[0,1],[0,1],[0,1,2,3,4],[0,7,8],[0,1],[0,1]):rows.append(run(dict(mode='apply',creature=creature,loading=loading,dead=dead,dying=dying,durationType=duration,associate=associate,locked=locked,overrideFlag=override)))
for previous,form,rawOverride,client,result in itertools.product([[],[dict(id=77)],[dict(type=61),dict(id=77),dict(id=78),dict(id=79)]],[-1,0,44],[0,1,-1],[False,True],[0,1]):rows.append(run(dict(mode='apply',effects=previous,integers=[form,0,rawOverride,0,0,1,255,0],client=client,transformResult=result,transformOverride=rawOverride)))
for creature,dead,pc,possessed,destroyable,stage,override in itertools.product([False,True],[0,1],[0,1],[0,1],[0,1],[0,1],[0,1,-1]):rows.append(run(dict(mode='remove',creature=creature,dead=dead,pc=pc,possessed=possessed,destroyable=destroyable,integers=[44,stage,override,0,0,1,255,0],client=True)))
for custom,visual,override,client,time in itertools.product([0,1],[-1,0,85,999],[0,1],[False,True],[100,7199800]):rows.append(run(dict(mode='remove',integers=[44,0,override,custom,visual,1,255,0],client=client,time=time)))
for feats,creature,loading,duration,subtype in itertools.product([[],[228],[354],[228,354],[354,228,228]],[False,True],[0,1],[0,1,2,3,4],[0,8,16,32]):rows.append(run(dict(mode='racial',feats=feats,creature=creature,loading=loading,durationType=duration,subtype=subtype)))
for feats,feat,nullList in itertools.product([[],[0],[228],[354],[228,354],[65535],[0,228,228]],[-1,0,228,354,65889],[False,True]):rows.append(run(dict(mode='query',feats=feats,feat=feat,nullList=nullList)))
for entries,count in itertools.product([[],[228],[354,228,None,65889],[None,-1,65536,65535]],[0,1,4,65536,65537]):rows.append(run(dict(mode='loader',entries=entries,count=count)))
rows.append(run(dict(mode='racialRemove')))
constructors=[]
for argc,ability,creature,slot,feat,source,casting,primary in itertools.product([1,2,5],[-1,0,5,6],[False,True],[0,1,253,254,255],[65535,289],[10,255],[3,255],[0,255]):
 constructors.append(run(dict(mode='constructor',args=[44,-1,-1,ability,17][:argc],creature=creature,classIndex=slot,feat=feat,featSource=source,classInfo={str(i):dict(casting=casting,primary=primary)for i in [5,10,255]})))
for args,argc in [([],0),([44,0,85],3),([44,0,85,2],4),([-1,0,999,2,-1],5),([44,0,85,-2147483648,0],5),([44,0,85,2147483647,0],5)]:constructors.append(run(dict(mode='constructor',args=args,argc=argc)))
for index in range(5):constructors.append(run(dict(mode='constructor',args=[44,0,85,2,0],failPop=index)))
constructors.append(run(dict(mode='constructor',args=[44,0,85,2,0],push=0)))
out=m.root/'backups/animations/native-polymorph-effect-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows,constructors=constructors),indent=2)+'\n');print(json.dumps(dict(rows=len(rows),constructors=len(constructors),output=str(out))))
