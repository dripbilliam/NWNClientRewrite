"""Original CRC table construction, FrameSend, FrameNumberBetween and FrameReceive.

Allocation, frame storage, ordered-delivery enqueue, timers and send are captured
boundaries. Header/CRC/ring-window/ACK/NAK and packed/fragmented assembly execute
unchanged. This does not prove compression, full queue ownership or scheduling.
"""
import importlib,sys,json,struct,itertools
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
from capstone import Cs,CS_ARCH_X86,CS_MODE_64
u.hook_del(m.hook_handle)
owner=0x500000000;u.mem_map(owner,0x2900000)
window,storage,body,app=[m.heap+i*0x1000 for i in range(1,5)]
ranges=[]
for name in ['network-layer-ctor','network-reliable-frame-send','network-reliable-frame-between','network-reliable-frame-receive','network-frame-unpacketize','network-send-bndm','network-packetize-send','network-packetize-small']:
 d=json.loads((m.root/'backups/animations'/('rea-'+name+'.json')).read_text())['structuredContent']['normalized_result']
 ranges.extend((int(r['start'],16),int(r['end'],16)+1)for r in d['procedure']['body']['ranges'])
def alloc(n):
 global cursor
 p=m.heap+cursor;cursor+=(n+31)&~15;assert cursor<0xf0000;u.mem_write(p,bytes(n));return p
def hook(u,a,n,_):
 global cursor,next_frame
 if a==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(r)for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
 rsp=u.reg_read(UC_X86_REG_RSP)
 if a in [0x140c10324,0x140c10368]:m.finish(alloc(x));return
 if a in [0x140c10370,0x140c11414]:m.finish();return  # free/vector constructors outside CRC scope
 if a==0x14003e0e0:m.finish();return  # captured ScopeGuard allocation cleanup
 if a==0x140c42060:u.mem_write(x,bytes([y&255])*z);m.finish(x);return
 if a==0x140c417f0:u.mem_write(x,bytes(u.mem_read(y,z)));m.finish(x);return
 if a==0x14016dd40:m.finish(1000);return
 if a==0x1402511f0:calls.append(['send',bytes(u.mem_read(z,w)).hex()]);m.finish(1);return
 if a==0x140171510:
  m.wq(z,frame_data[y][0]);m.wi(w,frame_data[y][1]);m.finish(1);return
 if a==0x1401717c0:next_frame+=1;m.finish(next_frame);return
 if a==0x140171920:
  p=alloc(w);u.mem_write(p,bytes(u.mem_read(z,w)));frame_data[y]=(p,w);m.finish(1);return
 if a==0x140171120:calls.append(['reference',y,z if z<0x80000000 else z-0x100000000]);m.finish(1);return
 if a==0x1401716f0:m.finish(frame_data[y][0]);return
 if a==0x1400a1bb0:
  queue='high' if x==window+0x188 else 'low';calls.append(['deliver',queue,y]);m.finish();return
 if a==0x140245d70:calls.append(['load']);m.finish();return
 if a==0x140255c80:calls.append(['message',y,bytes(u.mem_read(z,w)).hex()]);m.finish(1);return
 if a==0x14024efc0:calls.append(['queue',y,z,bytes(u.mem_read(w,m.si(rsp+0x28))).hex()]);m.finish(1);return
 if a==0x140115890:calls.append(['diagnostic']);m.finish();return
 if a==0x140c10410:m.finish(u.reg_read(UC_X86_REG_RAX));return
 if not any(lo<=a<hi for lo,hi in ranges):raise RuntimeError(f'Uncaptured frame dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def call(address,args):
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 for r,v in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],args):u.reg_write(r,v)
 u.emu_start(address,m.stop,count=300000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return u.reg_read(UC_X86_REG_RAX)&0xffffffff
def reset():
 global cursor,calls,frame_data,next_frame
 cursor=0x10000;calls=[];frame_data={};next_frame=100
 u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000))
 m.wq(window+8,owner);m.wi(window+0x18,12);m.wi(window+0x930,16);m.wi(window+0x934,16)
 m.wi(window+0x28,16);m.wi(window+0x30,1);m.wi(window+0x38,2000);m.wi(window+0x34,3500)
 m.wq(owner+0xa4e10,storage);m.wq(0x1412df8b8,app)
 # Resolve the original global load rather than borrowing a server RVA.
 ins=next(Cs(CS_ARCH_X86,CS_MODE_64).disasm(m.pe.get_data(0x55b2d0,7),0x14055b2d0))
 global_app=ins.address+ins.size+int.from_bytes(ins.bytes[-4:],'little',signed=True)
 m.wq(global_app,app);m.wi(app+0x30,60000)
 u.mem_write(0x14141e310,b'\0')  # captured disabled instrumentation, not target mutation
reset();call(0x1402381c0,[owner,0]);table=[m.si(owner+0x28a4e18+i*4)&0xffffffff for i in range(256)]
sends=[]
for kind,seq,expected,compressed,payload in [(1,0,0,0,''),(2,0,0,0,''),(1,65535,65535,1,''),(0,0,0,0,'010203'),(0,65535,1,1,'ff'*960),(0,256,257,0,'aabb')]:
 reset();m.wi(window+0x24,expected);m.wi(window+0x170,compressed)
 raw=bytearray(12)+bytes.fromhex(payload);raw[7]=8;raw[8:10]=b'\0\1';raw[10:12]=len(bytes.fromhex(payload)).to_bytes(2,'big')
 u.mem_write(body,bytes(raw));frame_data[7]=(body,len(raw));call(0x14023d1e0,[window,kind,seq,7])
 sends.append(dict(kind=kind,sequence=seq,expected=expected,compressed=compressed,input=bytes(raw).hex(),calls=calls))
