"""Read-only build89 encounter points, polygon, activation, tally and
SpawnIfAppropriate/CalculateSpawnPool owner executions. Synthetic loaded
CR/class tables and objects; lookup, spatial lower-bound, ranks/life/class,
campaign/config and spawning dependencies captured. powf/log use host math
substitutions. No full spawn-list, creature lifetime, native libm or packet proof.
"""
from pathlib import Path
import sys,struct,hashlib,json,itertools,math
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
enc,area,app,vt,activate,spatial,points,mins,minlist,settings,rules,classes,polygon=[heap+n*0x2000 for n in range(13)]
def i(a):return int.from_bytes(u.mem_read(a,4),'little')
def q(a):return int.from_bytes(u.mem_read(a,8),'little')
def wi(a,v):u.mem_write(a,struct.pack('<I',v&0xffffffff))
def wq(a,v):u.mem_write(a,struct.pack('<Q',v))
def wf(a,v):u.mem_write(a,struct.pack('<f',v))
def rf(a):return struct.unpack('<f',u.mem_read(a,4))[0]
def signed(v):return struct.unpack('<i',struct.pack('<I',v&0xffffffff))[0]
def f(v):return struct.unpack('<f',struct.pack('<f',v))[0]
def xm(r,double=False):return struct.unpack('<d' if double else '<f',u.reg_read(r).to_bytes(16,'little')[:8 if double else 4])[0]
def setxm(r,v,double=False):u.reg_write(r,int.from_bytes(struct.pack('<d' if double else '<f',v),'little'))
def finish(v=0):
    rsp=u.reg_read(UC_X86_REG_RSP);u.reg_write(UC_X86_REG_RIP,q(rsp));u.reg_write(UC_X86_REG_RSP,rsp+8);u.reg_write(UC_X86_REG_RAX,v&0xffffffffffffffff)
