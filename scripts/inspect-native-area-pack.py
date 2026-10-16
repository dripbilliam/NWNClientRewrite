"""Complete unchanged CNWSArea::PackAreaIntoMessage, ambient/sound packers,
tile/time getters and placeable-light owner. Real scalar/text/ID/lookup-list
serialization and temporary cleanup execute. Server accessors, canonical object
lookup/virtual casts, expansion checks, script locals/formatting, PVP and 2DA
query are captured lower boundaries. No transport or live process changes.
"""
import importlib,sys,json,itertools,struct,random
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
t=importlib.import_module('inspect-native-message-text');r=t.r;w=t.w;m=t.m;u=m.u;u.hook_del(t.hook_handle)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
area,ambient,array,module,client,rules,table,tiles,grass,ids,objectBase=[m.heap+i for i in [0x40000,0x41000,0x42000,0x43000,0x44000,0x45000,0x46000,0x47000,0x48000,0x49000,0x4a000]]
casts={m.stop+0x200:12,m.stop+0x210:16,m.stop+0x220:5}
objectStride=0x1000;soundRefOffset=0xb00
ranges=[(0x140363200,0x140364661),(0x140358750,0x14035881d),(0x1404f5120,0x1404f53a8),(0x1404b3e40,0x1404b3f13),(0x1402c5610,0x1402c561e),(0x1402c5620,0x1402c562e),(0x1402c5580,0x1402c5595),(0x14047de20,0x14047de63)]

def rawString(ptr):
 return bytes(u.mem_read(m.q(ptr),m.si(ptr+8)&0xffffffff)).decode('latin1') if m.q(ptr) else ''
def owning(ptr,data):
 if not data or data[0]==0:m.wq(ptr,0);m.wq(ptr+8,0);return
 buf=m.heap+w.cursor;w.cursor+=(len(data)+16)&~15;assert w.cursor<0x40000;u.mem_write(buf,data+b'\0');m.wq(ptr,buf);m.wi(ptr+8,len(data));m.wi(ptr+12,len(data)+1)
def setIds(values):
 runtime['ids']=list(values);m.wi(area+0x230,len(values))
 for i,value in enumerate(values):m.wi(ids+i*4,value)
def recordFor(ptr):return ptrRecords.get(ptr)
def local(ptr,kind,key):
 record=ptrRecords[ptr-0x108];value=record.get('locals',{}).get(kind,{}).get(key,{'int':0,'object':0x7f000000,'float':0.,'string':''}[kind]);trace.append(['local',record['id'],kind,key,value]);return value

