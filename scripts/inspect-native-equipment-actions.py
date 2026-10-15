"""Read-only original AddEquipItemActions, AddEquipAction and AIActionEquipItem.
Round rescaling executes original instructions; linked-list allocation and
messages, clients, activity/death/RunEquip/encumbrance are captured boundaries.
No transitive RunEquip, property/effect or multiplayer packet parity claim.
"""
from pathlib import Path
import sys,struct,hashlib,json,itertools,re
root=Path(__file__).resolve().parents[1];sys.path.insert(0,str(root/'backups/research-python'))
import pefile
from unicorn import Uc,UC_ARCH_X86,UC_MODE_64,UC_HOOK_CODE
from unicorn.x86_const import *
data=(root.parent/'FullDecomp/NwnRootInstall/bin/win32/nwmain.exe').read_bytes();digest=hashlib.sha256(data).hexdigest()
assert digest=='3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a'
pe=pefile.PE(data=data);base=pe.OPTIONAL_HEADER.ImageBase
u=Uc(UC_ARCH_X86,UC_MODE_64);u.mem_map(base,(pe.OPTIONAL_HEADER.SizeOfImage+4095)&~4095);u.mem_write(base,pe.get_memory_mapped_image())
heap,stack,stop=0x200000000,0x300000000,0x400000000
u.mem_map(heap,0x50000);u.mem_map(stack,0x10000);u.mem_map(stop,0x1000)
o,r,item,node,app,client,msg,listptr,linked=[heap+n*0x4000 for n in range(9)]
ranges=[]
for file in ['live-native-queued-equip-full-asm.txt','live-native-add-equip-actions-asm.txt','live-native-clear-action-full-asm.txt']:
    for line in (root/'backups/animations'/file).read_text().splitlines():
        if line.startswith('FUNCTION REQUESTED'):
            ranges.extend((int(a,16),int(b,16)) for a,b in re.findall(r'([0-9a-f]+):([0-9a-f]+)',line))
def i(a):return int.from_bytes(u.mem_read(a,4),'little')
def si(a):return struct.unpack('<i',u.mem_read(a,4))[0]
def q(a):return int.from_bytes(u.mem_read(a,8),'little')
def wi(a,v):u.mem_write(a,struct.pack('<I',v&0xffffffff))
def wq(a,v):u.mem_write(a,struct.pack('<Q',v))
def finish(v=0):
    rsp=u.reg_read(UC_X86_REG_RSP);u.reg_write(UC_X86_REG_RIP,q(rsp));u.reg_write(UC_X86_REG_RSP,rsp+8);u.reg_write(UC_X86_REG_RAX,v&0xffffffffffffffff)
def link_sync():
    wq(linked,nodes[0] if nodes else 0)
    for n,ptr in enumerate(nodes):wq(ptr,nodes[n+1] if n+1<len(nodes) else 0)
