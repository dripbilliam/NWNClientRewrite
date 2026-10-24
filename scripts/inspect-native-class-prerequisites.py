"""Original GetMeetsPrestigeClassRequirements executes unchanged. C2DA IO,
allocation, skill/feat/save/BAB/local queries are captured typed boundaries;
this does not execute class creation, resource IO or the complete validator.
"""
from pathlib import Path
import importlib.util,json,itertools
root=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('mapped',root/'scripts/inspect-native-intratile-coordinator.py')
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
stats,cls,owner,rules,infos=[m.heap+x for x in [0x1000,0x4000,0x7000,0x8000,0x10000]]
current={};cursor=0
def cstr(p):
    out=bytearray()
    while p and len(out)<1024:
        b=bytes(u.mem_read(p+len(out),1))
        if b==b'\0':break
        out.extend(b)
    return out.decode('ascii')
def alloc(size):
    global cursor
    p=m.heap+0x90000+cursor;cursor+=(size+15)&~15;assert cursor<0x10000;u.mem_write(p,bytes(size));return p
def hook(u,a,n,_):
    if a==m.stop:u.emu_stop();return
    x,y,z,w=[u.reg_read(r)for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
    if a==0x140c10368:m.finish(alloc(x));return
    if a==0x140c10410:m.finish(u.reg_read(UC_X86_REG_RAX));return
    if a in [0x140c10370,0x1401a65a0,0x1401a9b10]:m.finish();return
    if a==0x14018ded0:m.finish(x);return
    if a==0x1401a62b0:m.wi(x+0x50,len(current['requirements']));m.finish(x);return
    if a==0x1401a73a0:m.finish(1);return
    if a==0x1401a6a80:m.finish(['ReqType','ReqParam1','ReqParam2'].index(cstr(m.q(y))));return
    if a in [0x1401a69e0,0x1401a7120]:
        key=['ReqType','ReqParam1','ReqParam2'][z];value=current['requirements'][y].get(key)
        if value is None:m.finish(0);return
        if a==0x1401a7120:m.wi(w,int(value));m.finish(1);return
        text=str(value).encode('ascii');p=alloc(len(text)+1);u.mem_write(p,text+b'\0');m.wq(w,p);m.wi(w+8,len(text));m.wi(w+12,len(text)+1);m.finish(1);return
    if a==0x140406a40:m.finish(current['skills'].get(str(y&255),0));return
    if a==0x14040b900:m.finish(int((y&65535)in current['feats']));return
    if a==0x1403f8e90:m.finish(current['bab']);return
    if a in [0x1403f9040,0x1403f9550,0x1403f9a60]:m.finish(current['saves'][[0x1403f9040,0x1403f9550,0x1403f9a60].index(a)]);return
    if a==0x140507460:m.finish(current['locals'].get(cstr(m.q(y)),0));return
    if a==0x140c799d0:m.finish(int(cstr(x)!=cstr(y)));return
    if 0x140403810<=a<=0x1404041bb:return
    raise RuntimeError(f'Uncaptured prerequisite dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
    global current,cursor
    current=dict(requirements=[],race=6,feats=[],skills={},bab=0,saves=[0,0,0],classes=[],locals={})|case;cursor=0
    u.mem_write(stats,bytes(0x2000));u.mem_write(cls,bytes(0x1000));u.mem_write(infos,bytes(0x60000));m.wq(0x1412df8f8,rules);m.wq(rules+0x110,infos);m.wq(stats+0x30,owner)
    u.mem_write(stats+0xd20,int(current['race']).to_bytes(2,'little'));u.mem_write(stats+0xd8,bytes([len(current['classes'])]));m.wi(cls+0x30,1)
    for i,c in enumerate(current['classes']):
        u.mem_write(stats+0x25c+i*0x188,bytes([c['id'],c['level']]));m.wi(infos+c['id']*0x530+0x4d8,int(c.get('spellCaster',False)));m.wi(infos+c['id']*0x530+0x500,int(c.get('arcane',False)))
    rsp=m.stack+0x1fe08;u.mem_write(rsp-0x400,bytes(0x500));m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,stats);u.reg_write(UC_X86_REG_RDX,cls)
    u.emu_start(0x140403810,m.stop,count=50000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
    return dict(case=current,result=u.reg_read(UC_X86_REG_RAX)&0xffffffff)
def req(t,a=0,b=0):return dict(ReqType=t,ReqParam1=a,ReqParam2=b)
if __name__=='__main__':
    cases=[{}]
    for t,a,b in [('SKILL',3,4),('FEAT',5,0),('RACE',6,0),('FEATOR',5,0),('BAB',3,0),('SPELL',3,0),('ARCSPELL',3,0),('VAR','test',2),('CLASSNOT',79,0),('CLASSOR',10,0),('SAVE',1,2),('SAVE',2,2),('SAVE',3,2),('SAVE',4,999),('UNKNOWN',0,0),('classnot',79,0)]:
        for race,feats,skill,bab,classes,local in itertools.product([4,6],[[],[5]],[0,4],[0,3],[[],[dict(id=10,level=3,spellCaster=True,arcane=True)],[dict(id=79,level=1)]],[0,2]):
            cases.append(dict(requirements=[req(t,a,b)],race=race,feats=feats,skills={'3':skill},bab=bab,classes=classes,locals={'test':local},saves=[skill]*3))
    for race,feats,classes in itertools.product([4,6,9],[[],[5],[8]],[[],[dict(id=10,level=1)],[dict(id=79,level=1)]]):
        cases.append(dict(requirements=[req('CLASSNOT',79),req('RACE',4),req('RACE',6),req('FEATOR',5),req('FEATOR',8),req('CLASSOR',10),req('CLASSOR',79)],race=race,feats=feats,classes=classes))
    observed=[run(c)for c in cases];out=root/'backups/animations/native-class-prerequisite-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=observed),indent=2));print(json.dumps(dict(output=str(out),cases=len(observed))))

