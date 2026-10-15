"""Read-only build89 full AIActionPickPocket execution. Synthetic actors,
repositories and RNG inputs; lookup, message/queue, rules, skill, acquisition,
reputation and movement helpers are captured substitutes. This validates owner
branch/order/state, not those helpers, live heap lifetime, casting or packets.
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
u.mem_map(heap,0x100000);u.mem_map(stack,0x10000);u.mem_map(stop,0x1000)
actor,victim,node,timers,stats,vs,repo,vt,app,rules,info=[heap+n*0x2000 for n in range(11)]
def i(a):return int.from_bytes(u.mem_read(a,4),'little')
def q(a):return int.from_bytes(u.mem_read(a,8),'little')
def wi(a,v):u.mem_write(a,struct.pack('<I',v&0xffffffff))
def wq(a,v):u.mem_write(a,struct.pack('<Q',v))
def signed(v):return struct.unpack('<i',struct.pack('<I',v&0xffffffff))[0]
def finish(v=0):
    rsp=u.reg_read(UC_X86_REG_RSP);u.reg_write(UC_X86_REG_RIP,q(rsp));u.reg_write(UC_X86_REG_RSP,rsp+8);u.reg_write(UC_X86_REG_RAX,v&0xffffffffffffffff)
def oid(p):return i(p+8)
def payload(p):return messages.get(p,{})
def hook(u,a,n,_):
    global allocation,roll_index,can_index
    if a==stop:u.emu_stop();return
    x,y,z,w=[u.reg_read(r) for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
    if a in [0x140c10370,0x140c10368,0x140c4f024]:finish()
    elif a==0x1404953b0:finish(case['dead'])
    elif a==0x140495620:finish(case['dying'])
    elif a==0x14037cc30:calls.append(['activity',y&0xffffffff]);finish()
    elif a==0x14055b3d0:finish((actor if case.get('target',22)==11 else victim) if case['present'] and case.get('targetType',5)==5 else 0)
    elif a==0x14055b4c0:finish((actor if case.get('target',22)==11 else victim) if case['present'] else 0)
    elif a==0x14055b850:finish(app)
    elif a==0x140296470:wq(z,victim if case['present'] else 0);finish(0 if case['present'] else 1)
    elif a==0x1403fa1d0:
        allowed=case['can'][min(can_index,1)];can_index+=1;calls.append(['can',y&255,allowed]);finish(allowed)
    elif a==0x14037cbc0:calls.append(['manager',y&0xffffffff]);finish()
    elif a==0x140402f80:finish(case['dm'])
    elif a in [stop+0x100,stop+0x108]:finish(0 if a==stop+0x100 and x==victim and case.get('targetType',5)!=5 else x)
    elif a==0x140391310:finish(case['range'])
    elif a==0x140396480:u.mem_write(z,struct.pack('<fff',1,2,3));u.mem_write(w,struct.pack('<f',1.5));finish()
    elif a in [0x14048d3f0,0x14048cb80]:
        params=[]
        for k in range(12):
            t=(w if k==0 else i(rsp+0x30+(k-1)*0x10))&0xffffffff
            ptr=q(rsp+0x28+k*0x10)
            if t:params.append({'type':t,'value':signed(i(ptr)) if t in [1,2] else i(ptr)})
        calls.append(['front' if a==0x14048d3f0 else 'add',y&0xffffffff,z&65535,params]);finish(1)
    elif a==0x14037fae0:calls.append(['move',y&65535,i(rsp+0x28),i(rsp+0x30)]);finish()
    elif a==0x140406a40:finish(case['rank']&255 if x==stats else case['spot']&255)
    elif a==0x1404ab6c0:finish(case['reaction'])
    elif a==0x1402ae870:finish(0) # Hash owner substituted; defaults identify queried rules.
    elif a==0x1402a4130:calls.append(['rule',signed(z)]);finish(z)
    elif a==0x1402ad680:
        rolled=case['rolls'][roll_index];roll_index+=1;calls.append(['dice',y&255,z&255,rolled]);finish(rolled)
    elif a==0x140c10324:
        allocation+=0x100;messages[allocation]={};finish(allocation)
    elif a in [0x1403ab1a0,0x1404c6490]:messages[x]={};finish(x)
    elif a in [0x1402da730,0x1402da770,0x1404c72e0,0x1404c7320]:
        key='integers' if a in [0x1402da730,0x1404c72e0] else 'objects'
        v=signed(z) if key=='integers' else z&0xffffffff
        values=messages[x].setdefault(key,[])
        while len(values)<=y:values.append(0)
        values[y]=v;finish()
    elif a==0x1403a2480:calls.append(['feedback',oid(x),y&65535,payload(z)]);finish()
    elif a==0x140384150:calls.append(['broadcast',oid(x),payload(y)]);finish()
    elif a==0x14055b960:finish(app)
    elif a==0x140557660:calls.append(['reputations',y&0xffffffff,z&0xffffffff,w&0xffffffff]);finish()
    elif a==0x1403d4d70:calls.append(['associate',oid(x),y&65535,z&0xffff]);finish(0x7f000000)
    elif a==0x1403877e0:calls.append(['clear',y&0xffffffff]);finish()
    elif a==0x1404693e0:finish(nodes[y][0])
    elif a==0x140169110:wq(y,nodes[q(y)][1]);finish()
    elif a==0x14029ca00:finish(info+y*0x100)
    elif a==0x1403d0230:
        if not q(x):wq(x,heap+0x70000)
        count=i(x+8);wq(q(x)+count*8,y);wi(x+8,count+1);finish()
    elif a==0x140c7ed00:calls.append(['random',case['random']]);finish(case['random'])
    elif a==0x1403cff30:calls.append(['acquire',i(q(y)+0x50),z&0xffffffff,w&0xffffffff,i(rsp+0x28)&255,i(rsp+0x30)&255,i(rsp+0x38),i(rsp+0x40)]);finish(case['acquire'])
    elif a in [0x14039e9b0,0x14037eda0]:calls.append(['removeGold' if a==0x14039e9b0 else 'addGold',oid(x),signed(y),z&0xffffffff]);finish()
    elif a==0x1405570b0:calls.append(['event',w&0xffffffff,i(rsp+0x28),int.from_bytes(u.mem_read(q(rsp+0x38),2),'little'),payload(q(rsp+0x38))]);finish(1)
    elif not(0x1403c50c0<=a<0x1403c67a4 or 0x1403aa390<=a<0x1403aae24):raise RuntimeError(f'Unmapped pickpocket dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(c):
    global case,calls,messages,allocation,roll_index,nodes,can_index
    case=c;calls=[];messages={};allocation=heap+0x80000;roll_index=0;can_index=0;nodes={};u.mem_write(heap,bytes(0x100000))
    u.mem_write(0x14141e310,b'\0');wq(0x1412df970,app);wq(app+8,app);wq(0x1412df8f8,rules);wq(rules+0x20,info)
    for p,id in [(actor,11),(victim,22)]:wq(p,vt);wi(p+8,id);wi(p+0xa0,33)
    wq(vt+0x60,stop+0x100);wq(vt+0x20,stop+0x108)
    wq(actor+0xad0,stats);wq(victim+0xad0,vs);wq(actor+0x878,timers);wi(timers+0x34,c['timer'])
    wi(actor+0x830,c['stage']);wi(actor+0x834,c['detected']);u.mem_write(victim+0x771,bytes([c['victimState']]))
    u.mem_write(victim+0x8d4,struct.pack('<H',c['word']));wi(victim+0x898,c['gold']);wi(node+0x38,22);wi(node+0x40,c['approach']);u.mem_write(node+0x98,struct.pack('<H',7))
    item_state=[]
    if c['items'] is not None:
        wq(victim+0x958,repo);wq(repo+0x10,repo+0x100)
        for k,item_case in enumerate(c['items']):
            item=heap+0x30000+k*0x2000;link=item+0x1000;nodes[link]=(item,link+0x2000 if k+1<len(c['items']) else 0)
            wi(item+0x50,100+k);wi(item+0x40,k);wi(info+k*0x100+0x80,item_case.get('container',0))
            for off,name in [(0x44c,'pick'),(0x450,'cursed'),(0x360,'identified'),(0x458,'stolen')]:wi(item+off,item_case.get(name,0))
            if item_case.get('container')==1:wq(item+0x3d0,item+0x1100);wq(item+0x1110,item+0x1200)
            item_state.append(item)
        wq(repo+0x100,heap+0x31000 if c['items'] else 0)
    rsp=stack+0xff08;u.mem_write(rsp-0x1000,bytes(0x1080));wq(rsp,stop)
    for r,v in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_RSP],[actor,node,rsp]):u.reg_write(r,v)
    address=0x1403c50c0
    if c.get('request'):
        address=0x1403aa390;u.mem_write(actor+0x771,bytes([c['actorState']]));wi(actor+0xec,c['commandable']);wi(victim+0x8fc,c['master']);wi(victim+0xa0,c['victimArea'])
        wq(rules+0x120,heap+0x60000);wi(heap+0x60000+(c['skill']&255)*0x38+0x24,c['hostile']);wq(rsp+0x28,heap+0x5f000);wi(rsp+0x30,33);wi(rsp+0x38,0x7f000000);wi(rsp+0x40,0)
        for r,v in zip([UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],[c['skill'],0,c['target']]):u.reg_write(r,v)
    try:u.emu_start(address,stop,count=5000)
    except Exception:
        print(json.dumps({'case':c,'rip':hex(u.reg_read(UC_X86_REG_RIP)),'calls':calls}));raise
    assert u.reg_read(UC_X86_REG_RIP)==stop
    return {'case':c,'result':u.reg_read(UC_X86_REG_RAX)&0xffffffff,'stage':i(actor+0x830),'detected':i(actor+0x834),'timer':i(timers+0x34),'stolen':[i(p+0x458) for p in item_state],'calls':calls}
default=dict(dead=0,dying=0,present=True,range=1,approach=1,timer=0,stage=0,detected=0,victimState=0,word=1,rank=30,spot=0,reaction=0,gold=10,rolls=[1,20,10,60],random=0,items=[],acquire=1)
cases=[]
for dead,dying,present,timer,state,stage,detected in itertools.product([0,1],[0,1],[False,True],[0,999,2001],[0,15],[0,1],[0,1]):cases.append(default|dict(dead=dead,dying=dying,present=present,timer=timer,victimState=state,stage=stage,detected=detected))
for rank,spot,reaction,word,gold,rolls,acquire in itertools.product([-128,0,30,127],[-1,40],[0,2],[0,1],[0,10],[[20,1,10,1],[1,20,10,60]],[0,1]):
    cases.append(default|dict(rank=rank,spot=spot,reaction=reaction,word=word,gold=gold,rolls=rolls,acquire=acquire,items=[{'pick':1,'identified':0},{'pick':1,'identified':2}]))
for pick,cursed,container,random in itertools.product([0,1],[0,1],[0,1,2],[0,1,32767]):cases.append(default|dict(stage=1,rolls=[20,60],gold=0,random=random,items=[{'pick':pick,'cursed':cursed,'container':container,'identified':2}]))
cases.append(default|dict(range=0));cases.append(default|dict(range=0,approach=0))
observations=[run(c) for c in cases]
request_default=default|dict(request=True,actorState=0,commandable=1,master=0x7f000000,victimArea=33,hostile=0,can=[1,1],dm=0,target=22,targetType=5,skill=13)
requests=[]
for skill,state,allowed,present,hostile,reaction in itertools.product([1,3,6,7,10,11,12,15,16,17,19,20,21,23,255,13],[0,5],[0,1],[False,True],[0,1],[0,1]):requests.append(run(request_default|dict(skill=skill,actorState=state,can=[allowed,1],present=present,hostile=hostile,reaction=reaction)))
for timer,second,dm,target,master,area,commandable,targetType in itertools.product([0,999,2001],[0,1],[0,1],[11,22],[11,0x7f000000],[33,44],[0,1],[5,9]):requests.append(run(request_default|dict(timer=timer,can=[1,second],dm=dm,target=target,master=master,victimArea=area,commandable=commandable,targetType=targetType)))
output=root/'backups/animations/native-pickpocket-observations.json';output.write_text(json.dumps({'binarySha256':digest,'limits':__doc__,'observations':observations,'requests':requests},indent=2));print(json.dumps({'output':str(output),'observations':len(observations),'requests':len(requests)}))
