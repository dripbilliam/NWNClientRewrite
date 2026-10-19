"""Read-only complete native area visual loader872770, phase873160 and AI872330.
Profiling disabled. Table reads, resource/model wrapper, audio, timer subtraction,
scene/destroy, CRT allocation/string/ref copy and camera shake are captured lower
boundaries. These prove owner calls/branches/state, not original audio/GPU/cache,
world clock construction or ground orientation. No original runtime modification.
"""
import importlib,itertools,json,struct
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
effect,manager,app,rules,table,model,vt,head,sound=[m.heap+n*0x1000 for n in range(1,10)]
ranges=[]
for name in ['network-area-visual-load','network-area-visual-start','network-area-visual-ai']:
 d=json.loads((m.root/f'backups/animations/rea-{name}.json').read_text())['structuredContent']['raw_result']['value'];ranges.extend((int(r['start'],16),int(r['end'],16)+1)for r in d['procedure']['body']['ranges'])
fields={'retire178':0x178,'remaining17c':0x17c,'visual180':0x180,'retiring188':0x188,'suppressed18c':0x18c,'instant190':0x190,'destroy194':0x194,'orient198':0x198,'detach19c':0x19c,'skipRetirement1a0':0x1a0,'repeat1a4':0x1a4,'elapsed58':0x58}
def alloc(n):
 global cursor
 p=m.heap+cursor;cursor+=(n+31)&~15;assert cursor<0xe0000;return p
def text(p):
 a=m.q(p);return bytes(u.mem_read(a,m.si(p+8))).decode()if a else''
def string(p,s):
 b=s.encode();a=alloc(len(b)+1);u.mem_write(a,b+b'\0');m.wq(p,a);m.wi(p+8,len(b));m.wi(p+12,len(b)+1)