def hook(u,a,n,_):
    global allocated
    if a==stop:u.emu_stop();return
    x,y,z,w=[u.reg_read(reg) for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
    if a in [0x14055b390,0x14055f720]:finish(client if c['client'] else 0)
    elif a==0x14055b810:finish(msg if c['message'] else 0)
    elif a==0x14055b6c0:finish(item if c['itemExists'] else 0)
    elif a==0x1404da660:calls.append(['cancel',z&0xffffffff,w&0xffffffff,i(rsp+0x28)]);finish()
    elif a==0x1403a2480:calls.append(['feedback',y&0xffffffff]);finish()
    elif a in [0x14048cb80,0x14048d3f0,0x14048ced0]:
        values=[[w&0xffffffff,i(q(rsp+0x28))],[i(rsp+0x30),i(q(rsp+0x38))],[i(rsp+0x40),i(q(rsp+0x48))]]
        calls.append(['queue',{0x14048cb80:'tail',0x14048d3f0:'front',0x14048ced0:'afterFront'}[a],y&0xffffffff,z&65535,values]);finish()
    elif a==0x140374930 and c['mode']=='request':calls.append(['round',y&0xffffffff,z&0xffffffff]);finish()
    elif a==0x1401690b0:finish(q(y+8))
    elif a==0x140169110:wq(y,q(q(y)));finish()
    elif a==0x140c10324:allocated=heap+0x48000;finish(allocated)
    elif a==0x1403d54d0:finish(c['possessed'])
    elif a==0x14055b8c0:finish(1)
    elif a==0x14037cc30:calls.append(['activity',y&0xffffffff]);finish()
    elif a==0x14055b860:calls.append(['pause',y&255]);finish(c['pause'])
    elif a==0x14055bb60:calls.append(['exclusion',y&0xffffffff]);finish(c['exclusion'])
    elif a==0x1404953b0:calls.append(['dead']);finish(c['dead'])
    elif a==0x140495620:calls.append(['dying']);finish(c['dying'])
    elif a==0x14039f960 and c['mode']=='ai':calls.append(['run',y&0xffffffff,z&0xffffffff,w&0xffffffff]);finish(c['runResult'])
    elif a==0x1403db1e0:calls.append(['encumbrance',y&0xffffffff]);finish()
    elif a==stop+0x100:finish(c['lock'])
    elif a==stop+0x108:calls.append(['lock',y&0xffffffff]);finish()
    elif a in insert_helpers.values():
        ptr=heap+0x47000;wq(ptr+8,y)
        if a==insert_helpers['before']:nodes.insert(nodes.index(z),ptr);calls.append(['insert','before'])
        else:nodes.append(ptr);calls.append(['insert','tail'])
        link_sync();finish(ptr)
    elif not any(lo<=a<hi for lo,hi in ranges):raise RuntimeError(f'Unmapped equipment action dependency {a:x}')
# Addresses established by full AddEquipAction disassembly.
asm=(root/'backups/animations/live-native-queued-equip-full-asm.txt').read_text().split('FUNCTION REQUESTED 1403bbb60')[0]
insert_calls=[m.group(1) for line in asm.splitlines() if re.match(r'^[0-9a-f]+:',line) and int(line.split(':')[0],16)>=0x140374ac2 and (m:=re.search(r'call 0x([0-9a-f]+)',line))]
insert_helpers={'before':int(insert_calls[0],16),'tail':int(insert_calls[1],16)}
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
    global c,calls,nodes,allocated
    c=case;calls=[];nodes=[];allocated=0;u.mem_write(heap,bytes(0x50000));wq(0x1412df970,app);wq(app+8,app)
    wi(o+8,77);wi(o+0xec,c['gate']);wi(o+0x700,c['combat']);wi(o+0x89c,c['pc']);wq(o+0x880,r);wi(item+0x50,99);wi(client+0x48,1)
    for off,value in [(0x2f04,c['started']),(0x2f08,c['paused']),(0x2f0c,240),(0x2f10,c['length']),(0x2f14,0)]:wi(r+off,value)
    wq(r+0x2f70,listptr);wq(listptr,linked);wq(r+0x2f78,o)
    for n,action in enumerate(c['actions']):
        ptr=heap+0x40000+n*0x100;value=ptr+0x40;nodes.append(ptr);wq(ptr+8,value)
        for off,key in [(0,'time'),(8,'duration'),(0xc,'count'),(0x10,'nativeActionType'),(0x14,'targetId'),(0x18,'followTarget'),(0x1c,'equipmentSlot')]:wi(value+off,action[key])
    link_sync();rsp=stack+0xff08;u.mem_write(rsp-0x300,bytes(0x380));wq(rsp,stop);u.reg_write(UC_X86_REG_RSP,rsp)
    if c['mode']=='round':entry=0x140374930;args=[r,99,c['slot'],0]
    elif c['mode']=='request':entry=0x14037eb50;args=[o,item,c['slot'],c['front']];wi(rsp+0x28,c['force']);wi(rsp+0x30,c['playerId'])
    elif c['mode']=='clear':
        entry=0x1403870b0;args=[o,node,c['head'],0];wi(node,8);wi(node+0x9c,c['cancelFlag']);wi(node+0x38,99);wi(node+0x40,c['slot']);wq(o,heap+0x49000);wq(heap+0x49190,stop+0x100);wq(heap+0x49188,stop+0x108);wi(o+0xc4,5);wi(o+0xc8,6)
    else:
        entry=0x1403bbb60;args=[o,node,0,0];u.mem_write(node+0x9a,struct.pack('<H',c['parameterCount']));wi(node+0x38,99);wq(node+0x40,c['slot']);wq(node+0x48,c['playerId'])
    for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],args):u.reg_write(reg,value&0xffffffffffffffff)
    try:u.emu_start(entry,stop,count=20000)
    except Exception:print(json.dumps(dict(case=c,rip=hex(u.reg_read(UC_X86_REG_RIP)),calls=calls)));raise
    assert u.reg_read(UC_X86_REG_RIP)==stop
    actions=[]
    for ptr in nodes:
        v=q(ptr+8);actions.append(dict(time=si(v),duration=si(v+8),nativeActionType=i(v+0x10)&255,targetId=i(v+0x14),followTarget=i(v+0x18),count=si(v+0xc),equipmentSlot=i(v+0x1c)))
    return dict(case=c,calls=calls,result=u.reg_read(UC_X86_REG_RAX)&0xffffffff,actions=actions,timer=si(r+0x2f0c),length=si(r+0x2f10),startDay=i(o+0xc4),startTime=i(o+0xc8))
