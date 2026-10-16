"""Read-only original CNWMessage reader executions, including complete setup,
scalar decoding, type checks and overflow/underflow owners. Packets originate
from the original writer fixture; known A5 physical tail bytes are explicitly
supplied for malformed overreads. Allocation/free/log formatting are captured
lower boundaries. No network traffic or live process changes.
"""
import importlib,sys,json,itertools,struct,random
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
w=importlib.import_module('inspect-native-message-writer');m=w.m;u=m.u;u.hook_del(w.hook_handle)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
packet=m.heap+0x9000
addresses={'unsigned':0x1402da210,'signed':0x1402da1a0,'bool':0x1402d9600,'byte':0x1402d9630,'word':0x1402da450,'dword':0x1402d9bc0,'dword64':0x1402d9b50,'int':0x1402d9ec0,'float':0x1402d9c30,'range':0x1402d9d40,'bits':0x1402d9700,'bit':0x1402d96b0,'expect':0x1402d5560,'overflow':0x1402d9460,'underflow':0x1402d9520}
ranges=[(0x1402da7b0,0x1402da892),(0x1402da210,0x1402da3f1),(0x1402da1a0,0x1402da204),(0x1402d9600,0x1402d9629),(0x1402d9630,0x1402d96aa),(0x1402da450,0x1402da4bd),(0x1402d9bc0,0x1402d9c2c),(0x1402d9b50,0x1402d9bbf),(0x1402d9ec0,0x1402d9f3d),(0x1402d9c30,0x1402d9d33),(0x1402d9d40,0x1402d9e41),(0x1402d9700,0x1402d97ca),(0x1402d96b0,0x1402d96f7),(0x1402d5560,0x1402d5648),(0x1402d9460,0x1402d9512),(0x1402d9520,0x1402d95e2)]

def hook(u,a,n,_):
 if a==m.stop:u.emu_stop();return
 if a==0x14016afb0:
  diagnostics.append(dict(kind='typeMismatch',expected=u.reg_read(UC_X86_REG_R8)&0xffffffff,actual=u.reg_read(UC_X86_REG_R9)&0xffffffff));m.finish();return
 if a==0x140115890:
  line=m.si(u.reg_read(UC_X86_REG_RSP)+0x28)
  if line!=0x29e:diagnostics.append(dict(kind={0x15c:'fragmentOffset',0x505:'overflow',0x511:'overflow',0x51c:'underflow',0x528:'underflow'}[line]))
  m.finish();return
 if any(lo<=a<hi for lo,hi in ranges):return
 w.hook(u,a,n,_)
hook_handle=u.hook_add(UC_HOOK_CODE,hook)

def state():
 return {key:m.si(w.message+offset)&0xffffffff for key,offset in [('byteSize',0x40),('byteCursor',0x44),('fragmentSize',0x50),('fragmentCursor',0x54),('fragmentOffset',0x58),('flag',0x60),('playerId',0x64)]}|dict(curBit=u.mem_read(w.message+0x5c,1)[0],lastBits=u.mem_read(w.message+0x5d,1)[0])

def run(case):
 global diagnostics
 diagnostics=[];w.cursor=0x10000
 u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));m.wq(0x1412df970,w.app);m.wi(w.app+0x28,case['format']);w.call(0x1402d4830)
 observations=[]
 for op in case['ops']:
  name=op[0];result=None
  if name=='set':
   data=None if op[1] is None else bytes.fromhex(op[1]);ptr=0 if data is None else packet
   if data is not None:u.mem_write(packet,data)
   m.wi(m.stack+0x1fe30,1)
   result=w.call(0x1402da7b0,[w.message,ptr,op[2],0x80000001])
  elif name in ['float','range']:
   args=[w.message,0,op[2],0] if name=='float' else [w.message,0,0,op[3]]
   w.call(addresses[name],args,[op[1]] if name=='float' else [op[1],op[2]])
   result=f'{u.reg_read(UC_X86_REG_XMM0)&0xffffffff:08x}'
  else:
   w.call(addresses[name],[w.message,op[1] if len(op)>1 else 0,op[2] if len(op)>2 else 1,0]);value=u.reg_read(UC_X86_REG_RAX)
   if name in ['unsigned','bits','dword64']:result=str(value)
   elif name=='signed':result=str(value if value<1<<63 else value-(1<<64))
   elif name in ['byte','bool','bit']:result=value&255
   elif name=='word':result=value&65535
   elif name=='expect':result=None
   else:result=value&0xffffffff;result=result-(1<<32) if name=='int' and result>=1<<31 else result
  observations.append(dict(result=result,state=state(),diagnostics=list(diagnostics)));diagnostics=[]
 return dict(case=case,observations=observations)

