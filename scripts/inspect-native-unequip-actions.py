"""Read-only original unequip request, round insertion, action dispatch,
cancellation and repository page. Native round rescaling runs unchanged;
list/allocation, clients, eligibility, activity, fitting and messaging captured.
"""
import importlib.util,itertools,json,struct
from pathlib import Path
spec=importlib.util.spec_from_file_location('coordinator',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle);q,si,wi,wq,finish=[getattr(m,n) for n in ['q','si','wi','wq','finish']]
o,r,item,node,app,client,msg,wrapper,linked,vtable=[m.heap+n*0x4000 for n in range(10)]
ranges=[(0x140374f80,0x14037511c),(0x140375a30,0x140375b7f),(0x140380bd0,0x140380e11),(0x1403cef60,0x1403cf7e0),(0x1403870b0,0x1403877dd),(0x1404656a0,0x1404656b6)]
def sync():
    wq(linked,nodes[0] if nodes else 0)
    for n,ptr in enumerate(nodes):wq(ptr,nodes[n+1] if n+1<len(nodes) else 0)
def hook(u,a,n,_):
    if a==m.stop:u.emu_stop();return
    x,y,z,w=[u.reg_read(reg) for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
    if a in [0x14055b390,0x14055f720]:finish(client if c['client'] else 0)
    elif a==0x14055b810:finish(msg if c['message'] else 0)
    elif a==0x14055b6c0:finish(item if c['exists'] else 0)
    elif a==0x140462bd0:finish(item if c['armor'] else 0)
    elif a==0x1403d22b0:calls.append(['gate']);finish(c['allowed'])
    elif a==0x140374f80 and c['mode']=='request':calls.append(['round',y&0xffffffff,z&0xffffffff,w&255,si(rsp+0x28)&255]);finish()
    elif a==0x1404dab80:calls.append(['cancel',z&0xffffffff,w&0xffffffff]);finish()
    elif a==0x1403a2480:calls.append(['feedback',y&0xffffffff]);finish()
    elif a in [0x14048cb80,0x14048d3f0,0x14048ced0]:
        values=[[w&0xffffffff,si(q(rsp+0x28))&0xffffffff]]+[[si(rsp+0x30+k*16),si(q(rsp+0x38+k*16))& (255 if k in [1,2] else 0xffffffff)] for k in range(4)]
        calls.append(['queue',{0x14048cb80:'tail',0x14048d3f0:'front',0x14048ced0:'afterFront'}[a],y&0xffffffff,z&65535,values]);finish()
    elif a==0x1401690b0:finish(q(y+8))
    elif a==0x140169110:wq(y,q(q(y)));finish()
    elif a==0x140c10324:finish(m.heap+0x78000)
    elif a in [0x140168ed0,0x140169030]:
        ptr=m.heap+0x77000;wq(ptr+8,y);nodes.insert(0,ptr) if a==0x140168ed0 else nodes.append(ptr);sync();finish(ptr)
    elif a==0x14055b590:calls.append(['controlled']);finish(c['controlled'])
    elif a==0x1402ae870:finish()
    elif a==0x1402a4130:calls.append(['interact']);finish(c['interact'])
    elif a==0x14037cc30:calls.append(['activity',y&0xffffffff]);finish()
    elif a==0x14055b860:calls.append(['pause']);finish(c['pause'])
    elif a==0x14055bb60:calls.append(['exclusion']);finish(c['exclusion'])
    elif a==0x1404953b0:calls.append(['dead']);finish(c['dead'])
    elif a==0x140495620:calls.append(['dying']);finish(c['dying'])
    elif a==0x14039fff0:calls.append(['run',y&0xffffffff,z&0xffffffff,w&255,si(rsp+0x28)&255,si(rsp+0x30),si(rsp+0x38)&0xffffffff]);finish(c['runResult'])
    elif a==m.stop+0x100:finish(c['lock'])
    elif a==m.stop+0x108:calls.append(['lock',y&0xffffffff]);finish()
    elif not any(lo<=a<hi for lo,hi in ranges):raise RuntimeError(f'Unmapped unequip action dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
    global c,calls,nodes
    c=case;calls=[];nodes=[];u.mem_write(m.heap,bytes(0x100000));wq(0x1412df970,app);wq(app+8,app);wq(app+8+8,app);wi(o+8,77);wi(o+0xec,c['gate']);wi(o+0x700,c['combat']);wq(o+0x880,r);wq(o+0x950,linked);wi(item+0x50,99);wi(client+0x48,1)
    wq(r+0x2f70,wrapper);wq(wrapper,linked);wq(r+0x2f78,o)
    for off,v in [(0x2f04,c['started']),(0x2f08,c['paused']),(0x2f0c,240),(0x2f10,6000),(0x2f14,0)]:wi(r+off,v)
    for n,a in enumerate(c['actions']):
        ptr=m.heap+0x70000+n*0x100;value=ptr+0x40;nodes.append(ptr);wq(ptr+8,value)
        for off,key in [(0,'time'),(8,'duration'),(0xc,'count'),(0x10,'nativeActionType'),(0x14,'targetId'),(0x18,'followTarget'),(0x20,'repositoryId'),(0x24,'repositoryX')]:wi(value+off,a[key])
        u.mem_write(value+0x25,bytes([a['repositoryY']]))
    sync();rsp=m.stack+0x1fe08;u.mem_write(rsp-0x300,bytes(0x400));wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
    if c['mode']=='round':entry=0x140374f80;args=[r,99,88,255];wi(rsp+0x28,254)
    elif c['mode']=='request':
        entry=0x140380bd0;args=[o,item,88,255]
        for n,v in enumerate([254,c['front'],c['force'],c['playerId']]):wi(rsp+0x28+n*8,v)
    elif c['mode']=='clear':
        entry=0x1403870b0;args=[o,node,c['head'],0];wi(node,11);wi(node+0x38,99);wi(node+0x9c,c['cancelFlag']);wq(o,vtable);wq(vtable+0x190,m.stop+0x100);wq(vtable+0x188,m.stop+0x108);wi(o+0xc4,5);wi(o+0xc8,6)
    else:
        entry=0x1403cef60;args=[o,node,0,0];u.mem_write(o+0x908,struct.pack('<H',c['associate']));u.mem_write(node+0x9a,struct.pack('<H',c['count']));wi(node+0x38,99);wi(node+0x40,88);wi(node+0x48,255);wi(node+0x50,254);wi(node+0x58,c['playerId'])
    for reg,v in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],args):u.reg_write(reg,v&0xffffffffffffffff)
    try:u.emu_start(entry,m.stop,count=20000)
    except Exception:print(json.dumps(dict(case=c,rip=hex(u.reg_read(UC_X86_REG_RIP)),calls=calls)));raise
    assert u.reg_read(UC_X86_REG_RIP)==m.stop
    actionsOut=[]
    for ptr in nodes:
        v=q(ptr+8);actionsOut.append(dict(time=si(v),duration=si(v+8),count=si(v+0xc),nativeActionType=si(v+0x10)&255,targetId=si(v+0x14)&0xffffffff,followTarget=si(v+0x18),repositoryId=si(v+0x20)&0xffffffff,repositoryX=int.from_bytes(u.mem_read(v+0x24,1),'little'),repositoryY=int.from_bytes(u.mem_read(v+0x25,1),'little')))
    return dict(case=c,calls=calls,result=u.reg_read(UC_X86_REG_RAX)&0xffffffff,actions=actionsOut,timer=si(r+0x2f0c),length=si(r+0x2f10),startDay=si(o+0xc4),startTime=si(o+0xc8))
