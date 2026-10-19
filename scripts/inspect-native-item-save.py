"""Complete original SaveItem and SaveItemProperties with original extended
GFF writer. Generic object-state, visuals, UUID, price calculation and resref
conversion are captured boundaries. Recursion, repository order/coordinate
snapshots, flags, property selection and dirty-price mutation execute natively.
"""
import importlib,sys,json,copy,random,struct
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
gff,root,rules,baseArray,app=[m.heap+n*0x2000 for n in range(1,6)];allocation=m.heap+0x30000
ranges=[]
for name in ['item-save-owner','item-save-properties-owner','stats-save-word-and-byte','item-save-template-resref','item-save-resref-init']:
 d=json.loads((m.root/'backups/animations'/('rea-'+name+'.json')).read_text())['structuredContent']['normalized_result'];ranges.extend((int(r['start'],16),int(r['end'],16)+1)for r in d['procedure']['body']['ranges'])
scalarFields={0x40:'baseItem',0x360:'identified',0x454:'stackSize',0x458:'stolen',0x468:'hidden',0x448:'droppable',0x44c:'pickpocketable',0x450:'cursed',0x388:'charges',0x144:'plot',0x398:'dirty',0x390:'unidentifiedPrice',0x394:'addCost',0x38c:'basePrice',0x2ac:'useable'}
strings={0x68:'tag',0x78:'template',0x410:'descriptionOverride',0x400:'identifiedOverride',0x430:'display'}
localized={0x3f0:'description',0x3e0:'identifiedDescription',0x420:'name'}
visuals={0x140499c10:('animationOverrides','AnimationSaved'),0x140499f20:('materialOverrides','MaterialSaved'),0x14049a230:('miscVisuals','MiscSaved'),0x14049a640:('textureOverrides','TextureSaved'),0x14049a780:('visualTransform','TransformSaved'),0x140505c70:('uuid','UUIDSaved'),0x14049a350:('objectState','StateSaved')}
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
def text(p):return bytes(u.mem_read(m.q(p),m.si(p+8))).decode('ascii')if m.q(p)else''
def exo(p,s):
 b=s.encode('ascii');a=alloc(len(b)+1);u.mem_write(a,b+b'\0');m.wq(p,a);m.wi(p+8,len(b));m.wi(p+12,len(b)+1)
def word(p,v):u.mem_write(p,(v&65535).to_bytes(2,'little'))
def byte(p,v):u.mem_write(p,bytes([v&255]))
def node(t):nodes.append(dict(fields={},type=t));return len(nodes)-1
def addField(n,label,t,v):
 if label in nodes[n]['fields']:nodes[n]['fields'][label]['value']=v;return
 ptr=alloc(16);nodes[n]['fields'][label]=dict(type=t,value=v);fieldRecords.append((ptr,n,label,t));fieldIds[n,label]=len(fieldRecords)-1
 if t in [0,2,4,5]:m.wi(ptr+8,v)
types={0x1401a2a80:0,0x1401a36f0:2,0x1401a31d0:4,0x1401a34f0:5,0x1401a3350:8,0x1401a2d30:10,0x1401a2ec0:11,0x1401a2b20:12}
def norm(v,t):
 if t==0:return v&255
 if t==2:return v&65535
 if t==4:return v&0xffffffff
 if t==5:return (v&0xffffffff)-0x100000000 if v&0x80000000 else v&0xffffffff
 return v