def vector(p):return list(struct.unpack('<3f',u.mem_read(p,12)))
def retf(v):u.reg_write(UC_X86_REG_XMM0,int.from_bytes(struct.pack('<f',v),'little'));m.finish()
def hook(u,a,n,_):
 global destroyed
 if a==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(r)for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];sp=u.reg_read(UC_X86_REG_RSP)
 if a in [0x140c10370,0x140c10410]:m.finish();return
 if a in [0x140c10368,0x140c10324]:m.finish(alloc(x));return
 if a in [0x1401a68f0,0x1401a7010,0x1401a6c70]:
  col=text(z);v=c.get('entries',{}).get(col,dict(found=False,value=''if a==0x1401a68f0 else 0));calls.append(['query',col])
  if v['found']:
   if a==0x1401a68f0:string(w,v['value'])
   elif a==0x1401a7010:m.wi(w,v['value'])
   else:m.wf(w,v['value'])
  m.finish(int(v['found']));return
 if a==0x1406ab9b0:m.finish(app);return
 if a==0x1406abea0:m.finish(app);return
 if a==0x14018dea0:u.mem_write(x,text(y).encode()[:16].ljust(17,b'\0'));m.finish(x);return
 if a==0x14018ded0:u.mem_write(x,bytes(u.mem_read(y,17)));m.finish(x);return
 if a in [0x1407cbfa0,0x1407cfd00]:calls.append(['shake',1 if a==0x1407cbfa0 else 2,y,z if a==0x1407cfd00 else 0]);m.finish();return
 if a==0x1401d9c40:calls.append(['oneShot',bytes(u.mem_read(y,17)).split(b'\0')[0].decode(),vector(z),m.xmm(UC_X86_REG_XMM3),m.si(sp+0x28)&255,m.si(sp+0x30)&0xffffffff,m.si(sp+0x38)&255]);m.finish();return
 if a==0x1401d95b0:calls.append(['createSound',bytes(u.mem_read(y,17)).split(b'\0')[0].decode()]);m.wq(x,head);m.finish(x);return
 if a in [0x1401d9e90,0x1401da060,0x1401d9f90]:calls.append([{0x1401d9e90:'sound3d',0x1401da060:'soundPriority',0x1401d9f90:'soundLooping'}[a],y]);m.finish();return
 if a==0x1401d9ca0:calls.append(['playSound']);m.finish();return
 if a==0x1401da320:calls.append(['stopSound']);m.finish();return
 if a==0x1401da020:calls.append(['updateSound',vector(y),m.xmm(UC_X86_REG_XMM2)]);m.finish();return
 if a==m.stop+0x10:destroyed=True;calls.append(['destroy']);m.finish();return
 if a==m.stop+0x20:calls.append(['loadModel',bytes(u.mem_read(y,17)).split(b'\0')[0].decode(),z&255,w&255]);m.finish(c.get('load',1));return
 if a==m.stop+0x30:calls.append(['animationMode',y&255]);m.finish();return
 if a==m.stop+0x40:calls.append(['defaultAnimation']);m.finish();return
 if a==m.stop+0x50:calls.append(['length',y&65535]);retf(c.get('length',1250.5));return
 if a==m.stop+0x60:calls.append(['play',y&65535,m.xmm(UC_X86_REG_XMM2),w&0xffffffff,m.si(sp+0x28)]);m.finish(1);return
 if a==m.stop+0x70:calls.append(['setScene',y]);m.finish();return
 if a==m.stop+0x80:calls.append(['destroySound']);m.finish();return
 if a==0x1406ac330:m.finish(app);return
 if a==0x140597180:m.wi(y,c.get('now',dict(day=2,time=10000))['day']);m.wi(z,c.get('now',dict(day=2,time=10000))['time']);m.finish();return
 if a==0x140597a20:m.wi(m.q(sp+0x30),c.get('difference',dict(day=0,time=1))['day']);m.wi(m.q(sp+0x38),c.get('difference',dict(day=0,time=1))['time']);m.finish();return
 if not any(lo<=a<hi for lo,hi in ranges):raise RuntimeError(f'Unmapped area visual dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,calls,cursor,destroyed
 c=case;calls=[];cursor=0x20000;destroyed=False;u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));m.wq(0x1412df970,manager);m.wq(manager,app);m.wq(0x1412df8f8,app);m.wq(app+0x130,rules);m.wq(rules+0x280,table);m.wi(app+100,c.get('quality',1));m.wf(0x141297d74,.75)
 m.wq(effect,vt);m.wq(model,vt);m.wq(effect+0x78,model if c.get('model',True)else 0);m.wq(effect+0x170,sound if c.get('sound')else 0);m.wq(sound,head);m.wq(head,m.stop+0x80)
 for offset,target in [(0,0x10),(0xf0,0x20),(0x160,0x30),(0x170,0x40),(0x48,0x50),(0x80,0x60),(0x138,0x70)]:m.wq(vt+offset,m.stop+target)
 for key,off in fields.items():m.wi(effect+off,c.get('state',{}).get(key,1 if key=='destroy194'else -1 if key=='visual180'else 0))
 for i,v in enumerate([1.25,-2,3.5]):m.wf(effect+0x38+i*4,v)
 u.mem_write(effect+0x184,struct.pack('<H',c.get('state',{}).get('phase184',0)))
 m.wi(effect+0x50,1);m.wi(effect+0x54,2)
 sp=m.stack+0x1fe08;m.wq(sp,m.stop);u.reg_write(UC_X86_REG_RSP,sp);u.reg_write(UC_X86_REG_RCX,effect);u.reg_write(UC_X86_REG_RDX,c.get('id',c.get('phase',1)))
 entry={'load':0x140872770,'start':0x140873160,'update':0x140872330}[c['kind']]
 try:u.emu_start(entry,m.stop,count=100000)
 except Exception:print(json.dumps(dict(case=c,calls=calls,ip=hex(u.reg_read(UC_X86_REG_RIP)))));raise
 state={key:m.si(effect+off)&0xffffffff for key,off in fields.items()};state['phase184']=int.from_bytes(u.mem_read(effect+0x184,2),'little');state['sound']=bool(m.q(effect+0x170));state['since']=dict(day=m.si(effect+0x50)&0xffffffff,time=m.si(effect+0x54)&0xffffffff)
 return dict(case=c,calls=calls,state=state,destroyed=destroyed,result=u.reg_read(UC_X86_REG_RAX)&0xffffffff)
rows=[]
for quality,chosen,load,id_ in itertools.product([0,1],['LowQuality','Imp_HeadCon_Node','Imp_Impact_Node','Imp_Root_M_Node','Imp_Root_H_Node',None],[0,1],[36,39,40,99,219,253]):
 entries={chosen:dict(found=True,value='fixture')}if chosen else{};rows.append(run(dict(kind='load',quality=quality,entries=entries,load=load,id=id_)))
for phase,hasModel,hasSound,repeat,id_ in itertools.product([1,2,3,65535],[False,True],[False,True],[0,1],[36,40]):rows.append(run(dict(kind='start',phase=phase,model=hasModel,sound=hasSound,state=dict(visual180=id_,repeat1a4=repeat),entries={'SoundImpact':dict(found=True,value='impact'),'SoundDuration':dict(found=True,value='duration'),'SoundCessation':dict(found=True,value='cessation')})))
for phase,remaining,elapsed,instant,destroy,skip,suppressed in itertools.product([1,2,3],[0,1,1250],[0,1,1249,1250,4000],[0,1],[0,1],[0,1],[0,1]):rows.append(run(dict(kind='update',state=dict(visual180=36,phase184=phase,remaining17c=remaining,instant190=instant,destroy194=destroy,skipRetirement1a0=skip,suppressed18c=suppressed),difference=dict(day=0,time=elapsed),sound=True)))
out=m.root/'backups/animations/native-area-visual-observations.json';out.write_text(json.dumps(dict(target=m.digest,limits=__doc__,cases=rows),indent=2)+'\n');print(json.dumps(dict(cases=len(rows),output=str(out))))
