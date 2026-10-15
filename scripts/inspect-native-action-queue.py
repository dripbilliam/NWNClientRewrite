"""Read-only original action queue display and exhaustive ushort AQ mapping.
Queue summary/group selection, combat special lists and item properties are
captured helper boundaries; physical record writes execute unchanged. Map
instructions execute for every ushort in both normal/special modes.
"""
import importlib.util,itertools,json,re,hashlib,struct
from pathlib import Path
spec=importlib.util.spec_from_file_location('coordinator',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle);q,si,wi,wq,finish=[getattr(m,n) for n in ['q','si','wi','wq','finish']]
actor,nodes,actions,item,prop,table=[m.heap+n*0x1000 for n in range(6)];ranges=[]
for file in ['live-native-action-queue-display-full-asm.txt','live-native-aq-map-group-asm.txt']:
    for line in (m.root/'backups/animations'/file).read_text().splitlines():
        if line.startswith('FUNCTION REQUESTED'):ranges.extend((int(a,16),int(b,16)) for a,b in re.findall(r'([0-9a-f]+):([0-9a-f]+)',line))
acceptable={1,7,9,12,15,20,21,24,25,26,27,28,29,30,38,39,40,41,42,43,45,46,50,54,55,56,57,59}
def position(index):
    old=-1;group=-1
    for n,row in enumerate(c['actions']):
        if row['group']!=old:group+=1;old=row['group']
        if group==index:return n
    return -1
def summary(group):
    found=False;last=-1
    for n,row in enumerate(c['actions']):
        if row['group']==group:
            found=True
            if row['action'] in acceptable:last=n
        elif found:break
    return last
def hook(u,a,n,_):
    if a==m.stop:u.emu_stop();return
    x,y,z=[u.reg_read(reg) for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8]]
    if a==0x140495e90:
        index=position(y if y<0x80000000 else y-0x100000000);calls.append(['groupPosition',y]);finish(nodes+index*32 if index>=0 else 0)
    elif a==0x1401690b0:finish(actions+((y-nodes)//32)*0x100)
    elif a==0x140494dd0:
        index=summary(y&65535);calls.append(['groupAction',y&65535]);wq(z,actions+index*0x100 if index>=0 else 0);finish(c['actions'][index]['action'] if index>=0 else 65535)
    elif a in [0x140376300,0x140376570,0x140376440]:
        if a==0x140376300:calls.append(['specialCount']);finish(len(c['specials']))
        elif a==0x140376570:calls.append(['specialId',y]);finish(c['specialIds'][y]&65535)
        else:calls.append(['specialType',y]);finish(c['specials'][y]&65535)
    elif a==0x14055b6c0:calls.append(['item',y]);finish(item if c['item'] else 0)
    elif a==0x1404686d0:calls.append(['property',y]);finish(prop if c['property'] else 0)
    elif a==0x1401a7010:
        calls.append(['spellIndex',y]);wi(u.reg_read(UC_X86_REG_R9),c['spellIndex']);finish(1)
    elif a==0x140c10368:finish(m.heap+0x9000)
    elif a==0x140c10370:finish()
    elif not any(lo<=a<hi for lo,hi in ranges):raise RuntimeError(f'Unmapped action queue dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def invoke(address,args):
    rsp=m.stack+0x1fe08;u.mem_write(rsp-0x100,bytes(0x200));wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
    for reg,v in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8],args):u.reg_write(reg,v)
    u.emu_start(address,m.stop,count=100000);assert u.reg_read(UC_X86_REG_RIP)==m.stop;return u.reg_read(UC_X86_REG_RAX)&65535
def run(case):
    global c,calls
    c=case;calls=[];u.mem_write(m.heap,bytes(0x100000));u.mem_write(actor+0x59c,bytes([0xa5])*280);wq(0x1412df970,table);wq(0x1412df8f8,table);wq(table+0x130,table)
    # g_pRules is the pointer loaded at1403a6793 (1412df8f8).
    wq(0x1412df8f8,table);wq(table+0x130,table);wq(table+0x148,table)
    for n,row in enumerate(c['actions']):
        pointer=actions+n*0x100;u.mem_write(pointer+0x98,struct.pack('<H',row['group']&65535))
        for k,v in enumerate(row['words']):wi(pointer+0x38+k*8,v)
    u.mem_write(prop+2,struct.pack('<H',c['subtype']&65535))
    try:invoke(0x1403a6270,[actor,0,0])
    except Exception:print(json.dumps(dict(case=c,rip=hex(u.reg_read(UC_X86_REG_RIP)),calls=calls)));raise
    return dict(case=c,calls=calls,raw=bytes(u.mem_read(actor+0x59c,280)).hex())
def action(code,group=3,flag=0):return dict(action=code,group=group,words=[77,0x3f800000,0x40000000,0x40400000,88,flag,0x40800000,0x40a00000,0x40c00000,99,100,101])
default=dict(actions=[],specials=[],specialIds=[],item=1,property=1,subtype=4,spellIndex=57)
rows=[run(default|dict(actions=[action(code)],specials=specials,specialIds=list(range(10,10+len(specials))))) for code,specials in itertools.product(range(65),[[],[9,6,0,65002,16],[9,17,23,30,31,39,204,296,301,65000]])]
rows += [run(default|dict(actions=records,item=item,property=prop,spellIndex=spell)) for records,item,prop,spell in itertools.product([[action(1,3,flag=64),action(12,4),action(7,5)], [action(17,1),action(19,1),action(1,2),action(12,2),action(15,3),action(7,1)], [action(46),action(9,4)], [action(7,n) for n in range(12)]],[0,1],[0,1],[-1,57])]
maps=[]
for special in [0,1]:
    values=[];sparse={}
    for code in range(65536):
        value=invoke(0x1404ab820,[actor,code,special]);values.append(value)
        if value!=65535:sparse[str(code)]=value
    maps.append(dict(special=special,sha256=hashlib.sha256(struct.pack('<65536H',*values)).hexdigest(),mapping=sparse))
out=m.root/'backups/animations/native-action-queue-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows,maps=maps),indent=2));print(json.dumps(dict(output=str(out),rows=len(rows),mappedInputs=131072)))
