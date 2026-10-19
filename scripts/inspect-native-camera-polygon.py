"""Execute complete original polyhit231810..231a99 against synthetic polygon,
cached plane and finite segment inputs. No native function bodies replaced;
actual native output bits captured, no original assets or live process edits.
"""
import sys,importlib,itertools,json,struct,random
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
g=importlib.import_module('inspect-native-camera');w=g.w;m=g.m;u=g.u
from unicorn.x86_const import *
buf=m.heap+0x70000
def run(c):
 vertices=c['vertices'];normal=c['normal'];g.put(buf,sum(vertices,[]));g.put(buf+0x100,normal+[c['constant']]);g.put(buf+0x200,c['start']);g.put(buf+0x210,c['end']);g.put(buf+0x220,[-1234]*3)
 rsp=m.stack+0x1fe08;m.wq(rsp+0x28,buf+0x200);m.wq(rsp+0x30,buf+0x210);m.wq(rsp+0x38,buf+0x210 if c.get('alias') else buf+0x220)
 result=w.call(0x140231810,[buf,len(vertices),buf+0x100,buf+0x10c]);out=buf+0x210 if c.get('alias') else buf+0x220
 return dict(case=c,result=result,output=g.vec(out),bits=[f'{v:08x}'for v in struct.unpack('<III',u.mem_read(out,12))])
if __name__=='__main__':
 rows=[]
 for scale,x,y,z1,z2,alias in itertools.product([1,1e-5,1e5],[0,.25,.5,1,-1e-7,1.0000001],[-1e-7,0,.25,.5,1],[0,1,-1],[0,1,-1],[False,True]):
  rows.append(run(dict(vertices=[[0,0,0],[scale,0,0],[0,scale,0]],normal=[0,0,1],constant=0,start=[x*scale,y*scale,z1*scale],end=[x*scale,y*scale,z2*scale],alias=alias)))
 rng=random.Random(231810)
 for _ in range(256):
  vertices=[[rng.uniform(-10,10)for _ in range(3)]for _ in range(3)]
  # Execute the game's plane normal and constant too, not Python cross products.
  for i,v in enumerate(vertices):g.put(buf+i*12,v)
  w.call(0x14022d960,[buf+0x100,buf,buf+12,buf+24]);normal=g.vec(buf+0x100);a=[struct.unpack('<f',struct.pack('<f',v))[0]for v in vertices[0]];f=lambda v:struct.unpack('<f',struct.pack('<f',v))[0]
  constant=f(-f(f(f(a[1]*normal[1])+f(a[0]*normal[0]))+f(a[2]*normal[2])))
  rows.append(run(dict(vertices=vertices,normal=normal,constant=constant,start=[rng.uniform(-20,20)for _ in range(3)],end=[rng.uniform(-20,20)for _ in range(3)])))
 out=m.root/'backups/animations/native-camera-polygon-observations.json';out.write_text(json.dumps(dict(target=m.digest,limits=__doc__,rows=rows),indent=2)+'\n');print(json.dumps(dict(rows=len(rows),output=str(out))))