def hook(u,a,n,_):
 if a==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(r)for r in[UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
 if a in types:
  t=types[a]
  if t==8:v=struct.unpack('<f',struct.pack('<I',u.reg_read(UC_X86_REG_XMM2)&0xffffffff))[0]
  elif t==10:v=text(z)
  elif t==11:v=string(z)[:16]
  elif t==12:v=locs[z]
  else:v=norm(z,t)
  addField(m.si(y),string(w)[:16],t,v);m.finish(1);return
 if a==0x14019f1e0:
  values=[];lists.append(values);addField(m.si(z),string(w)[:16],15,values);m.wi(y,len(lists)-1);m.finish(1);return
 if a==0x14019f2b0:
  idx=node(w&0xffffffff);lists[m.si(z)].append(nodes[idx]);m.wi(y,idx);m.finish(1);return
 if a==0x14019fcc0:m.finish(fieldIds.get((m.si(y),string(z)[:16]),0xffffffff));return
 if a==0x14019fc20:m.finish(fieldRecords[z][0]if z<len(fieldRecords)else 0);return
 if a==0x14019edb0:addField(m.si(y),string(z)[:16],w&0xffffffff,0);m.finish(fieldRecords[fieldIds[m.si(y),string(z)[:16]]][0]);return
 if a==0x140085bd0:
  assert string(z)=='%s%s';b=(string(w)+string(m.q(rsp+0x28))).encode('ascii');u.mem_write(x,b[:y-1]+b'\0');m.finish(len(b));return
 if a==0x140047000:
  assert string(y)=='APart_%d_Col_%d';b=f'APart_{z&0xffffffff}_Col_{w&0xffffffff}'.encode('ascii');u.mem_write(x,b+b'\0');m.finish(len(b));return
 if a==0x1401693c0:locs[x]=copy.deepcopy(locs[y]);u.mem_write(x,bytes(16));m.finish(x);return
 if a==0x14029ca00:
  id=y&0xffffffff;calls.append(['base',id]);m.finish(basePtrs[id]);return
 if a==0x14029dd60:
  id=itemKeys[x];channel=y&255;part=z&255;calls.append(['partColor',id,channel,part]);m.finish(c['items'][id]['partColors'][channel][part]);return
 if a==0x140464e10:
  id=itemKeys[x];calls.append(['calculate',id]);item=c['items'][id]
  for off,key in [(0x38c,'basePrice'),(0x390,'unidentifiedPrice')]:m.wi(x+off,item['calculated'][key])
  m.finish();return
 if a==0x1401690b0:m.finish(nodeValues.get(y,0));return
 if a==0x140169110:m.wq(y,nodeNext[m.q(y)]);m.finish();return
 if a==0x14055b6c0:
  id=y&0xffffffff;calls.append(['item',id]);m.finish(itemPtrs.get(str(id),0));return
 if a in visuals:
  name,label=visuals[a];offset=0x330 if name=='uuid'else 0x48;ptr=x-offset;id=itemKeys[ptr];calls.append([name,id]);addField(m.si(z),label,5,int(id))
  if name=='objectState'and c['items'][id].get('moveOnState'):
   byte(ptr+0x3d8,91);byte(ptr+0x3d9,92)
  m.finish();return
 if a==0x140c10410:m.finish(u.reg_read(UC_X86_REG_RAX));return
 if not any(lo<=a<hi for lo,hi in ranges):raise RuntimeError(f'Uncaptured item-save dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def fillProperties(ptr,offset,entries):
 array=alloc(max(1,len(entries))*48);m.wq(ptr+offset,array);m.wi(ptr+offset+8,len(entries));m.wi(ptr+offset+12,len(entries))
 for i,p in enumerate(entries):
  r=array+i*48
  for off,key in [(0,'type'),(2,'subtype'),(6,'costValue')]:word(r+off,p[key])
  for off,key in [(4,'costTable'),(8,'param1'),(9,'param1Value'),(10,'chance'),(16,'usesPerDay'),(17,'durationType')]:byte(r+off,p[key])
  m.wi(r+12,p['remaining']);exo(r+24,p['customTag'])
def run(case):
 global c,cursor,nodes,lists,locs,fieldIds,fieldRecords,calls,itemPtrs,itemKeys,basePtrs,nodeValues,nodeNext
 c=case;cursor=0;nodes=[];lists=[];locs={};fieldIds={};fieldRecords=[];calls=[];itemPtrs={};itemKeys={};basePtrs={};nodeValues={};nodeNext={}
 u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));m.wq(0x1412df8f8,rules);m.wq(rules+0x20,baseArray);m.wq(0x1412df970,app);m.wq(app+8,app)
 for id,b in c['bases'].items():
  p=alloc(0x200);basePtrs[int(id)]=p;byte(p+0x16,b['modelType']);word(p+0x24,b['stacking']);m.wi(p+0x80,b['container'])
 for id,item in c['items'].items():
  p=alloc(0x500);itemPtrs[id]=p;itemKeys[p]=id
  for off,key in scalarFields.items():m.wi(p+off,item[key])
  for off,key in strings.items():exo(p+off,item[key])
  for off,key in localized.items():locs[p+off]=item[key]
  for kind,off in [('modelParts',0x39c),('armorParts',0x3a2)]:
   for i,v in enumerate(item[kind]):word(p+off+i*2,v)
  for i,v in enumerate(item['colors']):byte(p+8+i,v)
  for i,v in enumerate(item['position']+item['orientation']):m.wf(p+0xec+i*4,v)
  byte(p+0x3d8,item['x']);byte(p+0x3d9,item['y']);fillProperties(p,0x368,item['active']);fillProperties(p,0x378,item['passive'])
  if item['repository']is not None:
   repo=alloc(64);linked=alloc(32);m.wq(p+0x3d0,repo);m.wq(repo+0x10,linked);previous=0
   for id in item['repository']:
    n=alloc(24)
    if not previous:m.wq(linked,n)
    else:nodeNext[previous]=n
    nodeNext[n]=0;previous=n
    if id is not None:val=alloc(4);m.wi(val,id);nodeValues[n]=val
 node(0xffffffff);m.wi(root,0);rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 entry=0x14046c130 if c.get('propertiesOnly')else 0x14046b760
 for r,v in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],[itemPtrs['101'],gff,root,c['flag']&0xffffffff]):u.reg_write(r,v)
 try:u.emu_start(entry,m.stop,count=500000)
 except Exception:print(json.dumps(dict(case=c['name'],rip=hex(u.reg_read(UC_X86_REG_RIP)),calls=calls[-6:])));raise
 assert u.reg_read(UC_X86_REG_RIP)==m.stop,(c['name'],hex(u.reg_read(UC_X86_REG_RIP)))
 for p,n,label,t in fieldRecords:
  if t in [0,2,4,5]:nodes[n]['fields'][label]['value']=norm(m.si(p+8)&0xffffffff,t)
 state={id:{key:m.si(p+off)for off,key in scalarFields.items()}for id,p in itemPtrs.items()}
 return dict(case=c,output=nodes[0],calls=calls,state=state)
