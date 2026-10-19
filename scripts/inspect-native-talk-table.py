"""Complete original FetchInternal and GetStrByStrRef wrappers, native
InitFromCharArray and STR_RES assignment. File I/O/metadata, hash containers,
Format/ResRef assignment, token parsing, allocation/free, memcpy, logging and VM
transfers are captured boundaries. Short text allocations have authored known
0xa5 fill; real unknown uninitialized bytes are not claimed reproducible.
OpenFile/ReadHeader, actual disk I/O, ParseStr and whole VM are not proved here.
"""
import importlib,sys,json,itertools,struct
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
table,out,gsent,gbuckets,overrideNode,male,female,msent,fsent,mbuckets,fbuckets,mnode,fnode,cmd,cacheRecord=[m.heap+i*0x1000 for i in range(1,16)]
files={male:'male',female:'female'};nodes={male:mnode,female:fnode};sentinels={male:msent,female:fsent}
ranges=[(0x140198c60,0x1401994b8),(0x140530e20,0x140530f65),(0x14003d8c0,0x14003d9ab),(0x140198640,0x14019868b)]
def string(ptr,limit=1000):
 b=bytearray()
 if ptr:
  for i in range(limit):
   v=u.mem_read(ptr+i,1)[0]
   if v==0:break
   b.append(v)
 return bytes(b)
def alloc(size):
 global cursor
 assert size<0x10000;ptr=m.heap+cursor;cursor+=(size+31)&~15;assert cursor<0xf0000;u.mem_write(ptr,bytes([0xa5])*size);return ptr
def set_string(target,data):
 if not data or data[0]==0:m.wq(target,0);m.wq(target+8,0);return
 ptr=alloc(len(data)+1);u.mem_write(ptr,data+b'\0');m.wq(target,ptr);m.wi(target+8,len(data));m.wi(target+12,len(data)+1)
def record(ptr):return dict(text=bytes(u.mem_read(m.q(ptr),m.si(ptr+8)&0xffffffff)).hex()if m.q(ptr)else'',sound=string(ptr+16,16).hex(),durationBits=m.si(ptr+36)&0xffffffff)
def set_record(ptr,text,sound,duration):set_string(ptr,text);u.mem_write(ptr+16,sound[:16].ljust(20,b'\0'));m.wi(ptr+36,duration)
def hook(u,a,n,_):
 global output,pops
 if a==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(r)for r in[UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
 if a==0x140c10368:m.finish(alloc(x));return
 if a==0x140c10370:m.finish();return
 if a==0x140c417f0:
  if z:u.mem_write(x,bytes(u.mem_read(y,z)))
  m.finish(x);return
 if a==0x140c10410:m.finish(u.reg_read(UC_X86_REG_RAX));return
 if a==0x14016afb0:
  fmt=string(y).decode('ascii');value=z&0xffffffff;set_string(x,(fmt%(value if value<0x80000000 else value-0x100000000)).encode('ascii'));m.finish();return
 if a in[0x14018ded0,0x14018def0]:u.mem_write(x,string(y,16).ljust(17,b'\0'));m.finish(x);return
 if a==0x14018de80:u.mem_write(x,bytes(u.mem_read(y,20)));m.finish(x);return
 if a==0x140199e20:parses.append(record(y)['text']);set_string(y,b'p:'+bytes.fromhex(record(y)['text']));m.finish();return
 if a==0x140115890:warnings.append(m.si(rsp+0x28));m.finish();return
 if a==0x14019b7d0:m.wq(y,nodes[x-0x28]if c['cached']else sentinels[x-0x28]);m.finish(y);return
 if a==0x140197310:ptr=nodes[x-0x30];m.wq(ptr,y);m.wq(ptr+8,z);m.wi(ptr+16,m.si(m.q(m.q(rsp+0x28))));m.finish(ptr);return
 if a==0x140197540:m.wq(y,z-16);m.finish(y);return
 if a==0x140198640 and x in[mnode+24,fnode+24]:cacheWrites.append(dict(file=files[male if x==mnode+24 else female],index=m.si(x-8)&0xffffffff,value=record(y)))
 if a==0x140166c60:m.finish(len(data[x]));return
 if a==0x140166d40:
  phase='entry'if(y&0xffffffff)<100 else'text';positions[x]=y&0xffffffff;io.append(['seek',files[x],y&0xffffffff]);m.finish(0 if c['fail']==phase+'Seek'and(x==female or not c['femaleOnly'])else 1);return
 if a==0x140166ca0:
  assert z==1;phase='entry'if positions[x]<100 else'text';size=w&0xffffffff;amount=size
  if c['fail']==phase+'Read'and(x==female or not c['femaleOnly']):amount=max(0,size-1)
  available=data[x][positions[x]:positions[x]+amount];amount=len(available)
  if amount:u.mem_write(y,available)
  positions[x]+=amount;io.append(['read',files[x],size,amount]);m.finish(amount);return
 if a==0x140286110:m.wi(y,c['ref']if pops==0 else c['requestedGender']);m.finish(c['pop1'if pops==0 else'pop2']);pops+=1;return
 if a==0x140286550:output=record(y)['text'];m.finish(c['push']);return
 if not any(lo<=a<hi for lo,hi in ranges):raise RuntimeError(f'Uncaptured TLK owner{a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def raw_file():
 raw=bytearray(100);entry=bytearray(40);struct.pack_into('<I',entry,0,c['flags']);entry[4:20]=bytes.fromhex(c['sound']).ljust(16,b'\0')[:16];struct.pack_into('<III',entry,28,c['offset'],c['length'],c['durationBits']);raw[20:60]=entry;raw[60:100]=entry;raw+=bytes.fromhex(c['text']);return bytes(raw)
def run(case):
 global c,cursor,warnings,parses,cacheWrites,data,positions,io,output,pops
 c=case;cursor=0x30000;warnings=[];parses=[];cacheWrites=[];positions={male:0,female:0};io=[];output=None;pops=0;u.mem_write(m.heap,bytes(0x20000));u.mem_write(m.stack,bytes(0x20000))
 m.wq(0x1412df968,table);m.wq(table+0x78,gsent);m.wq(table+0x88,gbuckets);m.wq(gsent,gsent);m.wq(gsent+8,gsent);m.wq(gbuckets,gsent);m.wq(gbuckets+8,gsent);u.mem_write(table+0x28,bytes([c['gender']]));m.wq(cmd+16,table)
 if c['override']:
  m.wq(gbuckets,overrideNode);m.wq(gbuckets+8,overrideNode);m.wq(overrideNode,gsent);m.wi(overrideNode+16,c['ref']);set_string(overrideNode+24,b'override<TOKEN>')
 data={male:raw_file(),female:raw_file()}
 for ptr,sent,buckets,nodeptr in[(male,msent,mbuckets,mnode),(female,fsent,fbuckets,fnode)]:
  m.wq(ptr+0x30,sent);m.wq(ptr+0x40,buckets);m.wq(sent,sent);m.wq(sent+8,sent);m.wq(buckets,sent);m.wq(buckets+8,sent);m.wi(ptr+0x14,0x302e3356);m.wi(ptr+0x1c,c['count']);m.wi(ptr+0x20,100);set_record(nodeptr+24,b'cached',b'CACHE',0x40200000)
  if ptr==female and c['femaleOnly']and c['fail']=='range':m.wi(ptr+0x1c,0)
 for offset,ptr in[(8,male),(16,female),(24,male),(32,female)]:m.wq(table+offset,0 if c['missingCustom']and offset>=24 or c['missingBase']and offset<24 else ptr)
 if c['sizeLimit']>=0:data={ptr:raw[:c['sizeLimit']]for ptr,raw in data.items()}
 set_record(out,b'initial',b'old',0x41100000)
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 regs=[table,c['ref'],out,c['parse']]if c['mode']=='fetch'else[cmd,0,c['argc'],0]
 for reg,v in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],regs):u.reg_write(reg,v&0xffffffffffffffff)
 u.emu_start(0x140198c60 if c['mode']=='fetch'else 0x140530e20,m.stop,count=100000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=c,result=u.reg_read(UC_X86_REG_RAX)&0xffffffff,value=record(out)if c['mode']=='fetch'else output,gender=u.mem_read(table+0x28,1)[0],warnings=warnings,parses=parses,cacheWrites=cacheWrites,io=io)
