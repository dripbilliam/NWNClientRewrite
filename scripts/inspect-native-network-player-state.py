"""Original PlayerUpdate4e8420 serializer and effect-icon writer.

Real native field reads, masks, spell-list/feat difference loops, effect-icon
comparison and scalar writers execute. Stat/rule/build/lookup getters and
post-write cache cleanup are explicit captured fixture boundaries. No local AI,
live process writes, native executable changes or complete GUI-state claim.
"""
import sys,importlib,json,struct,itertools
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
t=importlib.import_module('inspect-native-message-text');w=t.w;r=t.r;m=w.m;u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(t.hook_handle)
obj,player,vtable,luo,stats,rules,classes,data=[m.heap+x for x in [0x9000,0xa000,0xb000,0x50000,0x60000,0x70000,0x80000,0x90000]]
ranges=[(0x1404e8420,0x1404ea6c0)]
for name in ['write-char','write-short','gui-effect-icons-writer']:
 d=json.loads((m.root/'backups/animations'/('rea-network-'+name+'.json')).read_text())['structuredContent']['normalized_result'];ranges.extend((int(x['start'],16),int(x['end'],16)+1)for x in d['procedure']['body']['ranges'])
abilityGetters={0x140406930:10,0x1403fd3e0:12,0x1403fa0f0:14,0x140402d10:16,0x14040b5e0:18,0x1403fa050:20}
def hook(u,a,n,d):
 x,y,z,q=[u.reg_read(reg)for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
 if a==0x1404ba840 or a==m.stop+0x100:m.finish(obj);return
 if a==0x140494e80:m.finish(data+0x800);return
 if a==0x1403a5ae0:
  rsp=u.reg_read(UC_X86_REG_RSP);index=z*8+q;m.wi(m.q(rsp+0x28),index%8);m.wi(m.q(rsp+0x30),index//8);m.finish();return
 if a==0x140390070:m.finish(17);return
 if a==0x1403f1b30:m.finish(c['levelUp']);return
 if a==0x140406a40:m.finish((int(y)-2)&255);return
 if a==0x1404ca180:m.finish(0x76543210);return
 if a==0x1404ca1f0:m.finish(0x80000801);return
 if a==0x1404bd6d0:m.finish(int(c['build']['revision']>z or c['build']['revision']==z and c['build']['postfix']>=q));return
 if a==0x1403fa4a0:m.finish(10 if y==0 else 255);return
 if a==0x140405770:m.finish(3 if z==1 else 0);return
 if a==0x1404c3260:m.finish(0);return
 if a==0x140409680:m.finish(7 if z==1 else 0);return
 if a in [0x1404c42f0,0x1404c4160,0x1404c2ef0]:m.finish();return
 if a==0x1404012d0:m.finish([25,945][y]);return
 if a==0x1403fa030:m.finish(900);return
 if a==0x1404012f0:m.finish(4);return
 if a in abilityGetters:m.finish(abilityGetters[a]);return
 if any(lo<=a<hi for lo,hi in ranges):return
 t.hook(u,a,n,d)
u.hook_add(UC_HOOK_CODE,hook)
def ints(ptr,values):
 for i,v in enumerate(values):m.wi(ptr+i*4,v)
def string(ptr,value):
 global cursor
 raw=value.encode('ascii');p=data+cursor;cursor+=len(raw)+16;u.mem_write(p,raw+b'\0');m.wq(ptr,p);m.wi(ptr+8,len(raw));m.wi(ptr+12,len(raw)+1)
def run(case):
 global c,cursor
 c=case;cursor=0x4000;t.reset(dict(format=c['format']));m.wq(obj,vtable);m.wq(vtable+0x60,m.stop+0x100);m.wi(obj+8,0x7fffffff);m.wq(obj+0xad0,stats);m.wq(0x1412df8f8,rules);m.wq(rules+0x110,classes);u.mem_write(rules+0x105,bytes([28,0,c['skillCount']]));m.wi(classes+10*0x530+0x4ec,c['memorizes']);u.mem_write(stats+0xd8,b'\1');m.wi(obj+0x898,1529);m.wi(obj+0x978,95);ints(obj+0x9e8,[-1,42,65535]);u.mem_write(stats+0xdc6,struct.pack('<H',12));ints(stats+0xe34,[123]);ints(stats+0xe30,[456]);string(stats+0xe48,'fixture-a');string(stats+0xe38,'fixture-b');m.wi(stats+0xd4,123456);u.mem_write(stats+0xc0,b'\2')
 for i,v in enumerate([9,11,13,15,17,19]):u.mem_write(stats+0xd38+i*2,bytes([v]))
 # Native b98 removal list, c18 addition list. Other class positions empty.
 m.wq(luo+0xb90,data);ints(data,[100,101]);m.wi(luo+0xb98,2);m.wq(luo+0xc10,data+0x20);ints(data+0x20,[37,100,0xfffffffe]);m.wi(luo+0xc18,3)
 # Prepared slot removal and addition payloads, with exact native c/d/e bytes.
 m.wq(luo+0xc90,data+0x40);m.wq(data+0x40,data+0x50);u.mem_write(data+0x50,bytes([1,2]));m.wi(luo+0xc98,1);m.wq(luo+0xd10,data+0x60);m.wq(data+0x60,data+0x70);ints(data+0x70,[37,1,1]);u.mem_write(data+0x7c,bytes([2,1,1]));m.wi(luo+0xd18,1)
 # Feat source/cache differences and remaining-use list.
 u.mem_write(stats+8,struct.pack('<H',2));u.mem_write(stats+0x28,struct.pack('<H',1));m.wq(stats+0x10,data+0x100);m.wi(stats+0x18,1);m.wq(data+0x100,data+0x110);u.mem_write(data+0x110,struct.pack('<H',945));m.wq(luo+0x18,data+0x120);u.mem_write(data+0x120,struct.pack('<HH',25,100));m.wi(luo+0x20,2);m.wq(luo+0x28,data+0x130);u.mem_write(data+0x130,struct.pack('<H',901));m.wi(luo+0x30,1)
 # Special abilities: native vector of {DWORD spell,BOOL ready,BYTE level}.
 m.wq(stats+0xd88,data+0x200);m.wq(data+0x200,data+0x220);m.wq(data+0x208,2)
 for i,(spell,ready,level)in enumerate([(37,1,2),(65535,0,9)]):ints(data+0x220+i*12,[spell,ready]);u.mem_write(data+0x228+i*12,bytes([level]))
 # Actual icon differencing owner executes on sorted visible icon lists.
 m.wq(obj+0x778,data+0x300);m.wi(obj+0x780,3);m.wq(luo+0xde0,data+0x340);m.wi(luo+0xde8,2)
 for i,(icon,state)in enumerate([(1,1),(256,0),(900,1)]):p=data+0x380+i*16;m.wq(data+0x300+i*8,p);u.mem_write(p,struct.pack('<H',icon));ints(p+4,[state,1])
 for i,(icon,state)in enumerate([(1,0),(2,1)]):p=data+0x3c0+i*16;m.wq(data+0x340+i*8,p);u.mem_write(p,struct.pack('<H',icon));ints(p+4,[state,1])
 # Native inactive queue rows use sentinel -1, not zero. Exercise actual
 # A/S/D difference generation and mask-dependent target/point/spell fields.
 for i in range(10):u.mem_write(obj+0x59c+i*0x1c,struct.pack('<HHH',65535,65535,65535));u.mem_write(luo+0x58+i*0x1c,struct.pack('<HHH',65535,65535,65535))
 if c.get('queue')=='D':u.mem_write(luo+0x58,struct.pack('<HHH',321,4,7))
 else:u.mem_write(obj+0x59c,struct.pack('<HHH',123,c.get('queueType',0),7));u.mem_write(obj+0x5a8,struct.pack('<fff',1.25,2.5,3.75));m.wi(obj+0x5b4,0x123456);m.wi(obj+0x5a4,0x789abc)
 if c.get('map'):
  mode=c['map'];old=bytes([255 if mode in ['clear','reset-sparse']else 0])*8;current={'none':bytes(8),'sparse':bytes([1])+bytes(7),'dense':bytes([255,255])+bytes(6),'full':bytes([255])*8,'clear':bytes(8),'reset-sparse':bytes([15])+bytes(7)}[mode]
  m.wi(obj+0xa0,123);m.wq(obj+0x6c8,data+0x600);m.wi(data+0x600,123);m.wi(obj+0x6d0,1);m.wq(obj+0x6d8,data+0x610);m.wq(data+0x610,data+0x720);u.mem_write(data+0x720,current);m.wq(luo+0x170,data+0x700);u.mem_write(data+0x700,old);m.wi(data+0x800+0xc,8);m.wi(data+0x800+0x10,8);m.wi(data+0x800+0x140,123);u.mem_write(data+0x800+0x348,b'\10')
 m.wi(m.stack+0x1fe08+0x28,c['mask']);
 try:w.call(0x1404e8420,[w.message,player,luo,data+0x1000]);packet=w.snapshot()
 except Exception:print(json.dumps(dict(case=c,rip=hex(u.reg_read(UC_X86_REG_RIP)))));raise
 return dict(case=c,packet=packet['hex'])
cases=[]
for format,revision,mask in itertools.product([0,1],[34,36,37],[0,1,2,4,8,16,32,64,128,256,1024,2048,4096,8192,16384,32768,0xd5ff]):cases.append(dict(format=format,build=dict(number=8193,revision=revision,postfix=17 if revision==37 else 3),mask=mask,levelUp=0,skillCount=5,memorizes=1))
for format,revision,mask in itertools.product([0,1],[34,36,37],[1,0xd5ff]):cases.append(dict(format=format,build=dict(number=8193,revision=revision,postfix=17 if revision==37 else 4),mask=mask,levelUp=1,skillCount=5,memorizes=0))
for format,revision,queueType in itertools.product([0,1],[34,36,37],[0,1,2,4,12,19,65535]):cases.append(dict(format=format,build=dict(number=8193,revision=revision,postfix=17 if revision==37 else 3),mask=256,levelUp=0,skillCount=5,memorizes=1,queueType=queueType))
for format,revision in itertools.product([0,1],[34,36,37]):cases.append(dict(format=format,build=dict(number=8193,revision=revision,postfix=17 if revision==37 else 3),mask=256,levelUp=0,skillCount=5,memorizes=1,queue='D'))
for format,revision,map in itertools.product([0,1],[34,36,37],['none','sparse','dense','full','clear','reset-sparse']):cases.append(dict(format=format,build=dict(number=8193,revision=revision,postfix=17 if revision==37 else 3),mask=512,levelUp=0,skillCount=5,memorizes=1,map=map))
rows=[run(c)for c in cases];output=m.root/'backups/animations/native-network-player-state-observations.json';output.write_text(json.dumps(dict(target=m.digest,limits=__doc__,cases=rows),indent=2)+'\n');print(json.dumps(dict(cases=len(rows),output=str(output))))
