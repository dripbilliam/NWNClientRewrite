"""Read-only complete original byte-string/ResRef/server OBJECT_ID writers,
corresponding server readers and localized-string writer with real language
fallback, linked-list lookup, CString copies and player language scan; also
bounded area identity prefix1403632ea..14036339b, not the complete area packer. Only
allocation/free/realloc/copy, warning and stack-cookie lower boundaries are
captured. Fixed heap/stack tails are explicit fixture memory, not native zeros.
No actual transport, original asset copies or live process changes.
"""
import importlib,sys,json,itertools,struct
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
r=importlib.import_module('inspect-native-message-reader');w=r.w;m=w.m;u=m.u;u.hook_del(r.hook_handle)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
owned=m.heap+0x3000;loc=m.heap+0x3800;private=m.heap+0x4000;linked=m.heap+0x5000;nodeBase=m.heap+0x6000;entryBase=m.heap+0x7000;inputBase=m.heap+0x8000
server=m.heap+0xc0000;serverInternal=server+0x1000;clients=m.heap+0xe0000;clientBase=clients+0x1000
extraRanges=[(0x1402dab50,0x1402daca5),(0x1402dad90,0x1402dae3d),(0x1404763e0,0x140476436),(0x140476160,0x1404763dd),
 (0x1402d97d0,0x1402d98cf),(0x1402d9960,0x1402d99ef),(0x140476130,0x14047615c),(0x140475bc0,0x140475c98),(0x140169b60,0x140169b7c),
 (0x140169af0,0x140169b2e),(0x14016a3b0,0x14016a43e),(0x14016a440,0x14016a4db),(0x140169110,0x14016917a),(0x14003d8c0,0x14003d9ab),
 (0x14018def0,0x14018df0d),(0x14018ded0,0x14018deed),(0x140190d30,0x140190dcd),(0x14055b8d0,0x14055b8d9),(0x14055b770,0x14055b779),
 (0x140560e20,0x140560e4f),(0x140560bc0,0x140560bc3)]
extraRanges.append((0x1403632ea,0x14036339b))
extraRanges.extend([(0x1401696e0,0x140169769),(0x140169ee0,0x14016a00c),(0x140169030,0x1401690a3),(0x1401a1040,0x1401a10c2)])
sizes={}

def hook(u,a,n,_):
 x=u.reg_read(UC_X86_REG_RCX);y=u.reg_read(UC_X86_REG_RDX)
 if a==0x140c10324:w.hook(u,0x140c10368,n,_);return
 if a==0x140c4f038:
  ptr=m.heap+w.cursor;w.cursor+=(y+15)&~15;assert w.cursor<0xb0000
  u.mem_write(ptr,bytes([0xa5])*y)
  if x:u.mem_write(ptr,bytes(u.mem_read(x,min(sizes[x],y))))
  sizes[ptr]=y;m.finish(ptr);return
 if a==0x140c4f024:m.finish();return
 if a==0x140c10410:m.finish(u.reg_read(UC_X86_REG_RAX));return
 if a==0x14018def0:readSource.append(bytes(u.mem_read(y,16)).hex())
 if a==0x140115890 and m.si(u.reg_read(UC_X86_REG_RSP)+0x28)==0x4b:r.diagnostics.append(dict(kind='client'));m.finish();return
 if any(lo<=a<hi for lo,hi in extraRanges):return
 r.hook(u,a,n,_)
hook_handle=u.hook_add(UC_HOOK_CODE,hook)

def reset(c):
 global sizes
 sizes={};w.cursor=0x10000;r.diagnostics=[]
 u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes([0xa5])*0x20000);m.wq(0x1412df970,w.app);m.wi(w.app+0x28,c['format']);m.wq(w.app+8,0 if c.get('noServer') else server);m.wq(server+8,serverInternal)
 records=c.get('clients',[dict(id=0x80000001,language=c.get('language',0))]);m.wq(serverInternal+0x100d8,clients);m.wi(serverInternal+0x100e0,len(records))
 for i,record in enumerate(records):ptr=clientBase+i*0x100;m.wq(clients+i*8,ptr);m.wi(ptr+0x48,record['id']);m.wi(ptr+0x4c,record['language'])
 w.call(0x1402d4830);w.call(0x1402d54a0,[w.message,c.get('size',0),0x80000001,1])
 if c.get('fill'):w.call(0x1402dad90,[w.message,inputBase,c['fill'],0])

def stringState(ptr):
 length=m.si(ptr+8)&0xffffffff;data=m.q(ptr);assert length<65536
 return dict(hex=bytes(u.mem_read(data,length)).hex() if data else None,length=length,capacity=m.si(ptr+12)&0xffffffff)