def prop(n,duration=2):return dict(type=n,subtype=65535,costTable=255,costValue=258,param1=255,param1Value=254,chance=100,usesPerDay=7,remaining=257,durationType=duration,customTag='Tag\0tail')
def item(base=1):
 v={key:0 for key in scalarFields.values()};v.update(baseItem=base,identified=1,stackSize=2,charges=5,droppable=1,pickpocketable=1,basePrice=10,addCost=2,unidentifiedPrice=3,dirty=1,useable=1)
 v.update({key:key for key in strings.values()});v['template']='MiXeD_Template_TooLong';v['tag']='ItemTag'
 v.update({key:dict(strRef=0xffffffff,entries=[dict(languageId=0,text=key)])for key in localized.values()})
 v.update(modelParts=[1,256,65535],armorParts=list(range(19)),colors=list(range(6)),partColors=[[255]*19 for _ in range(6)],active=[prop(15),prop(35,1)],passive=[prop(0),prop(1,0)],position=[1.25,-2.5,3.75],orientation=[0,1,0],repository=None,x=4,y=5,calculated=dict(basePrice=17,unidentifiedPrice=9));return v
def base(name):return dict(name=name,flag=0,items={'101':item()},bases={'1':dict(modelType=0,stacking=10,container=0)})
cases=[]
for model in [0,1,2,3,4,255]:
 for flag in [0,1,-1]:
  c=base(f'model-{model}-flag-{flag}');c['flag']=flag;c['bases']['1']['modelType']=model;c['items']['101']['partColors'][5][18]=17;c['items']['101']['armorParts'][9]=1024;cases.append(c)
for plot,baseId in [(0,1),(1,1),(2,1),(0,69),(0,70),(0,73),(0,74)]:
 for count in [0,9,10,11,65536]:
  c=base(f'price-{plot}-{baseId}-{count}');i=c['items']['101'];i.update(baseItem=baseId,plot=plot,stackSize=count,dirty=0,basePrice=0,addCost=0);c['bases']={str(baseId):dict(modelType=0,stacking=10,container=0)};cases.append(c)
for identified in [0,1,256]:
 c=base('identified-'+str(identified));c['items']['101']['identified']=identified;cases.append(c)
for flag in [0,2]:
 c=base('recursive-'+str(flag));c['flag']=flag;c['bases']['1']['container']=1;c['items']['101']['repository']=[None,999,102,103];c['items']['102']=item();c['items']['103']=item();c['items']['103']['repository']=[];c['items']['102']['moveOnState']=True;cases.append(c)
c=base('no-repository');c['bases']['1']['container']=1;cases.append(c)
c=base('empty-properties');c['items']['101']['active']=[];c['items']['101']['passive']=[];cases.append(c)
rng=random.Random(46)
for n in range(60):
 c=base('properties-'+str(n));c['propertiesOnly']=True
 for pool in ['active','passive']:
  p=c['items']['101'][pool]=[prop(rng.randrange(65536),rng.choice([0,1,2,3,258]))for _ in range(rng.randrange(8))]
  for v in p:v['remaining']=rng.choice([0,1,256,257,-1]);v['customTag']=rng.choice(['','custom','nul\0tail'])
 cases.append(c)
observations=[run(c)for c in cases]
output=m.root/'backups/animations/native-item-save-observations.json';output.write_text(json.dumps(dict(target=m.digest,cases=observations),indent=2)+'\n');print(json.dumps(dict(cases=len(cases),output=str(output))))
