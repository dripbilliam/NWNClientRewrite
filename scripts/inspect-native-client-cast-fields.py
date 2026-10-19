"""Original server cast-field branch4ebfec..4ec1b0 and client read/apply
782e68..782ed3, verified parent unwind functions4eb590/781e80. Server silent
metamagic/feat/class-level/fallback/cap control and client read/overflow/store
execute. GetClass3fa4a0 executes unchanged. Spell-level/feat/rule/hash and scalar
encoding/readers are captured lower services. Not full update flags/packet framing
or replication, client appearance/Gender, model/voice playback or GPU evidence.
"""
import importlib.util,itertools,json
from pathlib import Path
spec=importlib.util.spec_from_file_location('fixture',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle);actor,stats,spell,master,message,rules=[m.heap+n*0x2000 for n in range(1,7)]
keys=['EPIC_AUTOMATIC_LESSER_SILENT_LEVEL_CAP','EPIC_AUTOMATIC_SILENT_LEVEL_CAP','EPIC_AUTOMATIC_GREATER_SILENT_LEVEL_CAP']
def string(p):return bytes(u.mem_read(p,100)).split(b'\0')[0].decode('ascii')
def fnv(text,seed=0xcbf29ce484222325):
 for v in text.encode():seed=((seed^v)*0x100000001b3)&0xffffffffffffffff
 return seed
hashes={fnv(key):i for i,key in enumerate(keys)}
def hook(u,a,n,_):
 global spellCalls,readIndex
 if a in [m.stop,0x1404ec1b0,0x140782ed3,0x140785726]:u.emu_stop();return
 x,y,z,w=[u.reg_read(r)for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
 if a==0x1402db150:calls.append(['dword',y&0xffffffff,z]);m.finish()
 elif a==0x1404763e0:calls.append(['object',y&0xffffffff]);m.finish()
 elif a==0x1402da920:calls.append(['bool',y&0xffffffff]);m.finish()
 elif a==0x1402af4a0:
  calls.append(['spell',y&0xffffffff]);index=spellCalls;spellCalls+=1;m.finish((spell if c.get('spell',1)else 0)if index==0 else master if c.get('masterExists',1)else 0)
 elif a==0x1403fa4a0:calls.append(['class',y&255]) # Execute actual native GetClass.
 elif a==0x1402af530:
  kind='primary'if x==spell else'master';calls.append(['level',kind,y&255]);m.finish(255 if(y&255)==255 else c[kind])
 elif a==0x14040b900:calls.append(['feat',y&65535]);m.finish(c.get('featValue',1)if c['feats']&(1<<((y&65535)-860))else 0)
 elif a==0x1402ae870:
  partial=string(x);assert partial.startswith('PIC_');assert y==len(partial);assert z==fnv('E');m.finish(fnv(partial,z))
 elif a==0x1402a4130:
  index=hashes[y];assert z==[4,7,10][index];calls.append(['cap',keys[index],z]);m.finish(c['caps'][index])
 elif a==0x1402d9bc0:calls.append(['readDword',y]);m.finish(c['spellId'])
 elif a==0x1409737c0:calls.append(['readObject']);m.finish(c['itemId'])
 elif a==0x1402d9600:calls.append(['readBool']);m.finish(c['suppressed'])
 elif a==0x1402d9460:calls.append(['overflow']);m.finish(c['overflow'])
 elif not(0x1404ebfec<=a<0x1404ec1b0 or 0x140782e68<=a<0x140782ed3 or 0x1403fa4a0<=a<0x1403fa4c2):raise AssertionError(f'Unexpected cast-field lower {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,calls,spellCalls,readIndex
 c=case;calls=[];spellCalls=readIndex=0;u.mem_write(m.heap,bytes(0x20000));m.wq(0x1412df8f8,rules);m.wq(rules+0xd0,spell);m.wq(actor+0xad0,stats)
 m.wi(actor+0x218,c.get('spellId',37));m.wi(actor+0x818,0x7f000000);u.mem_write(actor+0x22c,bytes([c.get('classIndex',0)&255,c.get('meta',0)&255]));u.mem_write(stats+0xd8,bytes([2]));u.mem_write(stats+0x25c,bytes([10]));u.mem_write(stats+0x25c+0x188,bytes([11]));m.wi(spell+0x178,123);u.mem_write(spell+0x6f,bytes([c.get('innate',0)&255]));m.wi(actor+0x36c,100);m.wi(actor+0x370,200);m.wi(actor+0x374,-1)
 rsp=m.stack+0x1dd00;rbp=rsp+0x100;u.mem_write(rsp-0x100,bytes(0x300));m.wi(rbp-0x80,c.get('animation',15));m.wi(rsp+0x78,42);m.wi(rsp+0x44,0)
 for reg,v in [(UC_X86_REG_RSP,rsp),(UC_X86_REG_RBP,rbp),(UC_X86_REG_RDI,actor if c.get('object',1)else 0)]:u.reg_write(reg,v)
 if c['mode']=='send':
  u.reg_write(UC_X86_REG_RBX,c.get('animation',15));u.reg_write(UC_X86_REG_R15,message);entry=0x1404ebfec
 else:
  u.reg_write(UC_X86_REG_R12,c['animation']);u.reg_write(UC_X86_REG_R14,message);entry=0x140782e68
 try:u.emu_start(entry,m.stop,count=3000)
 except Exception:print(json.dumps(dict(case=c,rip=hex(u.reg_read(UC_X86_REG_RIP)),calls=calls)));raise
 return dict(case=c,calls=calls,state=dict(spellId=m.si(actor+0x36c),spellItemId=m.si(actor+0x370)&0xffffffff,suppressSound=m.si(actor+0x374)),exit=hex(u.reg_read(UC_X86_REG_RIP)))
rows=[]
levels=[(v,2)for v in [0,3,4,6,7,9,10]]+[(255,2),(255,255)]
for meta,feats,level,masterOk,index,innate,caps in itertools.product([0,16,17,255],range(8),levels,[0,1],[0,255],[0,5,255],[[4,7,10],[0,-1,3]]):rows.append(run(dict(mode='send',meta=meta,feats=feats,primary=level[0],master=level[1],masterExists=masterOk,classIndex=index,innate=innate,caps=caps)))
for meta in [0,16,255]:rows.append(run(dict(mode='send',spell=0,meta=meta,feats=7,primary=0,master=0,caps=[4,7,10])))
for animation,exists,overflow,suppressed,spellId,itemId in itertools.product([1,14,15,16,17,20,21,61,250,253,261,65551],[0,1],[0,1],[0,1],[37,0xffffffff],[0x7f000000,0x80000055]):rows.append(run(dict(mode='read',animation=animation,object=exists,overflow=overflow,suppressed=suppressed,spellId=spellId,itemId=itemId)))
out=m.root/'backups/animations/native-client-cast-field-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows))+'\n');print(json.dumps(dict(rows=len(rows),output=str(out))))