if __name__=='__main__':
 rows=[]
 source=json.loads((m.root/'backups/animations/native-message-writer-observations.json').read_text())
 for sourceRow in source['rows']:
  c=sourceRow['case'];ops=c['ops']
  if any(op[0] in ['create','get'] for op in ops):continue
  data=sourceRow['observations'][-1]['hex']
  if data is None:continue
  body=data[6:];readOps=[['set',body+'a5'*16,len(body)//2]]
  for op in ops:
   name=op[0]
   if name=='float':readOps.append([name,op[2],op[3]])
   elif name=='bool':readOps.append([name])
   else:readOps.append([name,op[2],op[3] if len(op)>3 else 1])
  readOps.extend([['overflow'],['underflow']]);rows.append(run(dict(format=c['format'],ops=readOps)))
 # Physical tails are known independently of declared packet length. Probe all
 # raw widths and setup failures, plus reuse preserving old fragment pointers.
 for mode,boundary,declared in itertools.product([0,1,2],[0,3,4,7,8,15,30],[0,1,3,4,5,8,16]):
  data=struct.pack('<I',boundary)+bytes(range(4,64));rows.append(run(dict(format=mode,ops=[['set',data.hex(),declared],['overflow'],['underflow']])))
 for mode,name,bits,declared in itertools.product([0,1],['unsigned','signed','byte','word','dword','dword64','int','bits'],[1,7,8,9,16,24,31,32,33,40,63,64],[5,8,12]):
  data=struct.pack('<I',7)+bytes([3,1,2,7,5,9,11,8])+bytes([0xa5])*68
  rows.append(run(dict(format=mode,ops=[['set',data.hex(),declared],[name,bits],['overflow'],['underflow']])))
 for mode,min_,max_,bits in itertools.product([0,1],[-100.,0.,1.25],[0.,100.,-3.5],[1,7,16,31,32,40,63,64]):
  data=struct.pack('<I',28)+bytes([0xa5])*92
  rows.append(run(dict(format=mode,ops=[['set',data.hex(),80],['range',min_,max_,bits],['overflow'],['underflow']])))
 for mode in [0,1]:
  data=struct.pack('<I',7)+bytes([0xa5])*60
  rows.append(run(dict(format=mode,ops=[['set',data.hex(),16],['bits',64],['bit',3],['set',None,0],['bits',17],['overflow'],['underflow']])))
  rows.append(run(dict(format=mode,ops=[['set',None,0],['bits',17],['bit',3],['signed',64],['overflow'],['underflow']])))
 # Independent cross-implementation check: original readers consume bytes
 # emitted by the replacement during installed Prelude area-header probes.
 live=json.loads((m.root/'backups/animations/live-client-area-message.json').read_text())
 for report in live['reports']:
  body=report['headerOnlyPacketHex'][6:]
  rows.append(run(dict(format=report['formatMode28'],source='replacement-client-area-header',areaId=report['areaId'],ops=[['set',body,len(body)//2],['int',32],*[['float',1.,32] for _ in range(4)],['bool'],['overflow'],['underflow']])))
 out=m.root/'backups/animations/native-message-reader-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2));print(json.dumps(dict(output=str(out),rows=len(rows))))
