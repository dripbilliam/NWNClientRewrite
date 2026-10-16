"""Read-only complete ClientArea sender1404cd9d0..1404ce035.
Original loading-screen loops, reset ordering, float argument handling and
atan2f execute unchanged. Canonical lookups, table/string reads, SetBMP, LUO
map cleanup, message writing/area packing/payload/transport are captured lower
boundaries. This is not a packet-byte or complete client-load protocol oracle.
"""
import importlib,sys,json,itertools,struct
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
m=importlib.import_module('inspect-native-intratile-coordinator')
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
message,client,area,module,app,rules,twodas,table,info,orientation,lastmap,payload=[m.heap+i*0x1000 for i in range(12)]
def signed(v):return struct.unpack('<i',struct.pack('<I',v&0xffffffff))[0]
def text(ptr):
 p=m.q(ptr);return bytes(u.mem_read(p,m.si(ptr+8))).decode('ascii') if p else ''
def string(ptr,value):
 global cursor
 data=value.encode('ascii');p=m.heap+cursor;cursor+=len(data)+16;u.mem_write(p,data+b'\0');m.wq(ptr,p);m.wi(ptr+8,len(data));m.wi(ptr+12,len(data)+1)
def hook(u,a,n,_):
 global cursor,randoms,queryCount,user
 if a==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(r) for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
 if a==0x14055b6e0:calls.append(['module']);m.finish(module if c.get('module',True) else 0)
 elif a==0x14055b980:calls.append(['mode']);m.finish(c.get('mode',2))
 elif a==0x1404ba840:calls.append(['clientObject']);m.finish(app if c.get('object',True) else 0)
 elif a==0x1404c2ac0:calls.append(['clearLastMap']);m.finish()
 elif a==0x1402d54a0:calls.append(['create',y,z&0xffffffff,w&0xffffffff]);m.finish(0)
 elif a==0x1404be490:
  value=signed(y);valueText=text(z);calls.append(['setBmp',value,valueText]);m.wi(x+0x20,value)
  if value==1:user=valueText
  m.finish()
 elif a==0x1401a68f0:
  column=text(z);calls.append(['loadingString',signed(y),column]);rows=c.get('secondRows',c['rows']) if column=='TILESET' else c['rows'];entry=rows[y];string(w,entry.get('value',''));m.finish(entry.get('status',1));queryCount+=1
 elif a==0x14016ae00:m.finish(int(text(x).lower()==text(y).lower()))
 elif a==0x140c7ed00:
  value=c['random'][min(randoms,len(c['random'])-1)];randoms+=1;calls.append(['random']);m.finish(value)
 elif a==0x1402db5a0:calls.append(['writeInt',signed(y),z&0xffffffff]);m.finish()
 elif a==0x1402db240:calls.append(['writeFloat',m.xmm(UC_X86_REG_XMM1),m.xmm(UC_X86_REG_XMM2),w&0xffffffff]);m.finish()
 elif a==0x1402da920:calls.append(['writeBool',signed(y)]);m.finish()
 elif a==0x140363200:calls.append(['packArea',signed(y),signed(z),signed(w)]);m.finish(c.get('pack',1))
 elif a==0x1402d5880:calls.append(['payload']);m.wq(y,payload);m.wi(z,3);m.finish(c.get('payload',1))
 elif a==0x1404dc490:calls.append(['send',y&0xffffffff,z&255,w&255,[1,2,3],m.si(rsp+0x30)]);m.finish(c.get('send',1))
 elif a==0x140115890:
  # Separate native warning sites retain whether selection or player supplied1.
  calls.append(['warning','selected' if m.q(rsp)==0x1404cde44 else 'player']);m.finish()
 elif a==0x140c10368:p=m.heap+cursor;cursor+=max(16,x);m.finish(p)
 elif a==0x140c10370:m.finish()
 elif a==0x140c417f0:
  if z:u.mem_write(x,bytes(u.mem_read(y,z)))
  m.finish(x)
 elif a==0x140c10410:m.finish(u.reg_read(UC_X86_REG_RAX))
 elif a==0x140cae8e0:m.finish()
 elif not any(lo<=a<hi for lo,hi in [(0x1404cd9d0,0x1404ce035),(0x140c8f29c,0x140c8f6ad)]):raise RuntimeError(f'Unmapped ClientArea dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,calls,cursor,randoms,queryCount,user
 c=case;calls=[];cursor=0x20000;randoms=queryCount=0;user='custom';u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000))
 m.wq(0x1412df970,app);m.wq(app+8,app);m.wq(0x1412df8f8,rules);m.wq(rules+0x130,twodas);m.wq(twodas+0x118,table);m.wi(table+0x50,len(c['rows']));m.wq(module+0x108,info)
 for i,value in enumerate(c.get('packFloats',[2.9,-3.9,4.1])):m.wf(info+0x14+i*4,value)
 m.wi(client+0x20,c['bmp']);m.wi(client+0x48,42);m.wq(client+0xa8,lastmap if c.get('lastMap',True) else 0);u.mem_write(area+0x350,struct.pack('<H',c['defaultBmp']&65535));u.mem_write(area+0x1a8,c['tileset'].encode('ascii').ljust(17,b'\0'));u.mem_write(payload,b'\1\2\3')
 for i,value in enumerate(c.get('orientation',[1,0,0])):m.wf(orientation+i*4,value)
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8],[message,client,area if c.get('area',True) else 0]):u.reg_write(reg,value)
 point=c.get('point',[1.1,-2.2,3.3]);u.reg_write(UC_X86_REG_XMM3,int.from_bytes(struct.pack('<f',point[0]),'little'));m.wf(rsp+0x28,point[1]);m.wf(rsp+0x30,point[2]);m.wq(rsp+0x38,orientation);m.wi(rsp+0x40,c.get('flag',-2))
 try:u.emu_start(0x1404cd9d0,m.stop,count=100000)
 except Exception:print(json.dumps(dict(case=c,rip=hex(u.reg_read(UC_X86_REG_RIP)),calls=calls)));raise
 assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=c,calls=calls,result=signed(u.reg_read(UC_X86_REG_RAX)),bmp=m.si(client+0x20),user=user)