def populateLoc(ptr,c):
 entries=c['entries'];m.wq(ptr,private);m.wi(ptr+8,c['strRef']);m.wq(private,linked);m.wi(private+8,len(entries));m.wq(linked,nodeBase if entries else 0)
 for i,entry in enumerate(entries):
  node=nodeBase+i*0x20;record=entryBase+i*0x40;buf=inputBase+i*0x800;raw=bytes.fromhex(entry['hex']);u.mem_write(buf,raw or b'\0');m.wq(node+8,node+0x20 if i+1<len(entries) else 0);m.wq(node+0x10,record);m.wi(record,entry['key']);m.wq(record+8,buf);m.wi(record+0x10,len(raw))

def runWriter(c):
 reset(c);kind=c['kind'];data=bytes.fromhex(c.get('hex',''));u.mem_write(inputBase,data or b'\0')
 if kind=='string':
  m.wq(owned,inputBase if c.get('pointer',True) else 0);m.wi(owned+8,len(data));m.wi(owned+12,len(data)+1 if c.get('pointer',True) else 0)
  w.call(0x1402dab50,[w.message,owned,c['bits'],0])
 elif kind=='resref':w.call(0x1402dad90,[w.message,inputBase,c['count'],0])
 elif kind=='object':w.call(0x1404763e0,[w.message,c['id'],0,0])
 elif kind=='localized':
  populateLoc(loc,c)
  w.call(0x140476160,[w.message,loc,c['gender'],0])
 else:
  area=m.heap+0x3000;populateLoc(area+0x188,c);m.wi(area+0x140,c['id']);u.mem_write(area+0x120,bytes.fromhex(c['resref']));custom=bytes.fromhex(c['custom']);u.mem_write(inputBase+0x4000,custom or b'\0');m.wq(area+0x358,inputBase+0x4000 if custom else 0);m.wi(area+0x360,len(custom))
  u.reg_write(UC_X86_REG_R14,area);u.reg_write(UC_X86_REG_RSI,w.message);u.reg_write(UC_X86_REG_R15,0);u.reg_write(UC_X86_REG_RSP,m.stack+0x1fc00);u.reg_write(UC_X86_REG_RBP,m.stack+0x1fd00)
  u.emu_start(0x1403632ea,0x14036339b,count=100000);assert u.reg_read(UC_X86_REG_RIP)==0x14036339b
 observation=w.snapshot();return dict(case=c,observation=observation,owned=stringState(owned) if kind=='string' else None,diagnostics=list(r.diagnostics))

def runReader(c):
 global readSource
 reset(c);readSource=[];data=bytes.fromhex(c['hex']);u.mem_write(r.packet,data)
 m.wi(m.stack+0x1fe30,1);setup=w.call(0x1402da7b0,[w.message,r.packet,c['length'],c.get('playerId',0x80000001)])
 if c['kind']=='string':w.call(0x1402d97d0,[w.message,owned,c['bits'],0]);assert u.reg_read(UC_X86_REG_RAX)==owned;value=stringState(owned)
 elif c['kind']=='resref':
  w.call(0x1402d9960,[w.message,owned,c['count'],0]);assert u.reg_read(UC_X86_REG_RAX)==owned;value=bytes(u.mem_read(owned,17)).hex()
 elif c['kind']=='object':value=w.call(0x140476130,[w.message,0,0,0])
 else:
  value=dict(id=w.call(0x140476130,[w.message,0,0,0]));w.call(0x1402d9960,[w.message,owned,16,0]);value['resref']=bytes(u.mem_read(owned,17)).hex();value['custom']=w.call(r.addresses['bool']);value['reference']=w.call(r.addresses['bool'])
  if value['reference']:value['gender']=w.call(r.addresses['byte'],[w.message,1,1,0]);value['strRef']=w.call(r.addresses['dword'],[w.message,32,0,0])
  else:w.call(0x1402d97d0,[w.message,owned,32,0]);value['text']=stringState(owned)
  assert w.call(r.addresses['overflow'])==0;assert w.call(r.addresses['underflow'])==0
 return dict(case=c,setup=setup,value=value,state=r.state(),diagnostics=list(r.diagnostics),resrefStackSource=readSource[-1] if readSource else None)

