"""Original9/7 server writer, bounded client one-shot branch77e330..77e3bb,
and complete listener coordinator6e67e0. Scalar/string/ID/ResRef codecs execute;
transport, GUI/source admission, camera/object lookup and sound output are
explicit synthetic boundaries. No native mixer, hardware output or full chat
handler execution is claimed. No original process or asset is modified.
"""
import sys,importlib,json,itertools,struct
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
t=importlib.import_module('inspect-native-message-text');w=t.w;m=w.m;u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(t.hook_handle)
def dossier(name):
 d=json.loads((m.root/'backups/animations'/name).read_text())
 if d.get('structuredContent',{}).get('raw_result',{}).get('value'):return d['structuredContent']['raw_result']['value']
 e=json.loads(next(c['text']for c in d['content']if c['type']=='text'));return e.get('normalized_result',e.get('raw_result',e))
sender=dossier('rea-network-script-sound-sender.json');listener=dossier('rea-network-audio-listener-owner.json')
ranges=[(int(r['start'],16),int(r['end'],16)+1)for d in [sender,listener]for r in d['procedure']['body']['ranges']]
ranges += [(0x14077e330,0x14077e3bb),(0x14018dea0,0x14018decd),(0x1401d9c40,0x1401d9c94)]
obj,text,raw,state,scene,camera,vt,pose,app=[m.heap+n*0x1000 for n in range(0x81,0x8a)]
updates={c['name']:int(c['address'],16)for c in listener['callees']}
def vector(ptr,count=3):return list(struct.unpack('<'+'f'*count,u.mem_read(ptr,count*4)))
def ref(ptr):return bytes(u.mem_read(ptr,16)).split(b'\0')[0].hex()
def hook(u,a,n,data):
 x,y,z,k=[u.reg_read(q)for q in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];sp=u.reg_read(UC_X86_REG_RSP)
 if a==0x1404dc490:
  size=m.si(sp+0x30)&0xffffffff;packets.append((bytes([80,z&255,k&255])+bytes(u.mem_read(m.q(sp+0x28),size))[3:]).hex());m.finish(1);return
 if mode=='client'and a==0x14077eb9f:u.emu_stop();return
 if mode=='wrapper'and a==0x1401df170:
  calls.append(dict(resRefHex=ref(y),position=vector(z),priority=k&255,delay=m.si(sp+0x28),volume=u.mem_read(sp+0x30,1)[0]));m.finish();return
 if mode=='client'and a in [0x1401d9c40,0x1401d9d00]:
  calls.append(dict(positional=a==0x1401d9c40,resRefHex=ref(y),position=vector(z)if a==0x1401d9c40 else None,priority=u.mem_read(sp+0x28,1)[0]if a==0x1401d9c40 else z&255,delay=m.si(sp+0x30)if a==0x1401d9c40 else k&0xffffffff,volume=u.mem_read(sp+(0x38 if a==0x1401d9c40 else 0x28),1)[0]));m.finish();return
 if mode=='listener':
  if a in [updates['CExoSound::Update'],updates['CExoSound::Render']]:m.finish();return
  if a==0x1406ab9e0:m.finish(obj if case['actor']else 0);return
  if a==m.stop+0x40:u.mem_write(y,struct.pack('<3f',*case['camera']));m.finish(y);return
  if a==m.stop+0x48:u.mem_write(y,struct.pack('<4f',*case['quaternion']));m.finish(y);return
  if a==0x1401d9f60:calls.append(dict(kind='position',value=vector(y)));m.finish();return
  if a==0x1401d9f10:calls.append(dict(kind='orientation',forward=vector(y),up=vector(z)));m.finish();return
 if any(lo<=a<hi for lo,hi in ranges):return
 t.hook(u,a,n,data)
u.hook_add(UC_HOOK_CODE,hook)
rows=[]
for fmt,oid,value in itertools.product([0,1],[0x13,0x7fffffff,0x7f000000],['','gui_journaladd','LOUD_NAME_1234567890','a\0ignored','native_é']):
 mode='writer';packets=[];calls=[];t.reset(dict(format=fmt));data=value.encode('cp1252');u.mem_write(raw,data+b'\0');m.wq(text,raw);m.wi(text+8,len(data));m.wi(text+12,len(data)+1)
 result=w.call(0x1404ccfe0,[w.message,0x80000001,oid,text]);rows.append(dict(kind='wire',format=fmt,objectId=oid,textHex=data.hex(),packets=packets,result=result))
for positional,value,point in itertools.product([False,True],['','gui_journaladd','LOUD_NAME_1234567890','a\0ignored','native_é'],[[0,0,0],[3.25,-8.5,1.8]]):
 mode='client';calls=[];t.reset(dict(format=1));data=value.encode('cp1252');u.mem_write(raw,data+b'\0');sp=m.stack+0x10000;m.wq(sp+0x60,raw);m.wi(sp+0x68,len(data));m.wi(sp+0x6c,len(data)+1);u.mem_write(obj+0x38,struct.pack('<3f',*point))
 for reg,v in [(UC_X86_REG_RSP,sp),(UC_X86_REG_RBP,m.stack+0x1000),(UC_X86_REG_RSI,obj if positional else 0),(UC_X86_REG_RDI,0)]:u.reg_write(reg,v)
 u.emu_start(0x14077e330,0x14077eb9f,count=10000);assert u.reg_read(UC_X86_REG_RIP)==0x14077eb9f
 rows.append(dict(kind='client-branch',positional=positional,textHex=data.hex(),position=point,calls=calls))
for point,height,priority,volume in itertools.product([[0,0,0],[3.25,-8.5,1.8]],[0,1.5,-.25],[8,11,12,13],[0,63,255]):
 mode='wrapper';calls=[];t.reset(dict(format=1));m.wq(obj,app);u.mem_write(raw,b'generic_sound\0');u.mem_write(pose,struct.pack('<3f',*point));sp=m.stack+0x1fe08;m.wi(sp+0x28,priority);m.wi(sp+0x30,0);m.wi(sp+0x38,volume);u.reg_write(UC_X86_REG_XMM3,int.from_bytes(struct.pack('<f',height),'little'));w.call(0x1401d9c40,[obj,raw,pose,0]);rows.append(dict(kind='wrapper',position=point,height=height,priority=priority,volume=volume,calls=calls))
for actor,hasScene,hasCamera,p,c,q in itertools.product([False,True],[False,True],[False,True],[[0,0,0],[12.25,-4.5,1.1]],[[2,3,4],[-8.5,4.2,16.5]],[[1,0,0,0],[.5,.5,.5,.5],[.8,.2,-.4,.1]]):
 mode='listener';calls=[];case=dict(actor=actor,scene=hasScene,hasCamera=hasCamera,player=p,camera=c,quaternion=q);t.reset(dict(format=1));m.wq(state+0x30,scene if hasScene else 0);m.wq(scene+0xe8,camera if hasCamera else 0);m.wq(camera,vt);m.wq(vt+0x40,m.stop+0x40);m.wq(vt+0x48,m.stop+0x48);u.mem_write(obj+0x38,struct.pack('<3f',*p));w.call(0x1406e67e0,[state]);rows.append(dict(kind='listener',case=case,calls=calls))
out=m.root/'backups/animations/native-network-audio-observations.json';out.write_text(json.dumps(dict(target=m.digest,limits=__doc__,cases=rows),indent=2)+'\n');print(json.dumps(dict(output=str(out),cases=len(rows))))