def hook(u,a,n,_):
 if a==m.stop:u.emu_stop();return
 x,y,z,q=[u.reg_read(reg)for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
 if a==0x14055b810:trace.append(['message']);m.finish(0 if case.get('noMessage') else w.message);return
 if a==0x14055b850:trace.append(['objectArray']);m.finish(array);return
 if a==0x14055b6e0:trace.append(['module']);m.finish(module);return
 if a==0x14047de20:trace.append(['time'])
 if a==0x1404bd6d0:
  value=case['expansions'].get(f'{z}:{q}',0);trace.append(['expansion',y,z,q,value]);m.finish(value);return
 if a==0x14035ea70:trace.append(['pvp']);m.finish(case['pvp']);return
 if a==0x140296470:
  id_=y&0xffffffff;runtime['lookups']+=1
  mutation=case.get('onLookup',{})
  if mutation.get('at')==runtime['lookups']:
   if 'ids'in mutation:setIds(mutation['ids'])
   if 'remove'in mutation:runtime['removed'].add(mutation['remove'])
  obj=idRecords.get(id_);status=1 if not obj or id_ in runtime['removed'] else obj.get('status',0)
  trace.append(['lookup',id_,status])
  if status==0:m.wq(z,obj['ptr'])
  m.finish(status);return
 if a in casts:
  obj=recordFor(x);m.finish(x if obj and obj['type']==casts[a] else 0);return
 if a in [0x14055b890,0x14055b3d0]:
  id_=y&0xffffffff;obj=idRecords.get(id_);type_=9 if a==0x14055b890 else 5;valid=obj is not None and obj['type']==type_ and id_ not in runtime['removed']
  trace.append(['placeable' if type_==9 else 'creature',id_,bool(valid)]);m.finish(obj['ptr'] if valid else 0);return
 if a==0x1404ba840:trace.append(['clientObject']);obj=idRecords.get(case.get('controlled',0x7f000000));m.finish(obj['ptr'] if obj else 0);return
 if a==0x1401a7010:
  runtime['lightQueries']+=1;mutation=case.get('onLight',{})
  if mutation.get('at')==runtime['lightQueries']:
   if 'ids'in mutation:setIds(mutation['ids'])
   for id_,changes in mutation.get('fields',{}).items():fields(idRecords[int(id_)]['ptr'],changes)
  row=y&0xffffffff;status,value=case.get('lightRows',{}).get(str(row),[0,0]);trace.append(['lightColor',row,rawString(z),status,value]);m.wi(q,value);m.finish(status);return
 if a in [0x1402c5610,0x1402c5620,0x1402c5580]:trace.append([{0x1402c5610:'main',0x1402c5620:'source',0x1402c5580:'anim'}[a],(x-tiles)//0x68])
 if a==0x14016afb0:
  format_=bytes(u.mem_read(y,40)).split(b'\0')[0].decode('latin1')
  if format_.startswith('NW_MAP_PIN_'):owning(x,(format_%(z&0xffffffff)).encode('ascii'));m.finish(x);return
 if a==0x140507460:m.finish(local(x,'int',rawString(y)));return
 if a==0x140507570:m.finish(local(x,'object',rawString(y)));return
 if a==0x140507430:
  value=local(x,'float',rawString(y));u.reg_write(UC_X86_REG_XMM0,int.from_bytes(struct.pack('<f',value),'little'));m.finish();return
 if a==0x1405075a0:owning(y,bytes.fromhex(local(x,'string',rawString(z))));m.finish(y);return
 if any(lo<=a<hi for lo,hi in ranges):return
 t.hook(u,a,n,_)
hook_handle=u.hook_add(UC_HOOK_CODE,hook)

def fields(ptr,values):
 for key,(kind,value)in values.items():
  address=ptr+int(key,16)
  if kind=='float':m.wf(address,value)
  elif kind=='byte':u.mem_write(address,bytes([value&255]))
  elif kind=='word':u.mem_write(address,struct.pack('<H',value&65535))
  else:m.wi(address,value)
def ref(ptr,value):u.mem_write(ptr,value.encode('ascii')[:16].ljust(17,b'\0'))
def populateName(ptr,entries,strRef=123):
 # Each private list is local to this owner's 4KB fixture region.
 priv=ptr+0x100;head=ptr+0x120;m.wq(ptr,priv);m.wi(ptr+8,strRef);m.wq(priv,head);m.wi(priv+8,len(entries));m.wq(head,ptr+0x140 if entries else 0)
 for i,(key,hex_)in enumerate(entries):
  node=ptr+0x140+i*0x20;entry=ptr+0x200+i*0x40;buf=ptr+0x300+i*0x100;raw=bytes.fromhex(hex_);u.mem_write(buf,raw or b'\0');m.wq(node+8,node+0x20 if i+1<len(entries) else 0);m.wq(node+0x10,entry);m.wi(entry,key);m.wq(entry+8,buf);m.wi(entry+0x10,len(raw))

def run(c,execute=None):
 global case,runtime,trace,idRecords,ptrRecords
 case=c;runtime=dict(ids=[],lookups=0,lightQueries=0,removed=set());trace=[];idRecords={};ptrRecords={};t.reset(dict(format=c['format'],size=c.get('size',0),language=c.get('language',0)))
 if 'playerId'in c:m.wi(w.message+0x64,c['playerId']);m.wi(t.clientBase+0x48,c['playerId'])
 fields(area,c['area']);m.wi(area+0x140,c['id']);m.wq(area+0x328,ambient);fields(ambient,c['ambient']);fields(module,c['module']);m.wq(area+0x1c8,tiles);m.wq(area+0x228,ids);setIds(c['ids'])
 if 'areaRefHex'in c:u.mem_write(area+0x120,bytes.fromhex(c['areaRefHex']));u.mem_write(area+0x1a8,bytes.fromhex(c['tilesetRefHex']))
 else:ref(area+0x120,'fixture_area');ref(area+0x1a8,'tni01')
 populateName(area+0x188,c.get('nameEntries',[]),c.get('nameStrRef',123));m.wq(area+0x358,0);m.wi(area+0x360,0)
 # Reapply fields potentially within the localized private fixture footprint.
 fields(area,c['area']);m.wq(area+0x328,ambient);m.wq(area+0x1c8,tiles);m.wq(area+0x228,ids);setIds(c['ids'])
 custom=bytes.fromhex(c.get('custom',''))
 if custom:
  ptr=m.heap+w.cursor;w.cursor+=(len(custom)+16)&~15;u.mem_write(ptr,custom+b'\0');m.wq(area+0x358,ptr);m.wi(area+0x360,len(custom));m.wi(area+0x364,len(custom)+1)
 for i,tile in enumerate(c['tiles']):fields(tiles+i*0x68,tile)
 m.wq(area+0x378,grass);m.wq(grass,grass+0x80 if c['grass'] else grass)
 for i,g in enumerate(c['grass']):
  node=grass+0x80+i*0x80;m.wq(node,grass+0x80+(i+1)*0x80 if i+1<len(c['grass']) else grass);fields(node,g['fields']);owning(node+0x18,bytes.fromhex(g['name']))
 for i,record in enumerate(c['objects']):
  obj=dict(record,ptr=objectBase+i*objectStride);idRecords[obj['id']]=obj;ptrRecords[obj['ptr']]=obj;ptr=obj['ptr'];fields(ptr,obj['fields']);m.wi(ptr+8,obj['id']);m.wq(ptr,ptr+0xe00)
  for offset,thunk in [(0xb8,m.stop+0x200),(0xd8,m.stop+0x210),(0x60,m.stop+0x220)]:m.wq(ptr+0xe00+offset,thunk)
  if obj['type']==12:populateName(ptr+0x310,obj.get('nameEntries',[]),obj.get('nameStrRef',123));fields(ptr,obj['fields'])
  if obj['type']==16:
   m.wq(ptr+0x338,ptr+soundRefOffset)
   if 'refsHex'in obj:
    for j,hex_ in enumerate(obj['refsHex']):u.mem_write(ptr+soundRefOffset+j*17,bytes.fromhex(hex_))
   else:
    for j,name_ in enumerate(obj['refs']):ref(ptr+soundRefOffset+j*17,name_)
 m.wq(0x1412df8f8,rules);m.wq(rules+0x130,rules+0x800);m.wq(rules+0x800+0x140,table)
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);m.wq(rsp+0x28,client);u.reg_write(UC_X86_REG_RSP,rsp)
 for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],[area,*c['point']]):u.reg_write(reg,value&0xffffffffffffffff)
 if execute is None:u.emu_start(0x140363200,m.stop,count=5000000)
 else:execute()
 assert u.reg_read(UC_X86_REG_RIP)==m.stop;result=u.reg_read(UC_X86_REG_RAX)&0xffffffff
 return dict(case=c,result=result,trace=trace,observation=w.snapshot(),diagnostics=list(r.diagnostics))

