"""Read-only complete SetPossessor oracle, build89.

Synthetic canonical creatures, bags and placeables. Registry/module/list and
script-event/feedback/quickbar helpers substituted and captured. Executes the
full original owner; no event scripts, actual quickbar mutation or inventory
acquisition/equipping is validated here.
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
u.mem_map(heap,0x40000);u.mem_map(stack,0x10000);u.mem_map(stop,0x1000)
item,app,vt,repo,linked=[heap+n*0x1000 for n in range(5)]
definitions={21:{'type':5,'pc':0},22:{'type':5,'pc':1},31:{'type':6,'owner':21},32:{'type':6,'owner':22},41:{'type':9,'veto':0},42:{'type':9,'veto':1}}
addresses={id:heap+(n+5)*0x1000 for n,id in enumerate(definitions)}
def q(a):return struct.unpack('<Q',u.mem_read(a,8))[0]
def i(a):return struct.unpack('<I',u.mem_read(a,4))[0]
def h(a):return struct.unpack('<H',u.mem_read(a,2))[0]
def wi(a,v):u.mem_write(a,struct.pack('<I',v&0xffffffff))
def wq(a,v):u.mem_write(a,struct.pack('<Q',v))
def finish(v=0):
    rsp=u.reg_read(UC_X86_REG_RSP);u.reg_write(UC_X86_REG_RIP,q(rsp));u.reg_write(UC_X86_REG_RSP,rsp+8);u.reg_write(UC_X86_REG_RAX,v)
cursor=heap+0x20000;records={};events=[];feedback=[];quickbar=[]
def hook(u,a,n,_):
    global cursor
    if a==stop:u.emu_stop();return
    x,y,z,w=[u.reg_read(r) for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
    if a==0x14055b6e0:finish(app+0x400)
    elif a in [0x14055b850,0x14055b960]:finish(app)
    elif a==0x140296470:wq(z,addresses.get(y,0));finish(0 if y in addresses else 1)
    elif a in [0x14055b3d0,0x14055b890]:finish(addresses.get(y,0) if definitions.get(y,{}).get('type')=={0x14055b3d0:5,0x14055b890:9}[a] else 0)
    elif a in [stop+0x10,stop+0x20]:finish(x)
    elif a==0x140c10324:
        result=cursor;cursor+=(x+15)&~15;assert cursor<heap+0x40000;u.mem_write(result,bytes(x));records[result]={'objects':[],'integers':[]};finish(result)
    elif a==0x1404c6490:finish(x)
    elif a in [0x1404c7320,0x1402da770,0x1404c72e0,0x1402da730]:
        key='objects' if a in [0x1404c7320,0x1402da770] else 'integers';values=records[x][key]
        while len(values)<=y:values.append(0x7f000000 if key=='objects' else 0)
        values[y]=z&0xffffffff if key=='objects' else (z&0x7fffffff)-(z&0x80000000);finish()
    elif a==0x1405570b0:
        rsp=u.reg_read(UC_X86_REG_RSP);record=q(rsp+0x38);assert i(rsp+0x30)==10
        events.append({'source':w&0xffffffff,'target':i(rsp+0x28),'type':h(record),**records[record]});finish()
    elif a==0x1403a2480:feedback.append({'owner':i(x+8),'code':y,**records[z]});finish()
    elif a==0x14039bf80:quickbar.append([i(x+8),y]);finish()
    elif a==0x1401690b0:finish(y+8)
    elif a==0x140169110:wq(y,q(q(y)));finish()
    elif not 0x14046c520<=a<0x14046cddc:raise RuntimeError(f'Unmapped possession dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
observations=[]
owners=[0x7f000000,21,22,31,32,41,42,99]
for old,new,scripts,messages,contents,qb in itertools.product(owners,owners,[0,1],[0,1],[0,1],[0,1]):
    case={'old':old,'new':new,'scripts':scripts,'messages':messages,'contents':contents,'quickbar':qb,'quantity':-5}
    cursor=heap+0x20000;records={};events=[];feedback=[];quickbar=[];u.mem_write(heap,bytes(0x40000))
    wq(0x1412df970,app);wq(app+8,app);wi(app+0x430,0)
    wq(vt+0x60,stop+0x10);wq(vt+0x70,stop+0x20)
    for id,d in definitions.items():
        obj=addresses[id];wq(obj,vt);wi(obj+8,id);u.mem_write(obj+0xc,bytes([d['type']]))
        wi(obj+0x3c8,d.get('owner',0x7f000000));wi(obj+0x504,d.get('veto',0))
        wq(obj+0xad0,obj+0xe00);wi(obj+0xeb0,d.get('pc',0));wq(obj+0x4e0,qb)
    wi(item+0x50,100);wi(item+0x3c8,old);wi(item+0x360,7)
    if contents:
        wq(item+0x3d0,repo);wq(repo+0x10,linked);wq(linked,heap+0xf000);wi(linked+0x10,2)
        wq(heap+0xf000,heap+0xf020);wi(heap+0xf008,111);wi(heap+0xf028,112)
    rsp=stack+0xff08;u.mem_write(rsp-0x200,bytes(0x280));wq(rsp,stop);wi(rsp+0x28,-5)
    for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9,UC_X86_REG_RSP],[item,new,scripts,messages,rsp]):u.reg_write(reg,value)
    u.emu_start(0x14046c520,stop,count=10000);assert u.reg_read(UC_X86_REG_RIP)==stop
    observations.append({'case':case,'result':{'possessorId':i(item+0x3c8),'droppable':i(item+0x448),'pickpocketable':i(item+0x44c),
        'events':events,'feedback':feedback,'quickbar':quickbar}})
output=root/'backups/animations/native-item-possession-observations.json'
output.write_text(json.dumps({'binarySha256':digest,'limits':__doc__,'definitions':definitions,'observations':observations},indent=2))
print(json.dumps({'output':str(output),'observations':len(observations)}))