attack=dict(time=900,duration=1000,nativeActionType=1,targetId=88,followTarget=1,count=1,equipmentSlot=0)
equip=dict(time=400,duration=1500,nativeActionType=6,targetId=100,followTarget=1,count=0,equipmentSlot=16)
default=dict(mode='request',client=False,message=True,itemExists=True,possessed=0,pc=0,gate=1,combat=0,started=0,paused=0,length=6000,slot=16,front=0,force=0,playerId=0x7f000000,actions=[attack],parameterCount=3,pause=0,exclusion=1,dead=0,dying=0,runResult=1)
requests=[run(default|dict(gate=gate,combat=combat,slot=slot,started=started,paused=paused,front=front,force=force,client=client)) for gate,combat,slot,started,paused,front,force,client in itertools.product([0,1],[0,1,2],[2,16],[0,1,2],[0,1,2],[0,1],[0,1],[False,True])]
rounds=[run(default|dict(mode='round',started=started,paused=paused,actions=actions,slot=slot,itemExists=exists,pc=pc,possessed=possessed,message=message,length=length)) for started,paused,actions,slot,exists,pc,possessed,message,length in itertools.product([0,1,2],[0,1,2],[[],[attack],[equip,attack],[equip|dict(targetId=99),attack]],[16,32],[False,True],[0,1],[0,1],[False,True],[0,800,6000])]
ai=[run(default|dict(mode='ai',parameterCount=count,pause=pause,exclusion=exclusion,dead=dead,dying=dying,runResult=result,client=client,playerId=player)) for count,pause,exclusion,dead,dying,result,client,player in itertools.product([0,1,2,3],[0,1],[0,1],[0,1],[0,1],[0,1,2],[False,True],[0x7f000000,123])]
clear=[run(default|dict(mode='clear',cancelFlag=flag,head=head,lock=lock,client=client,message=message)) for flag,head,lock,client,message in itertools.product([0,1],[0,1,2],[0x7f000000,88],[False,True],[False,True])]
out=root/'backups/animations/native-equipment-action-observations.json';out.write_text(json.dumps(dict(binarySha256=digest,limits=__doc__,requests=requests,rounds=rounds,ai=ai,clear=clear),indent=2));print(json.dumps(dict(output=str(out),requests=len(requests),rounds=len(rounds),ai=len(ai),clear=len(clear))))
