"""Read-only complete CompareItem oracle, build89.

Synthetic item fields/pools/CExoString buffers; only the base-row query is
substituted. Validates field/appearance/tag/property comparisons, not merge
mutation, ownership, equipment or inventory events.
"""
from pathlib import Path
import sys,struct,hashlib,json,itertools
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
a,b,info,app,active_a,active_b,passive_a,passive_b=[heap+n*0x1000 for n in range(8)]
def q(p):return struct.unpack('<Q',u.mem_read(p,8))[0]
def wi(p,v):u.mem_write(p,struct.pack('<I',v&0xffffffff))
def wh(p,v):u.mem_write(p,struct.pack('<H',v&65535))
def wb(p,v):u.mem_write(p,bytes([v&255]))
def wq(p,v):u.mem_write(p,struct.pack('<Q',v))
def finish(v=0):
    rsp=u.reg_read(UC_X86_REG_RSP);u.reg_write(UC_X86_REG_RIP,q(rsp));u.reg_write(UC_X86_REG_RSP,rsp+8);u.reg_write(UC_X86_REG_RAX,v)
case={}
def hook(u,address,n,_):
    if address==stop:u.emu_stop();return
    if address==0x14029ca00:finish(info if case['validBase'] else 0)
    elif not 0x140466220<=address<0x1404664fc:raise RuntimeError(f'Unmapped item comparison dependency {address:x}')
u.hook_add(UC_HOOK_CODE,hook)
mutations={'same':None,'identified':(b+0x360,4),'activeCount':(b+0x370,4),'passiveCount':(b+0x380,4),'plot':(b+0x144,4),
    'charges':(b+0x388,4),'baseItem':(b+0x40,4),'stolen':(b+0x458,4),'tagLength':(b+0x70,4),
    'tagContent':(heap+0x9100,1),'stackSize':(b+0x454,4),'droppable':(b+0x448,4),'location':(b+0x3d8,1),'price':(b+0x38c,4),
    'passiveValue':(passive_b+6,2)}
for name,offset,size in [('type',0,2),('subtype',2,2),('costTable',4,1),('costValue',6,2),('param1',8,1),('param1Value',9,1),('usesPerDay',16,1),('remaining',12,4),('chance',10,1),('durationType',17,1),('propertyId',40,8)]:mutations['active.'+name]=(active_b+offset,size)
for index in range(3):mutations[f'modelParts.{index}']=(b+0x39c+index*2,2)
for index in range(19):mutations[f'armorParts.{index}']=(b+0x3a2+index*2,2)
for index in range(6):mutations[f'colors.{index}']=(b+8+index,1)
observations=[]
for model,maximum,valid,mutation in itertools.product(range(5),[1,10],[0,1],mutations):
    case={'modelType':model,'stacking':maximum,'validBase':valid,'mutation':mutation};u.mem_write(heap,bytes(0x10000))
    wq(0x1412df8f8,app);wq(app+0x20,app);wb(info+0x16,model);wh(info+0x24,maximum)
    for item,active,passive,tag in [(a,active_a,passive_a,heap+0x9000),(b,active_b,passive_b,heap+0x9100)]:
        wi(item+0x360,1);wi(item+0x370,1);wi(item+0x380,1);wi(item+0x388,50);wi(item+0x40,49);wi(item+0x454,1)
        wq(item+0x368,active);wq(item+0x378,passive);wq(item+0x68,tag);wi(item+0x70,6);u.mem_write(tag,b'Potion\0')
        for index in range(3):wh(item+0x39c+index*2,index+1)
        for index in range(19):wh(item+0x3a2+index*2,index+1)
        for index in range(6):wb(item+8+index,index+1)
        wh(active,15);wh(active+2,1);wb(active+4,2);wh(active+6,3);wb(active+8,4);wb(active+9,5);wb(active+16,255)
    target=mutations[mutation]
    if target:
        address,size=target;value=int.from_bytes(u.mem_read(address,size),'little')^1;u.mem_write(address,value.to_bytes(size,'little'))
    rsp=stack+0xff08;wq(rsp,stop)
    for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_RSP],[a,b,rsp]):u.reg_write(reg,value)
    u.emu_start(0x140466220,stop,count=5000);assert u.reg_read(UC_X86_REG_RIP)==stop
    observations.append({'case':case,'result':u.reg_read(UC_X86_REG_RAX)&0xffffffff})
output=root/'backups/animations/native-item-stack-compare-observations.json'
output.write_text(json.dumps({'binarySha256':digest,'limits':__doc__,'observations':observations},indent=2))
print(json.dumps({'output':str(output),'observations':len(observations)}))