def runImport(c):
 reset(dict(format=1));rsp=m.stack+0x1fc00;m.wq(rsp+0x28,private);m.wi(rsp+0x30,0xffffffff);m.wq(private,linked)
 records=[]
 for entry in c['entries']:
  raw=bytes.fromhex(entry['hex']);records.append(struct.pack('<II',entry['key'],len(raw))+raw)
 data=struct.pack('<III',8+sum(map(len,records)),c['strRef'],len(records))+b''.join(records);u.mem_write(inputBase,data)
 u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RBP,len(data)-4);u.reg_write(UC_X86_REG_RBX,inputBase);u.reg_write(UC_X86_REG_RSI,0)
 u.emu_start(0x1401a1040,0x1401a10c2,count=100000);assert u.reg_read(UC_X86_REG_RIP)==0x1401a10c2;assert u.reg_read(UC_X86_REG_RBP)==0
 entries=[];node=m.q(linked)
 while node:
  ptr=m.q(node+0x10);value=stringState(ptr+8);entries.append(dict(key=m.si(ptr)&0xffffffff,hex=value['hex'] or ''));node=m.q(node+8)
 assert len(entries)==m.si(private+8)
 return dict(case=c,value=dict(strRef=m.si(rsp+0x30)&0xffffffff,entries=entries))

if __name__=='__main__':
 writers=[];readers=[];imports=[]
 for mode,bits,hex_,fill in itertools.product([0,1,2],[1,7,8,16,31,32,64],['','41','004142','410042ff80','81'*130,'42'*1024],[0,105,116]):
  writers.append(runWriter(dict(kind='string',format=mode,bits=bits,hex=hex_,fill=fill)))
 for mode,count,fill in itertools.product([0,1],[0,1,15,16,17,32,130],[0,110,120]):
  writers.append(runWriter(dict(kind='resref',format=mode,count=count,hex=(b'TNI01_ABC\0'+bytes([0xff,0x80,0,4])*33).hex(),fill=fill)))
 for mode,id_,fill in itertools.product([0,1],[0,1,0x7f000000,0x7fffffff,0x80000001,0xffffffff],[0,118,120]):writers.append(runWriter(dict(kind='object',format=mode,id=id_,fill=fill)))
 entrySets=[[],[dict(key=0,hex='456e676c697368')],[dict(key=1,hex='66656d616c65')],[dict(key=6,hex='6672656e6368'),dict(key=7,hex='46656d616c65')],[dict(key=8,hex='4f74686572'),dict(key=6,hex=''),dict(key=0,hex='456e676c697368')],[dict(key=99,hex='004142')],[dict(key=99,hex='410042ff80')],[dict(key=8,hex='42'*130),dict(key=0,hex='41'*250)]]
 for mode,language,gender,strRef,entries in itertools.product([0,1],[0,3,4,-1],[0,1,2,255],[0xffffffff,123],entrySets):
  writers.append(runWriter(dict(kind='localized',format=mode,language=language,gender=gender,strRef=strRef,entries=entries,fill=110)))
 for mode,noServer,records in itertools.product([0,1],[False,True],[[],[dict(id=0x80000001,language=3),dict(id=0x80000001,language=4)],[dict(id=42,language=3)]]):
  writers.append(runWriter(dict(kind='localized',format=mode,noServer=noServer,clients=records,gender=1,strRef=123,entries=entrySets[3])))
 # Reader packets made by the original writer above, followed by known tails.
 for row in writers:
  c=row['case']
  if c.get('fill') or c['kind'] in ['localized','areaPrefix']:continue
  packet=row['observation']['hex']
  if packet is None:continue
  body=packet[6:];base=dict(c,hex=body+'a5'*32,length=len(body)//2)
  readers.append(runReader(base))
  for length in [5,8,12]:readers.append(runReader(dict(base,length=length)))
 for mode,custom,id_,language,entries in itertools.product([0,1],['','437573746f6d','004142','ff80'*65],[4,0x7f000000],[0,3],entrySets[:4]):
  writers.append(runWriter(dict(kind='areaPrefix',format=mode,custom=custom,id=id_,language=language,entries=entries,strRef=123,resref=(b'm0q1a'+bytes(12)).hex(),fill=110)))
 live=json.loads((m.root/'backups/animations/live-message-text.json').read_text())
 for report in live['reports']:
  body=report['packetHex'][6:];readers.append(runReader(dict(kind='identity',source='replacement-installed-area-identity',format=report['format'],areaId=report['areaId'],playerId=42,hex=body,length=len(body)//2)))
 for key,hex_,reverse in itertools.product([0,1,2,3,6,7,0x7fffffff,0x80000000,0x80000001,0xfffffffd,0xffffffff],['','004142','410042ff80','42'*130],[False,True]):
  entries=[dict(key=8,hex='6669727374'),dict(key=key,hex=hex_),dict(key=0,hex='454e'),dict(key=key,hex='647570')]
  if reverse:entries.reverse()
  imports.append(runImport(dict(strRef=123,entries=entries)))
 out=m.root/'backups/animations/native-message-text-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,writers=writers,readers=readers,imports=imports),indent=2));print(json.dumps(dict(output=str(out),writers=len(writers),readers=len(readers),imports=len(imports))))
