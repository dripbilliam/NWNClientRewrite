"""Complete original GetCalendarYear/Month/Day script wrappers and their full
WorldTimer getters/normalization. Server timer lookup and VM integer push are
captured lower boundaries. Snapshot/counter origins and whole VM are separate.
"""
import importlib,sys,json,itertools,random
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
cmd,app,timer=[m.heap+i*0x1000 for i in range(1,4)]
ranges=[(0x14051fae0,0x14051fb1d),(0x14051fb20,0x14051fb5d),(0x14051fb60,0x14051fb9d),(0x140597230,0x14059729f),(0x140597360,0x14059738f),(0x140597500,0x140597535),(0x140597720,0x14059775a)]
def hook(u,a,n,_):
 global output
 if a==m.stop:u.emu_stop();return
 if a==0x14055ba10:transfers.append('timer');m.finish(timer);return
 if a==0x140286410:output=u.reg_read(UC_X86_REG_RDX)&0xffffffff;transfers.append('push');m.finish(c['push']);return
 if not any(lo<=a<hi for lo,hi in ranges):raise RuntimeError(f'Uncaptured calendar dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,output,transfers
 c=case;output=None;transfers=[];u.mem_write(m.heap,bytes(0x10000));u.mem_write(m.stack,bytes(0x20000));m.wq(0x1412df970,app);m.wq(app+8,app);m.wq(timer+8,int(c['counter']));m.wi(timer+0x18,c['paused']);m.wi(timer+0x1c,c['pausedDay']);m.wi(timer+0x24,c['dayOffset']);m.wi(timer+0x28,c['timeOffset']);m.wi(timer+0x30,c['dayLength'])
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,cmd);u.reg_write(UC_X86_REG_RDX,c['command']);u.reg_write(UC_X86_REG_R8,0)
 u.emu_start({13:0x14051fb60,14:0x14051fb20,15:0x14051fae0}[c['command']],m.stop,count=300000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=c,result=u.reg_read(UC_X86_REG_RAX)&0xffffffff,output=output,transfers=transfers)
if __name__=='__main__':
 rng=random.Random(20261017);states=[]
 for day,counter,paused in itertools.product([0,27,28,335,336,1340*336,32767*336+335,32768*336,0xffffffff],['0',str(2**64-1)],[0,1,2]):states.append(dict(counter=counter,dayOffset=day,timeOffset=0,dayLength=7200000,paused=paused,pausedDay=day))
 for _ in range(60):states.append(dict(counter=str(rng.randrange(2**64)),dayOffset=rng.randrange(2**32),timeOffset=rng.choice([0,1,7199999,7200000,0xffffffff]),dayLength=rng.choice([1440000,2880000,7200000,367200000]),paused=0,pausedDay=0))
 rows=[run(state|dict(command=command,push=push))for state,command,push in itertools.product(states,[13,14,15],[0,1])]
 out=m.root/'backups/animations/native-script-calendar-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2)+'\n');print(json.dumps(dict(output=str(out),rows=len(rows))))
