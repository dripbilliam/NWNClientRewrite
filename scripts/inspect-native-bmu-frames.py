"""Whole original MPEG iterator6a4430 and ProcessFrame6a3b00 sample-count
owner. Synthetic frame bodies; side/main-info validation and PCM decode are
captured successful/failed services. This does not verify codec PCM equivalence.
"""
import importlib.util,itertools,json,struct
from pathlib import Path
spec=importlib.util.spec_from_file_location('fixture',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle);iterator,frame,payload,decoder=[m.heap+n*0x1000 for n in [1,2,3,16]]
def dossier(name):return json.loads((m.root/'backups/animations'/name).read_text())['structuredContent']['raw_result']['value']
d=dossier('rea-creature-mp3-process-current.json');dependencies={x['name']:int(x['address'],16)for x in d['callees']}
def hook(u,a,n,_):
 if a==m.stop:u.emu_stop();return
 if a==dependencies['OpenMP3_Decoder::Private_ReadSideInfo']:m.finish(int(not case.get('sideFailure')));return
 if a==dependencies['OpenMP3_Decoder::Private_ReadMain']:m.finish(int(not case.get('mainFailure')));return
 if a==dependencies['OpenMP3_Decoder::Private_DecodeFrame']:m.finish();return
 assert 0x1406a4430<=a<0x1406a46b0 or 0x1406a46b0<=a<0x1406a46d0 or 0x1406a3b00<=a<0x1406a3b90,f'Unexpected MPEG dependency {a:x}'
u.hook_add(UC_HOOK_CODE,hook)
def call(address,x,y=0,z=0):
 sp=m.stack+0x1fe08;m.wq(sp,m.stop);u.reg_write(UC_X86_REG_RSP,sp)
 for r,v in [(UC_X86_REG_RCX,x),(UC_X86_REG_RDX,y),(UC_X86_REG_R8,z)]:u.reg_write(r,v)
 u.emu_start(address,m.stop+1,count=100000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return u.reg_read(UC_X86_REG_RAX)&0xffffffff
rates=list(struct.unpack('<6I',u.mem_read(0x140e26dd8,24)));bitrates=list(struct.unpack('<30I',u.mem_read(0x140e26d60,120)))
def image(c):
 low=c['version']==2;size=bitrates[int(low)*15+c['bitrate']]*(72 if low else 144)//rates[int(low)*3+c['frequency']]+c.get('padding',0)
 header=0xffe00000|(c['version']<<19)|(1<<17)|((not c['crc'])<<16)|(c['bitrate']<<12)|(c['frequency']<<10)|(c.get('padding',0)<<9)|(c['mode']<<6)
 parts=[]
 for i in range(2):
  b=bytearray(size);b[:4]=struct.pack('>I',header)
  if i==0 and c['info']:
   offset=4+(2 if c['crc']else 0)+(9 if low and c['mode']==3 else 17 if low or c['mode']==3 else 32);b[offset:offset+4]=b'Info'
  parts.append(b)
 b=bytearray(b'ID3\x00\x00\x00\x00'+b''.join(parts))
 if c.get('truncate'):b=b[:-c['truncate']]
 return b
rows=[]
cases=[dict(version=v,bitrate=b,frequency=f,mode=mo,crc=cr,info=i,padding=pa)for v,b,f,mo,cr,i,pa in itertools.product([2,3],[1,9,14],[0,1,2],[0,3],[False,True],[False,True],[0,1])]
cases += [cases[0]|dict(sideFailure=True),cases[0]|dict(mainFailure=True)] +[cases[0]|dict(truncate=n)for n in [1,4,25,100]]
for case in cases:
 data=image(case);u.mem_write(iterator,bytes(0x40));m.wq(iterator+8,payload);m.wq(iterator+0x10,payload+len(data));u.mem_write(iterator+0x18,b'\x01');u.mem_write(payload,bytes(data)+bytes(256));frames=[]
 while call(0x1406a4430,iterator,frame)&255:
  raw=bytes(u.mem_read(frame,32));low=bool(raw[1]);mode=m.si(frame+4);count=call(0x1406a3b00,decoder,frame,decoder+0x8000);frames.append(dict(offset=m.q(frame+0x10)-payload,payloadSize=m.si(frame+0x18),low=low,mode=mode,sampleRate=call(0x1406a46b0,frame),samples=count))
  assert len(frames)<=2
 rows.append(dict(case=case,frames=frames))
out=m.root/'backups/animations/native-bmu-frame-observations.json';out.write_text(json.dumps(dict(target=m.digest,limits=__doc__,cases=rows),indent=2)+'\n');print(json.dumps(dict(cases=len(rows),output=str(out))))
