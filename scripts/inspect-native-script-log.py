"""Complete original PrintLogEntry, GetCurrentTimestamp and DebugInfo_String
owners. Typed VM/string transfers, CRT clock/ctime/formatting, logger, config,
player list, owning string codec and transport are captured lower boundaries.
Original branch/iteration/format choice, timestamp truncation/assignment and
debug-mode getter execute. This is not a network/client debug-window oracle.
"""
import importlib,sys,json,itertools,datetime
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
cmd,app,internal,exo,players,array,client0,client1,text,timestamp,result,payload,allocated=[m.heap+i*0x2000 for i in range(1,14)]
ranges=[(0x1405397b0,0x140539a61),(0x140165230,0x140165336),(0x1404d5ce0,0x1404d5da4),(0x14055b410,0x14055b41b)]

def string(ptr):
 out=bytearray()
 while ptr:
  byte=u.mem_read(ptr,1)[0]
  if not byte:break
  out.append(byte);ptr+=1
 return out.decode('cp1252')

def exostring(ptr,data,storage):
 u.mem_write(storage,data+b'\0');m.wq(ptr,storage if data else 0);m.wi(ptr+8,len(data));m.wi(ptr+12,len(data)+1 if data else 0)

def hook(u,a,n,_):
 global frees,sends
 if a==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(r)for r in[UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
 if a==0x1402861b0:
  calls.append(['pop','string']);exostring(y,b''if c.get('nullText')else bytes.fromhex(c['hex']),text);m.finish(c['pop']);return
 if a==0x140164ee0:
  calls.append(['timestamp']);exostring(y,b''if c.get('nullTimestamp')else bytes.fromhex(c['timestampHex']),timestamp);m.finish();return
 if a==0x140115890:
  calls.append(['log',dict(flags=[x,y],function=string(z),file=string(w),line=m.si(rsp+0x28),format=string(m.q(rsp+0x30)),timestamp=string(m.q(rsp+0x38)),text=string(m.q(rsp+0x40)))]);m.finish(c['loggerResult']);return
 if a==0x14055b410:calls.append(['debugMode']) # execute the actual getter
 if a==0x14003dc20:
  data=bytes(u.mem_read(y,z));m.wq(x,allocated);m.wq(x+16,len(data));m.wq(x+24,len(data));u.mem_write(allocated,data+b'\0');m.finish(x);return
 if a==0x140119650:calls.append(['configBool',string(m.q(y)),bool(z&255)]);m.finish(c['config']);return
 if a==0x14016afb0:
  fmt=string(y);assert fmt=='[ServerLog:%s] %s';data=(fmt.replace('%s',string(z),1).replace('%s',string(w),1)).encode('cp1252')
  # Avoid substituting a %s that occurs inside the timestamp argument.
  data=('[ServerLog:'+string(z)+'] '+string(w)).encode('cp1252');exostring(x,data,allocated+0x100);m.finish();return
 if a==0x14055b8e0:calls.append(['players']);m.finish(players);return
 if a==0x14055b810:calls.append(['message']);m.finish(app);return
 if a==0x1404d5ce0 and c['mode']=='script':
  calls.append(['send',0 if y==client0 else 1 if y==client1 else None,string(m.q(z))]);sends+=1
  if c.get('mutateList')and sends==1:m.wi(players+8,0);m.wq(array+8,client0)
  m.finish(c['sendResult']);return
 if a in[0x140c10360,0x140c10370]:frees+=1;m.finish();return
 if a==0x140c10410:m.finish(u.reg_read(UC_X86_REG_RAX));return
 if a==0x140c8b3c0:m.wq(x,123456789);calls.append(['time']);m.finish(123456789);return
 if a==0x140c8abbc:u.mem_write(timestamp,bytes.fromhex(c['ctimeHex'])+b'\0');calls.append(['ctime']);m.finish(timestamp);return
 if a==0x140047000:
  fmt=string(y);assert fmt=='%.19s';u.mem_write(x,string(z).encode('cp1252')[:19]+b'\0');calls.append(['format',fmt]);m.finish();return
 if a==0x140c10368:m.finish(allocated);return
 if a==0x140c417f0:u.mem_write(x,bytes(u.mem_read(y,z)));m.finish(x);return
 if a==0x1402d54a0:calls.append(['create',y&0xffffffff,z&0xffffffff,w&0xffffffff]);m.finish();return
 if a==0x14003d8c0:
  data=bytes(u.mem_read(y,z));calls.append(['copy',data.hex(),z]);exostring(x,data if data and data[0]else b'',allocated);m.finish(x);return
 if a==0x1402dab50:
  calls.append(['writeString',bytes(u.mem_read(m.q(y),m.si(y+8))).hex()if m.q(y)else'',z]);m.wq(y,0);m.wq(y+8,0);m.finish();return
 if a==0x1402d5880:m.wq(y,payload);m.wi(z,17);m.finish(c['payloadStatus']);return
 if a==0x1404dc490:calls.append(['transport',y&0xffffffff,z&255,w&255,m.si(rsp+0x30)]);m.finish(c['sendResult']);return
 if not any(lo<=a<hi for lo,hi in ranges):raise RuntimeError(f'Uncaptured script log dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)

def run(case):
 global c,calls,frees,sends
 c=case;calls=[];frees=0;sends=0;u.mem_write(m.heap,bytes(0x30000));u.mem_write(m.stack,bytes(0x20000))
 m.wq(0x1412df970,cmd);m.wq(cmd+8,app);m.wq(app+8,internal);m.wi(internal+0x100f0,c['debugMode']);m.wq(0x1412df8b8,exo);m.wq(exo,exo);m.wq(exo+0x18,exo);m.wq(players,array);m.wi(players+8,c['count']);m.wi(client0+0x48,c['playerId'])
 for index,which in enumerate(c['players']):m.wq(array+index*8,client0 if which==0 else client1)
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 regs=[cmd,560,1,0]if c['mode']=='script'else[exo,result,0,0]if c['mode']=='timestamp'else[app,client0,result,0]
 if c['mode']=='sender':exostring(result,b''if c.get('nullText')else bytes.fromhex(c['hex']),text)
 if c['mode']=='timestamp':exostring(result,b'old value',text)
 for register,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],regs):u.reg_write(register,value)
 try:u.emu_start({'script':0x1405397b0,'timestamp':0x140165230,'sender':0x1404d5ce0}[c['mode']],m.stop,count=10000)
 except Exception as error:raise RuntimeError(f'Oracle fixture failure RIP={u.reg_read(UC_X86_REG_RIP):x} case={c} calls={calls}')from error
 assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=c,result=u.reg_read(UC_X86_REG_RAX)&0xffffffff,calls=calls,frees=frees,timestamp=string(m.q(result))if c['mode']=='timestamp'else None)