def hook(u,a,n,_):
    global allocation
    if a==stop:u.emu_stop();return
    x,y,z,w=[u.reg_read(r) for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
    if a in [0x140c10370]:finish()
    elif a==0x140494e80:finish(area if case['hasArea'] else 0)
    elif a==0x14055b3d0:finish(actor_ptrs.get(y&0xffffffff,0))
    elif a==0x14035e820:
        minimum=xm(UC_X86_REG_XMM2);index=next((n for n,o in enumerate(case['actors']) if f(o['point'][0])>=minimum),None)
        if index is not None:wi(y,index)
        finish(int(index is not None))
    elif a==0x1404ab6c0:finish(actors[x]['reaction'])
    elif a==0x1404953b0:finish(actors[x]['dead'])
    elif a==0x140495620:finish(actors[x]['dying'])
    elif a==0x1403d54d0:finish(actors[x]['possessed'])
    elif a==0x14055b6e0:finish(app)
    elif a==0x14047e430:finish(case['campaign'])
    elif a==0x1404058f0:finish(stat_actors[x]['level']&255)
    elif a==0x1403fa4a0:finish(stat_actors[x]['classes'][y&255]['id']&255)
    elif a==0x1403fa4f0:finish(stat_actors[x]['classes'][y&255]['level']&255)
    elif a==0x140c7c810:setxm(UC_X86_REG_XMM0,math.pow(xm(UC_X86_REG_XMM0),xm(UC_X86_REG_XMM1)));finish()
    elif a==0x140c927f0:setxm(UC_X86_REG_XMM0,math.log(xm(UC_X86_REG_XMM0,True)),True);finish()
    elif a==0x140c10368:allocation+=0x1000;finish(allocation)
    elif a==stop+0x100:finish(settings if case['option'] is not None else 0)
    elif a==0x14043f000:calls.append(['spawn']);finish()
    elif not any(start<=a<end for start,end in [(0x14043b220,0x14043b2c9),(0x14043b2d0,0x14043b3b1),(0x14043f760,0x14043f8ac),(0x14043f8b0,0x14043fbe3),(0x14043fbf0,0x14043ff79),(0x14043c150,0x14043c2eb)]):raise RuntimeError(f'Unmapped encounter dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(c):
    global case,calls,actor_ptrs,actors,stat_actors,allocation
    case=c;calls=[];actor_ptrs={};actors={};stat_actors={};allocation=heap+0x80000;u.mem_write(heap,bytes(0x100000))
    wq(0x1412df970,app);wq(app+8,app);wq(app,vt);wq(vt+0x68,stop+0x100);wq(0x1412df8f8,rules);wq(rules+0x110,classes);wq(0x14141ee58,points)
    for n in range(51):wf(points+n*4,f(math.pow(1.5,n)))
    wq(enc+0x428,minlist);wq(minlist,mins)
    for n,v in enumerate(c['minima']):wf(mins+n*4,v)
    wi(enc+8,77);wi(enc+0x320,c['active']);wi(enc+0x354,c['started']);wi(enc+0x36c,9);wi(enc+0x330,c['difficulty']);wi(enc+0x3cc,c['lastEntered']);wi(enc+0x434,c['playerOnly'])
    wi(enc+0x35c,c['capacity']);wq(enc+0x360,activate);wi(enc+0x368,len(c['initial']))
    for n,id in enumerate(c['initial']):wi(activate+n*4,id)
    for off,v in [(0x37c,-2),(0x380,2),(0x384,-2),(0x388,2),(0x3c0,c['areaPoints']),(0x3c4,c['pool'])]:wf(enc+off,v)
    wq(enc+0x370,polygon);wi(enc+0x378,4)
    for n,(x,y) in enumerate([(-2,-2),(2,-2),(2,2),(-2,2)]):u.mem_write(polygon+n*12,struct.pack('<fff',x,y,0))
    wi(settings+0x160,c['option'] or 0);wq(area+0x228,spatial);wi(area+0x230,len(c['actors']))
    for n,o in enumerate(c['actors']):
        actor=heap+0x30000+n*0x1800;stats=actor+0x1000;actor_ptrs[o['id']]=actor;actors[actor]=o;stat_actors[stats]=o;wi(spatial+n*4,o['id']);wi(actor+8,o['id']);u.mem_write(actor+0xa4,struct.pack('<fff',*o['point']));wq(actor+0xad0,stats);wi(stats+0xb0,o['statsPC']);wi(actor+0x89c,o['pc']);wi(actor+0x8fc,o['master']);u.mem_write(actor+0x908,struct.pack('<H',o['associate']));u.mem_write(stats+0xd8,bytes([len(o['classes'])]))
    for n,values in enumerate(c['effective']):
        for level,v in enumerate(values):u.mem_write(classes+n*0x530+0x4a8+level,bytes([v]))
    rsp=stack+0xff08;u.mem_write(rsp-0x2000,bytes(0x2080));wq(rsp,stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,enc);u.reg_write(UC_X86_REG_RDX,c['enterer']);setxm(UC_X86_REG_XMM1,c['cr']);setxm(UC_X86_REG_XMM2,c['cr'])
    address={'points':0x14043b220,'pool':0x14043b2d0,'activate':0x14043fbf0,'tally':0x14043f8b0,'spawn':0x14043f760}[c['mode']]
    try:u.emu_start(address,stop,count=20000)
    except Exception:print(json.dumps({'case':c,'rip':hex(u.reg_read(UC_X86_REG_RIP))}));raise
    assert u.reg_read(UC_X86_REG_RIP)==stop
    return {'case':c,'points':xm(UC_X86_REG_XMM0) if c['mode']=='points' else None,'areaPoints':rf(enc+0x3c0),'pool':rf(enc+0x3c4),'score':signed(i(enc+0x3ac)),'canSpawn':i(enc+0x36c),'started':i(enc+0x354),'capacity':i(enc+0x35c),'ids':[i(q(enc+0x360)+n*4) for n in range(i(enc+0x368))],'calls':calls}
actor=dict(id=11,point=[0,0,0],reaction=2,dead=0,dying=0,statsPC=1,pc=1,possessed=0,master=0x7f000000,associate=0,level=2,classes=[{'id':0,'level':2}])
default=dict(hasArea=True,active=1,started=0,difficulty=1,areaPoints=7,pool=1,lastEntered=11,playerOnly=0,capacity=16,initial=[],actors=[actor],option=0,campaign=0,cr=-1,enterer=11,minima=[.4,.3,.2,.15,-99999],effective=[list(range(41)),[min(255,n*2) for n in range(41)]])
cases=[]
for minima,cr in itertools.product([default['minima'],[.8,.6,.4,.2,0]],[-5,-1,0,.1,.15,.2,.3,.4,.5,.9,1,1.9,2,10,49.9,50,51]):cases.append(default|dict(mode='points',minima=minima,cr=cr))
for mode,cr,difficulty,pool,option in itertools.product(['pool','spawn'],[-1,0,.125,.5,1,2,5],[-1,0,1,5],[0,1,10],[None,0,1]):cases.append(default|dict(mode=mode,cr=cr,difficulty=difficulty,pool=pool,option=option))
for mode,statsPC,dead,dying,reaction,playerOnly,active,started in itertools.product(['activate','spawn'],[0,1],[0,1],[0,1],[0,2],[0,1],[0,1],[0,1]):cases.append(default|dict(mode=mode,playerOnly=playerOnly,active=active,started=started,actors=[actor|dict(statsPC=statsPC,dead=dead,dying=dying,reaction=reaction)]))
for mode,campaign,pc,statsPC,associate,master,level in itertools.product(['tally'],[0,1,2],[0,1],[0,1],[0,1],[0x7f000000,11],[0,1,2,40]):cases.append(default|dict(mode=mode,campaign=campaign,actors=[actor|dict(pc=pc,statsPC=statsPC,associate=associate,master=master,level=level,classes=[{'id':0,'level':level}])]))
for hasArea,initial,enterer in itertools.product([False,True],[[],[11,11,12,13,99]],[11,99]):cases.append(default|dict(mode='activate',hasArea=hasArea,initial=initial,enterer=enterer,actors=[actor|dict(id=11,point=[-3,0,0]),actor|dict(id=12,point=[-2,0,0]),actor|dict(id=13,point=[0,0,0]),actor|dict(id=14,point=[2,0,0]),actor|dict(id=15,point=[3,0,0])]))
cases.append(default|dict(mode='activate',actors=[actor|dict(id=n+11,point=[0,0,0]) for n in range(35)]))
observations=[run(c) for c in cases]
output=root/'backups/animations/native-encounter-activation-observations.json';output.write_text(json.dumps({'binarySha256':digest,'limits':__doc__,'observations':observations},indent=2));print(json.dumps({'output':str(output),'observations':len(observations)}))