if __name__=='__main__':
 d=dict(mode='fetch',ref=0,gender=0,requestedGender=0,parse=0,flags=7,sound=b'UPPER_WAV'.hex(),durationBits=0x40200000,text=b'a\0tail'.hex(),offset=0,length=6,count=2,fail='',femaleOnly=False,cached=False,override=False,missingBase=False,missingCustom=False,sizeLimit=-1,pop1=1,pop2=1,push=1,argc=2)
 rows=[run(d|dict(ref=ref,gender=gender,parse=parse,flags=flags))for ref,gender,parse,flags in itertools.product([0,1,2,0x1000001,0xffffffff],[0,1,2,255],[0,1],[0,1,2,3,4,7])]
 rows +=[run(d|dict(gender=gender,fail=fail,femaleOnly=only,ref=ref))for gender,fail,only,ref in itertools.product([0,1],['range','entrySeek','entryRead','textSeek','textRead'],[False,True],[0,0x1000000])]
 rows +=[run(d|dict(gender=gender,cached=cached,override=override,parse=parse,missingBase=base,missingCustom=custom,ref=ref))for gender,cached,override,parse,base,custom,ref in itertools.product([0,1],[False,True],[False,True],[0,1],[False,True],[False,True],[0,0x1000000])]
 rows +=[run(d|dict(offset=offset,length=length,sizeLimit=size))for offset,length,size in itertools.product([0,7,0xfffffff0],[0,1,6,9],[-1,20,100])]
 rows +=[run(d|dict(mode='script',requestedGender=gender,argc=argc,pop1=pop1,pop2=pop2,push=push,ref=ref))for gender,argc,pop1,pop2,push,ref in itertools.product([-1,0,1,2,256],[1,2],[0,1],[0,1],[0,1],[0,0xffffffff])]
 outFile=m.root/'backups/animations/native-talk-table-observations.json';outFile.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2)+'\n');print(json.dumps(dict(output=str(outFile),rows=len(rows))))
