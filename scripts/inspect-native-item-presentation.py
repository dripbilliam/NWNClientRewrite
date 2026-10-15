"""Read-only original item use cache and visual selectors, build89.

Full UpdateUsedActiveProperties/GetUsedActivePropertyUsesLeft/UpdateVisualEffect
bodies execute. Synthetic physical pools; substitute 2DA/base/resource/string,
allocator and message/client lookup plus security cookie helpers. Unpossessed
items do not send packets; no actual renderer/equipment effects are validated.
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
u.mem_map(heap,0x20000);u.mem_map(stack,0x10000);u.mem_map(stop,0x1000)
item,app,info,pool,damage,definition,melee,subtype=[heap+n*0x1000 for n in range(8)]
def q(a):return struct.unpack('<Q',u.mem_read(a,8))[0]
def i(a):return struct.unpack('<I',u.mem_read(a,4))[0]
def wi(a,v):u.mem_write(a,struct.pack('<I',v&0xffffffff))
def wh(a,v):u.mem_write(a,struct.pack('<H',v&65535))
def wb(a,v):u.mem_write(a,bytes([v&255]))
def wq(a,v):u.mem_write(a,struct.pack('<Q',v))
def finish(v=0):
    rsp=u.reg_read(UC_X86_REG_RSP);u.reg_write(UC_X86_REG_RIP,q(rsp));u.reg_write(UC_X86_REG_RSP,rsp+8);u.reg_write(UC_X86_REG_RAX,v&0xffffffffffffffff)
case={};cursor=heap+0x10000;client_queries=0
def alloc(n):
    global cursor
    p=cursor;cursor+=(max(n,1)+15)&~15;assert cursor<heap+0x20000;u.mem_write(p,bytes(max(n,1)));return p
def hook(u,a,n,_):
    global client_queries
    if a==stop:u.emu_stop();return
    x,y,z,w=[u.reg_read(r) for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
    if a==0x14029ca00:finish(info)
    elif a==0x140c10368:finish(alloc(x))
    elif a in [0x140c10370,0x140c10410]:finish()
    elif a==0x14055b810:finish(app)
    elif a==0x14055b390:client_queries+=1;finish()
    elif a==0x1401a7010:
        wi(w,case['visualValue'] if x==subtype else case['vfx']);finish(case['mode']!='bad-cell' if x==subtype else 1)
    elif a==0x1401a68f0:
        p=alloc(6);u.mem_write(p,b'child\0');wq(w,p);wi(w+8,5);wi(w+12,6);finish(case['mode']!='legacy')
    elif a==0x14003d8c0:
        p=alloc(z+1);u.mem_write(p,bytes(u.mem_read(y,z))+b'\0');wq(x,p);wi(x+8,z);wi(x+12,z+1);finish(x)
    elif a==0x1402b31e0:finish(0 if case['mode']=='missing-table' else subtype)
    elif a==0x1401a6a80:finish(-1 if case['mode']=='no-column' else 0)
    elif not(0x140469170<=a<0x1404692a9 or 0x14046cf20<=a<0x14046d109 or 0x14046d140<=a<0x14046d72e):
        raise RuntimeError(f'Unmapped item presentation dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def reset(props,active):
    global cursor,client_queries
    cursor=heap+0x10000;client_queries=0;u.mem_write(heap,bytes(0x20000))
    wq(0x1412df8f8,app);wq(0x1412df970,app);wq(app+0x20,app);wq(app+0x130,app+0x200);wq(app+0x4f0,damage);wq(app+0x368,definition);wq(app+0x360,melee)
    wb(info+0x16,2);wq(item+(0x368 if active else 0x378),pool);wi(item+(0x370 if active else 0x380),len(props))
    for index,p in enumerate(props):
        r=pool+index*48;wh(r,p['type']);wh(r+2,p.get('subtype',0));wh(r+6,p['costValue']);wb(r+9,p.get('param1Value',0));wi(r+12,p['remaining']);wb(r+16,p['usesPerDay'])
def run(address,args):
    rsp=stack+0xff08;u.mem_write(rsp-0x200,bytes(0x280));wq(rsp,stop)
    for reg,val in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],[item,*args]):u.reg_write(reg,val)
    u.reg_write(UC_X86_REG_RSP,rsp);u.emu_start(address,stop,count=20000);assert u.reg_read(UC_X86_REG_RIP)==stop
    return u.reg_read(UC_X86_REG_RAX)&0xffffffff
left=[]
for cost,remaining,uses,charges,stack_size in itertools.product(range(15),[0,1,-1],[0,1,255],[-1,0,1,50,250,65542],[1,256,-1]):
    case={'cost':cost,'remaining':remaining,'uses':uses,'charges':charges,'stack':stack_size}
    props=[{'type':15,'costValue':cost,'remaining':remaining,'usesPerDay':uses}];reset(props,True);wi(item+0x388,charges);wi(item+0x454,stack_size)
    raw=run(0x140469170,[0]);left.append({'case':case,'value':raw&65535,'rawReturn':raw})
caches=[]
for count,charges,remaining,force in itertools.product([0,1,8,9,33],[-1,0,50],[0,1],[0,1,2]):
    props=[{'type':15 if index%3 else 80,'costValue':index%13+1,'remaining':remaining,'usesPerDay':index%4} for index in range(count)]
    case={'count':count,'charges':charges,'remaining':remaining,'force':force};reset(props,True);wi(item+0x388,charges);wi(item+0x454,256)
    wb(item+0x350,85);u.mem_write(item+0x351,bytes(range(8)));run(0x14046cf20,[force])
    caches.append({'case':case,'props':props,'result':{'mask':u.mem_read(item+0x350,1)[0],'uses':list(u.mem_read(item+0x351,8)),'clientQueries':client_queries}})
visuals=[]
for prop_type,sub,mode,vfx,visual_value in itertools.product([7,9,16,17,19,36,48,57,59,67,83],[0,4,5,6,7,9,10,13,17,24,25,255],['legacy','missing-table','no-column','bad-cell','cell'],[0,1],[0,255,6]):
    case={'type':prop_type,'subtype':sub,'mode':mode,'vfx':vfx,'visualValue':visual_value}
    props=[{'type':prop_type,'subtype':sub,'param1Value':sub,'costValue':1,'remaining':1,'usesPerDay':255},{'type':36,'costValue':1,'remaining':1,'usesPerDay':255}]
    reset(props,False);run(0x14046d140,[]);visuals.append({'case':case,'result':u.mem_read(item+0x462,1)[0]})
output=root/'backups/animations/native-item-presentation-observations.json'
output.write_text(json.dumps({'binarySha256':digest,'limits':__doc__,'left':left,'caches':caches,'visuals':visuals},indent=2))
print(json.dumps({'output':str(output),'left':len(left),'caches':len(caches),'visuals':len(visuals)}))