if __name__=='__main__':
 d=dict(mode='script',hex='4125730042',timestampHex='536174204f63742031372031373a32333a3034',debugMode=0,config=0,pop=1,loggerResult=0,sendResult=1,payloadStatus=1,playerId=0xfedcba98,count=3,players=[1,0,1])
 rows=[run(d|dict(hex=text,debugMode=mode,config=config,pop=pop,sendResult=sent))for text,mode,config,pop,sent in itertools.product(['','4125730042','80ff','6c696e65310a6c696e6532'],[0,1,2,0xffffffff],[0,1],[0,1],[0,2])]
 rows +=[run(d|dict(debugMode=1,config=1,count=count,players=values))for count,values in[(0,[]),(-1,[]),(1,[0]),(3,[0,1,0])]]
 rows +=[run(d|dict(debugMode=1,config=1,mutateList=True)),run(d|dict(debugMode=1,config=1,nullText=True,nullTimestamp=True))]
 for date in[datetime.datetime(2026,10,17,17,23,4),datetime.datetime(2026,1,1,0,0,0),datetime.datetime(2024,2,29,23,59,59),datetime.datetime(1999,12,5,3,4,5)]:
  rows.append(run(d|dict(mode='timestamp',ctimeHex=date.ctime().encode('ascii').hex(),date=[date.year,date.month,date.day,date.hour,date.minute,date.second])))
 rows +=[run(d|dict(mode='timestamp',ctimeHex=text.encode('ascii').hex()))for text in['','x','1234567890123456789','12345678901234567890','Sun Jan  1 00:00:00 2023\n']]
 rows +=[run(d|dict(mode='sender',hex=text,payloadStatus=status,sendResult=sent))for text,status,sent in itertools.product(['','0041','410042','80ff','412573'],[0,1],[0,1,7,0xffffffff])]
 out=m.root/'backups/animations/native-script-log-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2)+'\n');print(json.dumps(dict(output=str(out),rows=len(rows))))