if __name__=='__main__':
 baseRows=[{}, {},dict(value='tni01'),dict(value='TNI01'),dict(value='ttf01'),dict(value='tni01',status=0)]
 tables=[baseRows,[{}, {},dict(value='ttf01'),dict(value='tdc01')],[{}, {},dict(value='tni01',status=2),dict(value='tni01',status=0)],[{}, {},dict(value='tni01')]]
 default=dict(bmp=-1,defaultBmp=0,tileset='tni01',rows=baseRows,random=[1,2]);rows=[]
 for bmp,defaultBmp,table_,random_ in itertools.product([-2,-1,0,1,2,5,6],[0,1,2,65535],tables,[0,1,3,32767]):rows.append(run(default|dict(bmp=bmp,defaultBmp=defaultBmp,rows=table_,random=[random_])))
 for mode,module_,object_,area_,lastMap in itertools.product([0,2,65538],[False,True],[False,True],[False,True],[False,True]):rows.append(run(default|dict(mode=mode,module=module_,object=object_,area=area_,lastMap=lastMap)))
 for pack,payload_,send_,orientation_ in itertools.product([0,1,2],[0,1,-1],[0,1,2],[[1,0,0],[-1,-0.,0],[0,-1,0],[.3,.9,2]]):rows.append(run(default|dict(bmp=2,pack=pack,payload=payload_,send=send_,orientation=orientation_)))
 rows += [run(default|dict(bmp=0,secondRows=[{}]*6)),run(default|dict(bmp=2,packFloats=[2147483648,-2147483648,16777217]))]
 out=m.root/'backups/animations/native-client-area-message-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2));print(json.dumps(dict(output=str(out),rows=len(rows))))