attack=dict(time=900,duration=1000,count=1,nativeActionType=1,targetId=100,followTarget=1,repositoryId=0x7f000000,repositoryX=255,repositoryY=255)
unequip=attack|dict(nativeActionType=7,targetId=99,time=400,duration=1500,count=0,repositoryId=77,repositoryX=3,repositoryY=4)
default=dict(mode='request',client=True,message=True,exists=True,armor=False,gate=1,combat=0,started=0,paused=0,front=0,force=0,playerId=0x7f000000,actions=[attack],allowed=1,associate=0,controlled=0,interact=0,count=5,pause=0,exclusion=1,dead=0,dying=0,runResult=1)
requests=[run(default|dict(gate=gate,combat=combat,armor=armor,started=started,paused=paused,front=front,force=force,playerId=player)) for gate,combat,armor,started,paused,front,force,player in itertools.product([0,1],[0,1,2],[False,True],[0,1,2],[0,1,2],[0,1],[0,1],[0x7f000000,77,123])]
rounds=[run(default|dict(mode='round',started=started,paused=paused,exists=exists,allowed=allowed,actions=acts)) for started,paused,exists,allowed,acts in itertools.product([0,1,2],[0,1],[False,True],[0,1,2],[[],[attack],[unequip],[unequip,attack],[attack,unequip]])]
ai=[run(default|dict(mode='ai',count=count,pause=pause,exclusion=exclusion,dead=dead,dying=dying,runResult=result,associate=associate,controlled=1,interact=interact)) for count,pause,exclusion,dead,dying,result,associate,interact in itertools.product([0,4,5],[0,1],[0,1],[0,1],[0,1],[0,1,2],[0,3],[0,1])]
clear=[run(default|dict(mode='clear',cancelFlag=flag,head=head,lock=lock,client=clientFlag,message=message)) for flag,head,lock,clientFlag,message in itertools.product([0,1],[0,1,2],[0x7f000000,88],[False,True],[False,True])]
pages=[]
for width,boundary,x,y in itertools.product([0,1,10,255],[1,60,65535,0xffffffff],[0,1,255,256,-1],[0,1,255,256,-1]):
    u.mem_write(o,bytes([width]));wi(o+4,boundary);rsp=m.stack+0x1fe08;wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
    for reg,v in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8],[o,x,y]):u.reg_write(reg,v&0xffffffffffffffff)
    u.emu_start(0x1404656a0,m.stop,count=100);pages.append(dict(width=width,boundary=boundary,x=x,y=y,result=u.reg_read(UC_X86_REG_RAX)&0xffffffff))
out=m.root/'backups/animations/native-unequip-action-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,requests=requests,rounds=rounds,ai=ai,clear=clear,pages=pages),indent=2));print(json.dumps(dict(output=str(out),requests=len(requests),rounds=len(rounds),ai=len(ai),clear=len(clear),pages=len(pages))))