def fieldMap(offsets,kind,value):return{f'{o:x}':[kind,value+i] for i,o in enumerate(offsets)}
def base(mode=1):
 a={**fieldMap([8,0x98,0x9c,0xa0,0xb8,0xbc,0xc0],'dword',0x10203040),**fieldMap([0xa8,0xc8,0xd8,0xdc,0x100,0x34c,0x334,0x368,0x380,0x10c],'int',-2),**fieldMap([0xa4,0xc4,0x104,0xe0,0xe3,0xe4,0x344,0x330],'byte',0),**fieldMap([0xac,0xb0,0xb4,0xcc,0xd0,0xd4,0x108,0xe8,0xec,0xf0,0xf4,0xf8,0xfc],'float',.25),'c':['int',1],'10':['int',1]};a['380']=['int',0];a['344']=['byte',255]
 tile={**fieldMap([0x14,0x24,0x18],'int',2),**fieldMap([0x28,0x29,0x2a,0x2b,0x2c,0x2d,0x2e,0x2f],'byte',0)}
 return dict(format=mode,id=4,point=[2,-3,4],area=a,ambient={**fieldMap([8,0x18,0x20,0xc,0x10,0x14,0x1c,0x24,0x28],'int',-3),**fieldMap([0x2c,0x2d],'byte',50)},module={**fieldMap([0x3c0,0x3c4,0x3c8,0x3cc,0x3d0],'dword',2037),'3d4':['byte',3],'3b9':['byte',6],'3ba':['byte',18]},tiles=[tile],grass=[],ids=[],objects=[],expansions={'35:0':1,'14:0':1,'36:3':1,'36:5':1},pvp=2)
def object_(type_,id_):
 values=fieldMap([0xa4,0xa8,0xac,0xb0,0xb4,0xb8],'float',1.25)
 if type_==12:values.update({'308':['int',1],'30c':['int',-1]})
 if type_==9:values.update({'32c':['word',7],'594':['int',1],'5a0':['int',1]})
 if type_==5:values['8fc']=['dword',0x7f000000]
 if type_==16:values.update({**fieldMap([0x308,0x30c,0x310,0x358,0x35c,0x32c],'int',-2),**fieldMap([0x314,0x318,0x31c,0x328],'byte',10),**fieldMap([0x324,0x348,0x34c],'dword',30),**fieldMap([0x320,0x350,0x354,0x330,0x334],'float',.5),'340':['word',2]})
 return dict(type=type_,id=id_,fields=values,refs=['fixture_sound','other_sound'] if type_==16 else [],nameEntries=[[0,'576179706f696e74']] if type_==12 else [],locals={})

