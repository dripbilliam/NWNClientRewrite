"""Execute original87b590 chat dispatch, original CExoString slicing/comparison,
and original roster lookup instructions over synthetic player records.
Allocation/copy/free/strchr/ASCII stricmp, application/network access, sender,
feedback and privilege boundaries are captured. No packets, game process,
console interpreter, GPU, private profile or public connection are executed.
"""
import importlib.util,itertools,json,struct,sys,re
from pathlib import Path
spec=importlib.util.spec_from_file_location('image',Path(__file__).with_name('inspect-native-intratile-coordinator.py'))
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
ranges=[[5377602960,5377608334],[5370195456,5370195527],[5370201872,5370202116],[5370195728,5370195825],[5370315232,5370315309],[5370406432,5370406483],[5375705216,5375705340],[5375705376,5375705500],[5375887632,5375887805],[5375887904,5375888077],[5368961216,5368961452]]
app,internal,gui,network,players,player0,player1,line,vt=[m.heap+n for n in [0x1000,0x2000,0x3000,0x4000,0x5000,0x6000,0x7000,0x8000,0x9000]]
senders={0x1407ba540:'dm',0x1407ba620:'party',0x1407ba700:'shout',0x1407ba7e0:'talk',0x1407ba8c0:'tell-id',0x1407ba9b0:'tell-name',0x1407baab0:'whisper'}
def cstring(ptr):
 if not ptr:return b''
 result=bytearray()
 while len(result)<65536:
  value=bytes(u.mem_read(ptr+len(result),1))
  if value==b'\0':return bytes(result)
  result.extend(value)
 raise AssertionError('Unbounded synthetic string')
def string(ptr):
 size=m.si(ptr+8)&0xffffffff;assert size<65536
 return bytes(u.mem_read(m.q(ptr),size)) if size and m.q(ptr) else b''
def allocate(size):
 global cursor
 assert 0<size<0x10000
 pointer=m.heap+cursor;cursor+=(size+15)&~15;assert cursor<0xf0000
 u.mem_write(pointer,bytes([0xa5])*size);return pointer
def write_string(ptr,text):
 data=text.encode('ascii');buf=allocate(len(data)+1);u.mem_write(buf,data+b'\0');m.wq(ptr,buf);m.wi(ptr+8,len(data));m.wi(ptr+12,len(data)+1)
def hook(u,a,n,_):
 x,y,z=[u.reg_read(reg) for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8]]
 if a==m.stop:u.emu_stop();return
 if a in [0x140c10324,0x140c10368]:m.finish(allocate(x));return
 if a in [0x140c10370,0x140c10410]:m.finish();return
 if a==0x140c417f0:
  if z:u.mem_write(x,bytes(u.mem_read(y,z)))
  m.finish(x);return
 if a==0x140c43180:
  data=cstring(x);at=data.find(bytes([y&255]));m.finish(x+at if at>=0 else 0);return
 if a==0x140c9a9fc:
  left,right=cstring(x).lower(),cstring(y).lower();m.finish(0 if left==right else -1 if left<right else 1);return
 if a==0x1406abbc0:m.finish(gui);return
 if a==0x1406abf90:m.finish(network);return
 if a==m.stop+0x100:m.finish(network);return
 if a in [0x1402377b0,0x1406aba10]:m.finish(0);return
 if a==0x1406aaf90:
  calls.append(dict(kind='feedback',code=y&0xffffffff));m.finish();return
 if a==0x1407c3390:
  calls.append(dict(kind='party',target=y&0xffffffff,command=z&0xffffffff));m.finish();return
 if a in senders:
  kind=senders[a]
  calls.append(dict(kind=kind,text=string(z if kind in ['tell-id','tell-name'] else y).decode('ascii'),**({'playerId':y&0xffffffff} if kind=='tell-id' else {'recipient':string(y).decode('ascii')} if kind=='tell-name' else {})))
  m.finish();return
 if not any(lo<=a<hi for lo,hi in ranges):raise RuntimeError(f'Uncaptured original dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(value,mode):
 global cursor,calls
 cursor=0x10000;calls=[];u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000))
 m.wq(0x1412df970,m.heap+0xa000);m.wq(m.heap+0xa000,app);m.wq(app+8,internal);m.wq(app,vt);m.wq(vt+0x38,m.stop+0x100);m.wq(internal+0x38,players);m.wi(internal+0x40,2)
 for index,(pointer,account,character,id) in enumerate([(player0,'Player Account','Two Words',7),(player1,'Other Account','Ada',8)]):
  m.wq(players+index*8,pointer);m.wi(pointer+8,id);m.wi(pointer+0x34,77+index);m.wi(pointer+0x38,88+index)
  write_string(pointer+0x10,account);write_string(pointer+0x40,character)
 write_string(line,value);rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,line);u.reg_write(UC_X86_REG_RDX,mode)
 try:u.emu_start(0x14087b590,m.stop,count=200000)
 except Exception as error:raise RuntimeError(dict(value=value,mode=mode,rip=hex(u.reg_read(UC_X86_REG_RIP)),registers={name:hex(u.reg_read(reg)) for name,reg in [('rcx',UC_X86_REG_RCX),('rdx',UC_X86_REG_RDX),('rdi',UC_X86_REG_RDI),('rax',UC_X86_REG_RAX)]})) from error
 assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(value=value,mode=mode,calls=calls)
values=['',' ', 'hello', '/unknown custom', '/unknown', '/t Ada hello','/tell "Two Words" hello','/tp "Player Account" hello','/tellplayer "Other Account" hello','/T "Two Words"hello','/tp "Player Account"hello','/t "Incomplete','/t Ada','/t "Two Words"','/t "" hello','/tp "player account" hello','/t ada hello','/o "Unlisted Character" hello','/o hello','/invite Player Account','/invite Missing','/accept','/d unavailable']
values += ['/invite Two Words','/invite Ada','/accept extra','/Tp "Player Account" hello','/']
values += ['/'+command+suffix for command,suffix in itertools.product(['s','w','p','dm','tk','talk'],['  payload','',' ',' payload'])]
rows=[run(value,mode) for value,mode in itertools.product(values,range(5))]
name=next((arg.split('=',1)[1] for arg in sys.argv[1:] if arg.startswith('--report=')),'native-chat-dispatch-v2.json')
assert re.fullmatch(r'native-chat-dispatch-[a-z0-9-]+\.json',name),'Invalid evidence filename'
out=m.root/'backups/animations'/name;assert not out.exists(),'Preserve prior evidence'
out.write_text(json.dumps(dict(target=m.digest,scope=__doc__,entry='0x14087b590',cases=rows),indent=2)+'\n')
print(json.dumps(dict(output=str(out),cases=len(rows),sample=rows[:12])))

