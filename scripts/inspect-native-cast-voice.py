"""Original stats Gender read/clamp40fb64..40fb9b, appearance copy41203d..
412053, appearance BYTE writer4ea81c..4ea854, client read780543..780579,
successful model-field copy9744d0..974508, client race store785200..78520e,
whole cast driver8018d0 and empty-model conjure wrapper98b450 execute. GFF BYTE,
scalar wire fields, spell lookup, model/part/scene, strings/CRT and sound output
are captured lowers. Model success is an explicit lower fixture gate; not full
GFF/type conversion, packet/dirty-flag/appearance/model/renderer/audio parity.
"""
import importlib.util,itertools,json,struct
from pathlib import Path
spec=importlib.util.spec_from_file_location('fixture',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
stats,appearance,actor,clientStats,clientAppearance,packet,controller,spell,rules,vt,model=[m.heap+n*0x1000 for n in range(1,12)]
sourceFn,poseFn=m.stop+0x10,m.stop+0x20
ends=[0x14040fb9b,0x140412053,0x1404ea854,0x140780579,0x140974508,0x14078520e,m.stop]
ranges=[(0x14040fb64,0x14040fb9b),(0x14041203d,0x140412053),(0x1404ea81c,0x1404ea854),(0x140780543,0x140780579),(0x1409744d0,0x140974508),(0x140785200,0x14078520e),(0x1408018d0,0x140801c00),(0x14098b450,0x14098b9ba),(0x14098baa0,0x14098bb4b),(0x14098b9f0,0x14098ba9e),(0x14098bb50,0x14098bc97)]
def readbyte(a):return u.mem_read(a,1)[0]
def string(p):return bytes(u.mem_read(p,100)).split(b'\0')[0].decode('ascii')if p else''
def hook(u,a,n,_):
 global readIndex
 if a in ends:u.emu_stop();return
 x,y,z,w=[u.reg_read(r)for r in[UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
 if a==0x1401a0ee0:
  default=readbyte(rsp+0x28);assert string(z)=='Gender';gff.append(dict(default=default));m.finish((c['rawGender']&255)if c['present']else default)
 elif a==0x1402da960:assert z==8 and w==1;wire.append(y&255);m.finish()
 elif a==0x1402d9630:assert y==8 and z==1;value=wire[readIndex];readIndex+=1;m.finish(value)
 elif a==0x1402af4a0:assert y==37;m.finish(spell)
 elif a in[0x14018de80,0x14018ded0]:u.mem_write(x,bytes(u.mem_read(y,17)));m.finish(x)
 elif a==0x140c10370:m.finish()
 elif a==0x140c10410:m.finish(u.reg_read(UC_X86_REG_RAX))
 elif a==sourceFn:m.finish(model if c['model']else 0)
 elif a==poseFn:
  assert string(y)=='handconjure'
  for i,v in enumerate([7,8,9]):m.wf(z+i*4,v)
  m.finish(1)
 elif a==0x1401d9c40:
  sounds.append(dict(resource=string(y),position=[m.rf(z+i*4)for i in range(3)],gain=u.reg_read(UC_X86_REG_XMM3)&0xffffffff,priority=readbyte(rsp+0x28)));m.finish()
 elif not any(lo<=a<hi for lo,hi in ranges):raise AssertionError(f'Unexpected chant lower {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def regs(**values):
 for key,value in values.items():u.reg_write(globals()['UC_X86_REG_'+key],value)
def segment(start,end):
 u.emu_start(start,m.stop,count=5000);assert u.reg_read(UC_X86_REG_RIP)==end
def run(case):
 global c,wire,sounds,gff,readIndex
 c=case;wire=[];sounds=[];gff=[];readIndex=0;u.mem_write(m.heap,bytes(0x20000));rsp=m.stack+0x1dd00;rbp=rsp+0x100;u.mem_write(rsp-0x100,bytes(0x1000));u.mem_write(stats+0xa4,bytes([c['current']]));u.mem_write(stats+0xdee,bytes([c['phenotype']]));regs(RSP=rsp,RBP=rbp,R14=stats,RSI=0,R12=0)
 segment(0x14040fb64,0x14040fb9b);imported=readbyte(stats+0xa4)
 regs(RCX=appearance);segment(0x14041203d,0x140412053)
 regs(R12=6,RDI=appearance,RBX=packet);segment(0x1404ea81c,0x1404ea854)
 u.mem_write(rbp+0x220,bytes([255,0]));regs(RDI=1,RSI=6,R12=packet);segment(0x140780543,0x140780579)
 # The local incoming POD D0/D1 values have now been read. Model creation
 # success controls whether the original copy block installs them in live data.
 incoming=readbyte(rbp+0x220);u.mem_write(clientAppearance+0xd0,bytes([255,0]));incomingPOD=m.heap+0x10000;u.mem_write(incomingPOD+0xd0,bytes([incoming,readbyte(rbp+0x221)]))
 if c['model']:regs(R15=incomingPOD,RSI=clientAppearance);segment(0x1409744d0,0x140974508)
 m.wq(rbp-0x50,clientStats);m.wi(rsp+0x64,c['race']);segment(0x140785200,0x14078520e)
 u.mem_write(actor+0x5c,struct.pack('<H',15));m.wi(actor+0x36c,37);m.wi(actor+0x374,c['suppressed']);m.wq(actor+0x3b0,clientStats);m.wq(actor+0x300,clientAppearance);m.wq(actor+0x3a0,controller);m.wq(actor,vt);m.wq(model,vt);m.wq(vt+0x140,sourceFn);m.wq(vt+0x138,poseFn)
 for i,v in enumerate([1,2,3]):m.wf(actor+0x38+i*4,v)
 for off,text in zip([0xa9,0xba,0xcb],['male','female','generic']):u.mem_write(spell+off,text.encode()+b'\0')
 m.wq(0x1412df8f8,rules);m.wq(rules+0xd0,spell)
 callrsp=m.stack+0x1ee08;u.mem_write(callrsp-0x400,bytes(0x500));m.wq(callrsp,m.stop);regs(RSP=callrsp,RCX=actor);segment(0x1408018d0,m.stop)
 return dict(case=c,importedGender=imported,appearanceGender=readbyte(appearance+0x17),appearancePhenotype=readbyte(appearance+0x16),wire=wire,incomingGender=incoming,clientGender=readbyte(clientAppearance+0xd0),clientPhenotype=readbyte(clientAppearance+0xd1),clientRace=struct.unpack('<h',u.mem_read(clientStats+0x50,2))[0],sounds=sounds,gff=gff)
rows=[run(dict(present=1,rawGender=gender,current=0,phenotype=2,race=race,model=model,suppressed=suppressed))for gender,race,model,suppressed in itertools.product(range(256),[0,6,7,65535,32768],[0,1],[0,1])]
rows += [run(dict(present=0,rawGender=0,current=current,phenotype=255,race=race,model=1,suppressed=0))for current,race in itertools.product([0,1,255],[6,7])]
out=m.root/'backups/animations/native-cast-voice-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows))+'\n');print(json.dumps(dict(rows=len(rows),output=str(out))))