if __name__=='__main__':
 cases=[]
 for mode,expansion,wind,override in itertools.product([0,1,2],[0,1,-1],[0,3],[0,255]):
  c=base(mode);c['expansions']={key:expansion for key in c['expansions']};c['area']['e4']=['byte',wind];c['area']['344']=['byte',override];cases.append(c)
 for mask in range(256):
  c=base(mask%2)
  for i,offset in enumerate([0x28,0x29,0x2a,0x2b,0x2c,0x2d,0x2e,0x2f]):c['tiles'][0][f'{offset:x}']=['byte',i+1 if mask>>i&1 else 0]
  cases.append(c)
 for type_,status,count in itertools.product([5,9,12,16,7],[0,1],[1,3,18]):
  c=base(count%2);c['objects']=[dict(object_(type_,100+i),status=status) for i in range(count)];c['ids']=[o['id'] for o in c['objects']]+[0x7f000000];c['lightRows']={'7':[1,0]};cases.append(c)
 for static_,light,status,value in itertools.product([0,1,2,-1],[0,1,2,-1],[0,1],[0,0x112233]):
  c=base();o=object_(9,100);o['fields']['5a0']=['int',static_];o['fields']['594']=['int',light];c['objects']=[o];c['ids']=[100];c['lightRows']={'7':[status,value]};cases.append(c)
 for total,master in itertools.product([0,1,3],[False,True]):
  c=base();pc=object_(5,1000);assoc=object_(5,1001);assoc['fields']['8fc']=['dword',1000];pc['locals']={'int':{'NW_TOTAL_MAP_PINS':total},'string':{'NW_MAP_PIN_NTRY_0':'5a65726f','NW_MAP_PIN_NTRY_1':'4f74686572','NW_MAP_PIN_NTRY_3':'4c617374'},'object':{'NW_MAP_PIN_AREA_0':4,'NW_MAP_PIN_AREA_1':5,'NW_MAP_PIN_AREA_3':4},'float':{'NW_MAP_PIN_XPOS_0':1.25,'NW_MAP_PIN_YPOS_0':-2.5,'NW_MAP_PIN_ZPOS_3':3.75}};c['objects']=[pc,assoc];c['controlled']=1001 if master else 1000;cases.append(c)
 for count,mode in itertools.product([0,1,3],[0,1]):
  c=base(mode);c['area']['380']=['int',count];c['grass']=[dict(fields={'10':['byte',i],**fieldMap([0x28,0x2c,0x30,0x34,0x38,0x3c,0x40,0x44],'float',i+.5)},name=(f'grass_{i}'.encode().hex()))for i in range(count)];cases.append(c)
 for mode,noMessage in itertools.product([0,1,2],[False,True]):c=base(mode);c['noMessage']=noMessage;cases.append(c)
 for mutation in [dict(at=1,ids=[]),dict(at=2,remove=100),dict(at=1,ids=[100,102,101])]:
  c=base();c['objects']=[object_(12,100),object_(16,101),object_(9,102)];c['ids']=[100,101,102];c['onLookup']=mutation;cases.append(c)
 for mode,custom,size in itertools.product([0,1],['','437573746f6d','004142','ff80'*130],[0,65536]):
  c=base(mode);c['size']=size;c['custom']=custom;c['nameEntries']=[[6,'4672616e63616973'],[0,'4e616d65ff80']];c['area']['c']=['int',2];c['area']['10']=['int',3];c['area']['e4']=['byte',3];c['tiles']=[c['tiles'][0]]*6;c['objects']=[object_(type_,100+i)for i,type_ in enumerate([12,16,9,5,12,16,9,7,9,9,16,12,16,9,12,16,9,16])];c['ids']=[o['id']for o in c['objects']];c['lightRows']={'7':[1,0]};cases.append(c)
 for mode,enabled in itertools.product([0,1],[0,-1,2]):
  c=base(mode);o=object_(12,100);o['fields']['308']=['int',enabled];c['objects']=[o];c['ids']=[100];cases.append(c)
 for mutation in [dict(at=1,ids=[100]),dict(at=1,fields={'100':{'5a0':['int',0]},'101':{'594':['int',-1],'5a0':['int',2]}})]:
  c=base();c['objects']=[object_(9,100),object_(9,101)];c['ids']=[100,101];c['lightRows']={'7':[1,0]};c['onLight']=mutation;cases.append(c)
 for mode,selected in itertools.product([0,1],['35:0','14:0','36:3','36:5']):
  c=base(mode);c['expansions']={key:int(key==selected)for key in c['expansions']};c['area']['e4']=['byte',3];cases.append(c)
 rows=[]
 for i,c in enumerate(cases):
  try:rows.append(run(c))
  except Exception:print(json.dumps(dict(index=i,case=c,rip=hex(u.reg_read(UC_X86_REG_RIP)))));raise
 out=m.root/'backups/animations/native-area-pack-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2));print(json.dumps(dict(output=str(out),rows=len(rows))))
