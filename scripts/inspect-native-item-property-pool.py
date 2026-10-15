"""Read-only complete native OnApplyItemProperty oracle, build89.

Synthetic unpossessed items/effects; substitute base/table queries, integer/
string storage, pool append/copy and post-change dirty/cost callbacks. Actual
classifier and RestoreUsedActiveProperty execute. Does not validate legacy
GFF loading, equipment effects, dynamic item cost or possession event owners.
"""
from pathlib import Path
import sys,hashlib,struct,json,itertools
root=Path(__file__).resolve().parents[1];sys.path.insert(0,str(root/'backups/research-python'))
import pefile
from unicorn import Uc,UC_ARCH_X86,UC_MODE_64,UC_HOOK_CODE
from unicorn.x86_const import *
data=(root.parent/'FullDecomp/NwnRootInstall/bin/win32/nwmain.exe').read_bytes();digest=hashlib.sha256(data).hexdigest()
assert digest=='3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a'
pe=pefile.PE(data=data);base=pe.OPTIONAL_HEADER.ImageBase
u=Uc(UC_ARCH_X86,UC_MODE_64);u.mem_map(base,(pe.OPTIONAL_HEADER.SizeOfImage+4095)&~4095);u.mem_write(base,pe.get_memory_mapped_image())
heap,stack,stop=0x200000000,0x300000000,0x400000000
u.mem_map(heap,0x10000);u.mem_map(stack,0x10000);u.mem_map(stop,0x1000)
item,effect,info,rules,vt,copy=[heap+n*0x1000 for n in range(6)]
def q(a):return struct.unpack('<Q',u.mem_read(a,8))[0]
def wi(a,v):u.mem_write(a,struct.pack('<I',v&0xffffffff))
def wq(a,v):u.mem_write(a,struct.pack('<Q',v))
def finish(v=0):
    rsp=u.reg_read(UC_X86_REG_RSP);u.reg_write(UC_X86_REG_RIP,q(rsp));u.reg_write(UC_X86_REG_RSP,rsp+8);u.reg_write(UC_X86_REG_RAX,v)
case={};values=[];pool=None;column_seen=None
def hook(u,a,n,_):
    global pool,column_seen
    if a==stop:u.emu_stop();return
    x,y,z,w=[u.reg_read(r) for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
    if a==stop+0x10:finish(item)
    elif a==0x14029ca00:finish(info if case['validBase'] else 0)
    elif a==0x140423fc0:finish(values[y])
    elif a==0x140425210:values[y]=z&0xffffffff;finish()
    elif a==0x1401a7120:column_seen=z;wi(w,case['allowed']);finish(1)
    elif a==0x140424690:finish(effect+0x100)
    elif a==0x14003d8c0:wq(x,heap+0x8000);wi(x+8,z);wi(x+12,z+1);finish(x)
    elif a==0x140425630:finish(y)
    elif a in [0x140464190,0x140464b50]:pool=int(a==0x140464190);u.mem_write(copy,bytes(u.mem_read(y,48)));wi(item+0x370,1);finish()
    elif a==0x1404686d0:finish(copy)
    elif a in [0x140c10370,0x14046cf20,0x140466660,0x14046d140]:finish()
    elif not(0x14042e5c0<=a<0x14042e971 or 0x1404640e0<=a<0x140464108 or 0x14046b580<=a<0x14046b5eb):
        raise RuntimeError(f'Unmapped property dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
observations=[]
cases=[]
for property_type,cost,uses,duration in itertools.product([15,61,62,70,80,0x1000f], [0,8,12,13], [255,4], [1,2]):
    cases.append({'type':property_type,'cost':cost,'uses':uses,'duration':duration,'base':8,'validBase':1,'tablePresent':1,'allowed':1,'column':35})
for base,valid,present,allowed in itertools.product([6,7,8,11,61,49],[0,1],[0,1],[0,1]):
    cases.append({'type':61,'cost':8,'uses':255,'duration':2,'base':base,'validBase':valid,'tablePresent':present,'allowed':allowed,'column':255})
for case in cases:
    values=[case['type'],9,0x102,case['cost'],0x103,0x104,case['uses'],0x105,7];pool=None;column_seen=None
    u.mem_write(heap,bytes(0x10000));wq(item,vt);wq(vt+0x70,stop+0x10);wi(item+0x40,case['base']);wi(item+0x3c8,0x7f000000)
    u.mem_write(info+0x32,bytes([case['column']]));u.mem_write(effect+0xa,struct.pack('<H',case['duration']))
    wq(effect+0x100,heap+0x8000);wi(effect+0x108,3);u.mem_write(heap+0x8000,b'tag\0')
    wq(0x1412df8f8,rules);wq(rules+0x20,rules);wq(rules+0x130,rules+0x100);wq(rules+0x270,rules+0x300 if case['tablePresent'] else 0)
    wq(0x14141ef30,41)
    rsp=stack+0xff08;u.mem_write(rsp-0x200,bytes(0x280));wq(rsp,stop)
    for reg,val in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_RSP],[rules,item,effect,rsp]):u.reg_write(reg,val)
    u.emu_start(0x14042e5c0,stop,count=5000);assert u.reg_read(UC_X86_REG_RIP)==stop
    b=bytes(u.mem_read(copy,48));result={'consumed':u.reg_read(UC_X86_REG_RAX)&0xffffffff,'pool':pool,'column':column_seen,'effectPropertyId':q(effect+0xf0),'nextPropertyId':q(0x14141ef30),'subtype':values[1]}
    if pool is not None:
        result['property']={'type':struct.unpack_from('<H',b,0)[0],'subtype':struct.unpack_from('<H',b,2)[0],'costTable':b[4],'costValue':struct.unpack_from('<H',b,6)[0],
          'param1':b[8],'param1Value':b[9],'chance':b[10],'remaining':struct.unpack_from('<i',b,12)[0],'usesPerDay':b[16],'durationType':b[17],'customTag':'tag','propertyId':f'{struct.unpack_from("<Q",b,40)[0]:016x}'}
    observations.append({'case':case,'result':result})
output=root/'backups/animations/native-item-property-pool-observations.json'
output.write_text(json.dumps({'binarySha256':digest,'limits':__doc__,'observations':observations},indent=2))
print(json.dumps({'output':str(output),'observations':len(observations)}))
