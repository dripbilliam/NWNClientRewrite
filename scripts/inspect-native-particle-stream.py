"""Execute original particle stream lock/commit/upload instructions read-only.
The original PE is SHA-checked and unchanged. RenderInterface dispatch is routed
to its analyzed GL implementation. GL allocation, binding and upload calls are
captured, not executed. This verifies byte ranges, not GPU timing or complete
particle rendering. No native game process or server connection is opened.
"""
import importlib,itertools,json
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
stream,pools,data=[m.heap+n*0x1000 for n in range(3)]
buffer_data,buffer_subdata,gen_buffer=[m.stop+n*0x100 for n in range(1,4)]
ranges=[(0x1400bd890,0x1400bd8a3),(0x1400bd5d0,0x1400bd5e0),
        (0x1400b4aa0,0x1400b4ad0),(0x1400bbad0,0x1400bbcb3)]

def hook(u,address,size,_):
 if address==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(reg)for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
 if address==0x1400bee30:u.reg_write(UC_X86_REG_RIP,0x1400b4aa0)
 elif address==0x1400bf3d0:u.reg_write(UC_X86_REG_RIP,0x1400bbad0)
 elif address==0x1400be870:calls.append(dict(call='bind',target=x,buffer=y));m.finish()
 elif address==buffer_data:calls.append(dict(call='buffer_data',target=x,bytes=y,pointer=z,usage=w));m.finish()
 elif address==buffer_subdata:calls.append(dict(call='buffer_subdata',target=x,offset=y,bytes=z,pointer=w));m.finish()
 elif address==gen_buffer:calls.append(dict(call='gen_buffers',count=x));m.wi(y,7);m.finish()
 elif not any(low<=address<high for low,high in ranges):raise RuntimeError(f'Unexpected native stream dependency {address:x}')
u.hook_add(UC_HOOK_CODE,hook)

def invoke(address,*arguments):
 u.mem_write(m.stack,bytes(0x20000));rsp=m.stack+0x1fe08;m.wq(rsp,m.stop)
 u.reg_write(UC_X86_REG_RSP,rsp)
 for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],arguments):u.reg_write(reg,value)
 u.emu_start(address,m.stop,count=10000)
 assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return u.reg_read(UC_X86_REG_RAX)

rows=[]
for count,capacity,uploaded,orphan in itertools.product([0,6,60,768],[768,1536],[0,1],[0,1]):
 u.mem_write(m.heap,bytes(0x100000));calls=[]
 m.wq(0x14128ead8,pools);m.wi(0x14128eae0,1);m.wi(0x14128e9cc,orphan)
 m.wq(0x141442448,buffer_data);m.wq(0x141442450,buffer_subdata);m.wq(0x141442470,gen_buffer)
 m.wq(pools,data);m.wi(pools+8,capacity*24);m.wi(pools+0xc,7);m.wi(pools+0x14,2)
 u.mem_write(pools+0x18,bytes([uploaded,1]))
 m.wi(stream+0x20,0);m.wi(stream+0x28,24)
 pointer=invoke(0x1400bd890,stream);assert pointer==data
 invoke(0x1400bd5d0,stream,count,0)
 transfers=[row for row in calls if row['call']in('buffer_data','buffer_subdata')]
 if count==0:assert transfers==[]
 elif not uploaded:assert transfers==[dict(call='buffer_data',target=0x8892,bytes=capacity*24,pointer=data,usage=0x88e8)]
 else:
  expected=[]
  if orphan:expected.append(dict(call='buffer_data',target=0x8892,bytes=capacity*24,pointer=0,usage=0x88e8))
  expected.append(dict(call='buffer_subdata',target=0x8892,offset=0,bytes=count*24,pointer=data))
  assert transfers==expected
 rows.append(dict(input=dict(vertices=count,capacity=capacity,uploaded=bool(uploaded),orphan=bool(orphan)),calls=calls,returnedPointer=pointer,lockFlags=int(u.mem_read(pools+0x11,1)[0])))

out=m.root/'backups/animations/native-particle-stream-v1.json'
assert not out.exists(),'Preserve original observations'
out.write_text(json.dumps(dict(binarySha256=m.digest,scope=__doc__,rows=rows),indent=2))
print(json.dumps(dict(success=True,output=str(out),cases=len(rows),stride=24)))
