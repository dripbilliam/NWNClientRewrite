"""Full original SpeakStrRef wrapper, action33 (profiling disabled), radius/
shout recipient coordinator and protected packet coordinator. VM, object/area/
player lookup, activity mutations, AddAction, scalar message writers and transport
are captured lower boundaries. Native distance math/control flow executes; this
does not prove activity effects, packet scalar codec, network broadcast, client
TLK/audio/overhead presentation or whole VM behavior.
"""
import importlib,sys,json,itertools
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
cmd,actor,app,table,players,array,client0,client1,viewer0,viewer1,node,payload=[m.heap+i*0x1000 for i in range(1,13)]
asObject,asCreature=m.stop+0x80,m.stop+0x90
ranges=[(0x140546970,0x140546bc9),(0x1404a70e0,0x1404a784d),(0x1404d3320,0x1404d35a0),(0x1404d4660,0x1404d46fe)]
def hook(u,a,n,_):
 global pops,calls,casts
 if a==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(r)for r in[UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
 if a==0x140286110:m.wi(y,c['strRef']if pops==0 else c['volume']);m.finish(c['pop1'if pops==0 else'pop2']);pops+=1;return
 if a==0x14055b850:m.finish(app);return
 if a==0x140296470:m.wq(z,actor);m.finish(c['status']);return
 if a==asObject:casts+=1;m.finish(actor if c['object']else 0);return
 if a==asCreature:casts+=1;m.finish(actor if c['creature']else 0);return
 if a==0x14048cb80:
  calls.append(['add',y,z,w,m.si(m.q(rsp+0x28)),m.si(rsp+0x30),m.si(m.q(rsp+0x38))]);m.finish();return
 if a==0x14055b810:m.finish(app);return
 if a==0x1404d3320 and c['mode']!='sender':calls.append(['send',y&255,z&0xffffffff,w&0xffffffff]);m.finish(c['sendResult']);return
 if a==0x14037cc30:calls.append(['activityManager',y&0xffffffff]);m.finish();return
 if a==0x1403a2650:calls.append(['activity',y&0xffffffff,z&0xffffffff]);m.finish();return
 if a==0x140494e80:m.finish(0 if c['nullArea']else app if x==actor or c['sameArea']else app+0x100);return
 if a==0x14055b8e0:m.finish(players);return
 if a==0x1404ba840:m.finish(0 if c['missingViewer']else viewer0 if x==client0 else viewer1);return
 if a==0x1404d4660 and c['mode']!='packet':
  calls.append(['packet',y&0xffffffff,z&0xffffffff,w&255,m.si(rsp+0x28)&0xffffffff]);m.finish(c['sendResult']if len(calls)==1 else c['sendResult2']);return
 if a==0x1402d54a0:calls.append(['create',y&0xffffffff,z&0xffffffff,w&0xffffffff]);m.finish();return
 if a==0x1404763e0:calls.append(['object',y&0xffffffff]);m.finish();return
 if a==0x1402db150:calls.append(['dword',y&0xffffffff,z&0xffffffff]);m.finish();return
 if a==0x1402d5880:m.wq(y,payload);m.wi(z,17);m.finish(c['payloadStatus']);return
 if a==0x1404dc490:calls.append(['transport',y&0xffffffff,z&255,w&255,m.si(rsp+0x30)]);m.finish(c['sendResult']);return
 if a==0x140c10410:m.finish(u.reg_read(UC_X86_REG_RAX));return
 if not any(lo<=a<hi for lo,hi in ranges):raise RuntimeError(f'Uncaptured speech owner{a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,pops,calls,casts
 c=case;pops=0;calls=[];casts=0;m.wq(0x1412df970,app);m.wq(app+8,app);m.wq(actor,table);m.wq(table+0x20,asObject);m.wq(table+0x60,asCreature);m.wi(actor+8,42);m.wi(actor+0xec,c['commandable']);m.wi(cmd+8,c['active']);m.wi(cmd+12,42);u.mem_write(0x14141e310,b'\0');m.wq(players,array);m.wi(players+8,c['count']);m.wq(array,client0);m.wq(array+8,client1);m.wi(client0+0x48,100);m.wi(client1+0x48,101)
 for pointer,point in[(actor,[0,0,0]),(viewer0,c['point']),(viewer1,c['point'])]:
  for i,v in enumerate(point):m.wf(pointer+0xa4+4*i,v)
 m.wi(node+0x38,c['strRef']);m.wi(node+0x40,c['channel']);rsp=m.stack+0x1fe08;u.mem_write(rsp-0x200,bytes(0x280));m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 start={'script':0x140546970,'action':0x1404a70e0,'sender':0x1404d3320,'packet':0x1404d4660}[c['mode']]
 regs=[cmd,c['command'],2,0]if c['mode']=='script'else[actor,node,0,0]if c['mode']=='action'else[app,c['channel'],42,c['strRef']]if c['mode']=='sender'else[app,100,42,c['channel']]
 for r,v in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],regs):u.reg_write(r,v&0xffffffffffffffff)
 if c['mode']=='packet':m.wi(rsp+0x28,c['strRef'])
 u.emu_start(start,m.stop,count=10000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=c,result=u.reg_read(UC_X86_REG_RAX)&0xffffffff,calls=calls,casts=casts)
if __name__=='__main__':
 d=dict(mode='script',command=691,strRef=12345,volume=0,channel=8,active=1,status=0,object=True,creature=True,commandable=1,pop1=1,pop2=1,sendResult=1,sendResult2=1,point=[0,0,0],count=2,sameArea=True,nullArea=False,missingViewer=False,payloadStatus=1)
 rows=[run(d|dict(command=command,strRef=ref,volume=volume,active=active,status=status,object=object,commandable=allowed))for command,ref,volume,active,status,object,allowed in itertools.product([240,691],[0x24,0xcf90,0x9e33,0xbe3,0xbd8,12345,0xffffffff],[-1,0,1,2,3],[0,1],[0,1,256],[False,True],[0,2])]
 rows +=[run(d|dict(pop1=a,pop2=b))for a,b in itertools.product([0,1],repeat=2)]
 rows +=[run(d|dict(mode='action',creature=creature,sendResult=result,channel=channel))for creature,result,channel in itertools.product([False,True],[0,1],[8,9,10,266])]
 rows +=[run(d|dict(mode='sender',channel=ch,point=point,sameArea=same,nullArea=null,missingViewer=missing,sendResult=result,sendResult2=result2,status=status))for ch,point,same,null,missing,result,result2,status in itertools.product([7,8,9,10,264],[[0,0,0],[3,0,0],[3.00001,0,0],[20,0,0],[20.00001,0,0],[0,0,20],[12,16,0]],[False,True],[False,True],[False,True],[0,1,2],[0,1],[0,1])]
 rows +=[run(d|dict(mode='packet',channel=ch,payloadStatus=status,sendResult=result))for ch,status,result in itertools.product([8,9,10,266],[0,1],[0,1,2])]
 out=m.root/'backups/animations/native-speech-strref-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2)+'\n');print(json.dumps(dict(output=str(out),rows=len(rows))))