between=[]
for first,candidate,end in itertools.product([0,1,15,16,32767,65534,65535],repeat=3):
 reset();between.append(dict(first=first,candidate=candidate,end=end,result=call(0x14023c5a0,[window,first,candidate,end])))
receives=[]
for name,expected,first,end,incoming in [
 ('in-order',0,0,0,[(0,0,65535,8)]),
 ('duplicate',0,0,0,[(0,0,65535,8),(0,0,65535,8)]),
 ('reorder',0,0,0,[(0,1,65535,0),(0,0,65535,8)]),
 ('outside-window',0,0,0,[(0,16,65535,8)]),
 ('wrap',65535,0,0,[(0,0,65535,8),(0,65535,65535,8)]),
 ('ack-all',0,0,3,[(1,0,2,0)]),
 ('ack-stale',0,0,3,[(1,0,65535,0)]),
 ('ack-future',0,0,3,[(1,0,3,0)]),
 ('ack-wrap',0,65534,1,[(1,0,0,0)]),
 ('nak',0,0,3,[(2,0,0,0)]),
 ('invalid-kind',0,0,0,[(3,0,0,0)]),
]:
 reset();m.wi(window+0x24,expected);m.wi(window+0x28,(expected+16)&65535);m.wi(window+0x1c,first);m.wi(window+0x20,end);m.wi(window+0x2c,(end-first)&65535)
 for seq in range((end-first)&65535):
  number=(first+seq)&65535;identifier=number%16+7;p=alloc(12);u.mem_write(p,bytes(12));frame_data[identifier]=(p,12);u.mem_write(window+100+(number%16)*2,struct.pack('<H',identifier))
 steps=[]
 for kind,seq,ack,flags in incoming:
  raw=bytearray(12);raw[3:5]=seq.to_bytes(2,'big');raw[5:7]=ack.to_bytes(2,'big');raw[7]=(kind<<4)|flags
  u.mem_write(body,bytes(raw));calls=[];result=call(0x14023c5d0,[window,body,len(raw)])
  steps.append(dict(input=bytes(raw).hex(),result=result,calls=calls,first=m.si(window+0x1c),next=m.si(window+0x20),expected=m.si(window+0x24),end=m.si(window+0x28),pending=m.si(window+0x2c),nakEnabled=m.si(window+0x30)))
 receives.append(dict(name=name,expected=expected,first=first,next=end,steps=steps))
def message_frame(payload,count=1,flags=8):
 raw=bytearray(12);raw[0]=77;raw[7]=flags;raw[8:10]=count.to_bytes(2,'big');raw[10:12]=len(payload).to_bytes(2,'big');return bytes(raw)+payload
assembly=[]
for name,high,frames in [
 ('single',1,[message_frame(b'one')]),
 ('packed',1,[message_frame(b'one')+message_frame(b'two')]),
 ('three-fragments',1,[message_frame(b'first',3),message_frame(b'second',0),message_frame(b'third',0)]),
 ('waiting',1,[message_frame(b'first',2)]),
 ('low',0,[message_frame(b'low',flags=0)]),
]:
 reset();m.wi(window+0x14,123)
 pointer=alloc(len(frames)*2);queue=window+(0x188 if high else 0x198);m.wq(queue,pointer);m.wi(queue+8,len(frames));m.wi(queue+12,len(frames))
 for i,raw in enumerate(frames):
  p=alloc(len(raw));u.mem_write(p,raw);frame_data[7+i]=(p,len(raw));u.mem_write(pointer+i*2,struct.pack('<H',7+i))
 result=call(0x1402566d0,[window,high]);assembly.append(dict(name=name,high=high,frames=[b.hex()for b in frames],result=result,calls=calls,remaining=m.si(queue+8)))
packets=[]
for length in [3,947,948,949,1896,1897]:
 reset();u.mem_write(owner+0x68,bytes(0x960*255))
 for i in range(255):m.wi(owner+i*0x960+0x7c,0xfffffffe)
 m.wi(owner+0x78,1);m.wi(owner+0x7c,0);payload=bytes((i*37+19)&255 for i in range(length));u.mem_write(body,payload)
 # Fifth ABI argument flags0 selects the high-priority uncompressed path.
 m.wq(m.stack+0x1fe08+0x28,0);result=call(0x14024d1e0,[owner,0,body,length])
 pending=m.si(owner+0x994);raw=bytes(u.mem_read(owner+0x5d0,pending)).hex()if pending else None
 packets.append(dict(payload=payload.hex(),result=result,calls=calls,pending=raw))
reset();call(0x1402505b0,[owner,12]);disconnect=calls
output=m.root/'backups/animations/native-network-frame-observations.json'
output.write_text(json.dumps(dict(target=m.digest,limits=__doc__,crcTable=table,sends=sends,between=between,receives=receives,assembly=assembly,disconnect=disconnect,packetization=packets),indent=2)+'\n')
print(json.dumps(dict(sends=len(sends),between=len(between),receives=len(receives),assembly=len(assembly),output=str(output))))
