"""Original 6e90e0 hot-mode +6e9590 timer/string execution in isolated Unicorn.

The original mode owner, CExoString concat/InitFromCharArray, popup setter,
6f9fa0 font-refresh and 1fd5b0 SetFont execute unchanged. Alloc/free/memcpy,
authored caption line providers, model/panel/font lower callbacks are captured.
No native font wrapping, scene mutation, rendering, process, profile or network.
Every untraced instruction dependency fails; no allocator failures are simulated.
"""
from pathlib import Path
import argparse, hashlib, json, struct, sys, time

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'backups/research-python'))
import pefile
from unicorn import Uc, UC_ARCH_X86, UC_MODE_64, UC_HOOK_CODE
from unicorn.x86_const import *

PIN = '3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a'
SOURCE = ROOT.parent / 'FullDecomp/NwnRootInstall/bin/win32/nwmain.exe'
FIXTURE = ROOT / 'godot-client/tests/fixtures/native-overhead-mode-change-v1.json'
REPORTS = [ROOT / 'godot-client/reports' / n for n in [
    'native-overhead-options-owner-v1.json', 'native-overhead-chat-original-v2.json',
    'native-overhead-popup-layout-policy-v1.json', 'native-overhead-popup-registry-lifetime-v1.json']]
ENTRIES = {'mode':0x1406e90e0, 'setter':0x1406e9590,
           'concat':0x14016ab00, 'init':0x14003d8c0,
           'font':0x1406f9fa0, 'bubbleFont':0x1401fd5b0}
HEAP, STACK, STOP = 0x200000000, 0x300000000, 0x400000000

def sha(data): return hashlib.sha256(data).hexdigest()
def f32(v): return struct.unpack('<f',struct.pack('<f',v))[0]
def fbits(v): return struct.pack('<f',v).hex()

class Oracle:
    def __init__(self):
        raw=SOURCE.read_bytes(); assert sha(raw)==PIN
        self.pe=pefile.PE(data=raw); self.base=self.pe.OPTIONAL_HEADER.ImageBase
        self.u=Uc(UC_ARCH_X86,UC_MODE_64)
        self.u.mem_map(self.base,(self.pe.OPTIONAL_HEADER.SizeOfImage+4095)&~4095)
        self.u.mem_write(self.base,self.pe.get_memory_mapped_image())
        self.u.mem_map(HEAP,0x100000);self.u.mem_map(STACK,0x20000);self.u.mem_map(STOP,0x1000)
        self.ranges={}
        for name,entry in ENTRIES.items():
            matches=[r.struct for r in self.pe.DIRECTORY_ENTRY_EXCEPTION if self.base+r.struct.BeginAddress==entry]
            assert len(matches)==1,(name,hex(entry),matches)
            r=matches[0];self.ranges[name]=(self.base+r.BeginAddress,self.base+r.EndAddress)
        # PE unwind entries split InitFromCharArray's empty-string branch at
        # 3d987. Fresh complete original assembly ends at RET3d9aa; include it.
        self.ranges['init']=(0x14003d8c0,0x14003d9ab)
        # Retained whole 6f9fa0 assembly has the shared return at6fa12f..135.
        self.ranges['font']=(0x1406f9fa0,0x1406fa136)
        self.u.hook_add(UC_HOOK_CODE,self.hook)
        self.instructions={};self.trace=[];self.callbacks={}
    def q(self,p):return int.from_bytes(self.u.mem_read(p,8),'little')
    def i(self,p):return int.from_bytes(self.u.mem_read(p,4),'little')
    def rf(self,p):return struct.unpack('<f',self.u.mem_read(p,4))[0]
    def wq(self,p,v):self.u.mem_write(p,struct.pack('<Q',v))
    def wi(self,p,v):self.u.mem_write(p,struct.pack('<I',v&0xffffffff))
    def wf(self,p,v):self.u.mem_write(p,struct.pack('<f',v))
    def xmm(self,reg):return struct.unpack('<f',struct.pack('<I',self.u.reg_read(reg)&0xffffffff))[0]
    def string(self,p):
        if not p:return b''
        out=bytearray()
        for n in range(32768):
            b=self.u.mem_read(p+n,1)[0]
            if b==0:return bytes(out)
            out.append(b)
        raise AssertionError('Unterminated boundary string')
    def alloc(self,n):
        assert 0<=n<32768,n
        p=self.next_alloc;self.next_alloc+=(max(n,1)+15)&~15
        assert self.next_alloc<HEAP+0xf0000
        self.u.mem_write(p,bytes(max(n,1)));return p
    def finish(self,v=0):
        sp=self.u.reg_read(UC_X86_REG_RSP)
        self.u.reg_write(UC_X86_REG_RIP,self.q(sp));self.u.reg_write(UC_X86_REG_RSP,sp+8)
        self.u.reg_write(UC_X86_REG_RAX,v&0xffffffffffffffff)
    def object_index(self,p):
        assert p in self.objects,hex(p)
        return self.objects.index(p)
    def event(self,name,**extra):self.trace.append(dict(event=name,**extra))
    def hook(self,u,at,size,_):
        if at==STOP:u.emu_stop();return
        x,y,z,w=[u.reg_read(r)for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
        sp=u.reg_read(UC_X86_REG_RSP)
        if at==0x140c10368:self.finish(self.alloc(x));return
        if at==0x140c10370:self.finish();return
        if at==0x140c417f0:
            assert z<32768
            if z:u.mem_write(x,bytes(u.mem_read(y,z)))
            self.finish(x);return
        if at==STOP+0x10:
            index=self.captions[x];self.event('line-count',index=index,count=len(self.lines[index]));self.finish(len(self.lines[index]));return
        if at==STOP+0x20:
            index=self.captions[x];assert y<len(self.lines[index])
            self.event('line',index=index,line=y);self.finish(self.lines[index][y]);return
        if at==ENTRIES['setter']:
            index=self.object_index(x);length=self.i(y+8);pointer=self.q(y)
            self.event('setter',index=index,bytes=bytes(u.mem_read(pointer,length)).hex()if pointer else '',length=length,
                       minimum=self.xmm(UC_X86_REG_XMM2),maximum=self.xmm(UC_X86_REG_XMM3),scale=self.rf(sp+0x28),forced=self.rf(sp+0x30),
                       before=self.fields(x))
        elif at==0x1401fd690:
            self.event('set-text',index=self.object_index(x),bytes=self.string(y).hex());self.finish();return
        elif at==0x1401fd480:
            self.event('fix-alignment',index=self.object_index(x),xy=[self.xmm(UC_X86_REG_XMM1),self.xmm(UC_X86_REG_XMM2)]);self.finish();return
        elif at in [0x1401fc470,0x1401fbe70,0x1401fc940,0x1401fd080,0x1401fb230]:
            names={0x1401fc470:'deactivate',0x1401fbe70:'activate',0x1401fc940:'scene-first',0x1401fd080:'toggle-off',0x1401fb230:'ignore-hit'}
            self.event(names[at],index=self.object_index(x));self.finish();return
        elif at==0x1401fafa0:
            self.event('portrait-attach',index=self.object_index(y),hook=self.string(z).decode('ascii'));self.finish();return
        elif at==STOP+0x30:
            index=self.scenes[x];target=y
            for n,v in enumerate([1.25,-2.5,-5]):self.wf(target+n*4,v)
            self.event('get-position',index=index);self.finish(target);return
        elif at==STOP+0x40:
            self.event('set-position',index=self.scenes[x],xyz=[self.rf(z+n*4)for n in range(3)]);self.finish(y);return
        elif at==STOP+0x50:
            self.event('caption-attach',index=self.captions[x],hook=self.string(z).decode('ascii'));self.finish();return
        elif at==STOP+0x60:
            self.event('caption-align',index=self.captions[x],value=self.xmm(UC_X86_REG_XMM1));self.finish();return
        elif at==0x14019a530:
            self.event('font-remap',requested=self.string(y).hex());self.finish(self.remapped_font);return
        elif at==STOP+0x70:
            self.event('caption-font',index=self.captions[x],font=self.string(y).hex());self.finish();return
        elif at in [0x1406e27c0,0x1401f0990,0x140879980,0x14087a0e0,0x1401fb540,0x14086b8e0,0x140853fb0]:
            self.event('other-font-owner',procedure=hex(at));self.finish();return
        if not any(lo<=at<hi for lo,hi in self.ranges.values()):raise AssertionError('Untraced original dependency '+hex(at))
        self.instructions[hex(at)]=self.instructions.get(hex(at),0)+1
    def fields(self,obj):
        return {name:self.i(obj+offset)for name,offset in [('activeBits',0xb0),('sizeChoice',0x110),('full',0x114),('elapsedBits',0x128),('durationBits',0x12c),('timed',0x144),('off',0x148),('minimumLines',0x10c),('indentBits',0x108)]}
    def reset(self,rows,old_mode):
        self.u.mem_write(HEAP,bytes(0x100000));self.u.mem_write(STACK,bytes(0x20000))
        self.trace=[];self.next_alloc=HEAP+0x80000;self.objects=[];self.captions={};self.scenes={};self.lines=[]
        self.u.mem_write(0x14141e310,b'\0')
        self.wi(0x141296de8,old_mode);self.wq(0x1414232f0,HEAP+0x1000);self.wi(0x1414232f8,len(rows))
        caption_vt,scene_vt=HEAP+0x4000,HEAP+0x5000
        for offset,value in [(0xe8,STOP+0x10),(0xe0,STOP+0x20),(8,STOP+0x50),(0x68,STOP+0x60),(0x50,STOP+0x70)]:self.wq(caption_vt+offset,value)
        self.wq(scene_vt+0xc0,STOP+0x30);self.wq(scene_vt+0xb0,STOP+0x40)
        for index,row in enumerate(rows):
            obj,caption,scene=HEAP+0x10000+index*0x1000,HEAP+0x20000+index*0x1000,HEAP+0x30000+index*0x1000
            self.objects.append(obj);self.captions[caption]=index;self.scenes[scene]=index
            self.wq(HEAP+0x1000+index*8,obj);self.wq(obj+0xf0,caption);self.wq(caption,caption_vt);self.wq(scene,scene_vt);self.wq(obj+0x10,scene)
            self.wq(obj+0xa0,scene if row['active'] else 0);self.wi(obj+0xb0,row.get('activeBits',1 if row['active'] else 0))
            for offset,value in [(0x110,7),(0x114,int(old_mode==2)),(0x144,row['timed']),(0x148,int(old_mode==0)),(0x10c,9)]:self.wi(obj+offset,value)
            self.wf(obj+0x128,.625);self.wf(obj+0x12c,9.25)
            self.wq(obj+0x118,HEAP+0x60000+index*0x100 if row.get('portrait') else 0)
            pointers=[]
            for line in row['lines']:
                if line is None:pointers.append(0);continue
                data=bytes.fromhex(line);p=self.alloc(len(data)+1);self.u.mem_write(p,data+b'\0');pointers.append(p)
            self.lines.append(pointers)
        # Only traced font-owner lower callbacks consume these explicit objects.
        app,client,gui=HEAP+0x65000,HEAP+0x66000,HEAP+0x67000
        self.wq(0x1412df970,app);self.wq(app,client);self.wq(client+8,HEAP+0x68000)
        for offset in [8,0x10,0x18,0x58,0x60]:self.wq(gui+offset,HEAP+0x69000+offset*0x100)
        self.font_owner=gui;self.remapped_font=self.alloc(64);self.requested_font=self.alloc(64)
        self.u.mem_write(self.requested_font,b'fixture dialog font\0');self.u.mem_write(self.remapped_font,b'fixture remapped font\0')
        self.wq(0x14140c920,self.requested_font)
        return [self.fields(o)for o in self.objects]
    def run(self,entry,args):
        sp=STACK+0x1fe08;self.wq(sp,STOP);self.u.reg_write(UC_X86_REG_RSP,sp)
        for reg,v in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],args):self.u.reg_write(reg,v)
        for reg in [UC_X86_REG_XMM0,UC_X86_REG_XMM1,UC_X86_REG_XMM2,UC_X86_REG_XMM3,UC_X86_REG_XMM6,UC_X86_REG_XMM7,UC_X86_REG_XMM8,UC_X86_REG_XMM9]:self.u.reg_write(reg,0)
        self.u.emu_start(entry,STOP,count=250000)
        assert self.u.reg_read(UC_X86_REG_RIP)==STOP,'Instruction ceiling exceeded'
    def registry(self):return [self.q(self.q(0x1414232f0)+i*8)for i in range(self.i(0x1414232f8))]

def expected_bytes(row):return b''.join(bytes.fromhex(s).split(b'\0',1)[0]for s in row['lines']if s)

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--report',required=True);args=parser.parse_args()
    out=Path(args.report).resolve();assert out.is_relative_to(ROOT)and not out.exists(),'NEW workspace report only'
    inputs={str(p.relative_to(ROOT)):sha(p.read_bytes())for p in [Path(__file__),FIXTURE,*REPORTS]}
    started=time.monotonic();oracle=Oracle();fixtures=json.loads(FIXTURE.read_text())['fixtures'];cases=[];fonts=[]
    try:
        for fixture_index,fixture in enumerate(fixtures):
            for old,new in [(0,1),(0,2),(1,0),(1,2),(2,0),(2,1),(2,2)]:
                row=dict(lines=fixture['lines'],active=bool(fixture_index%2),timed=fixture_index%3,portrait=bool(fixture_index%3==1),activeBits=5 if fixture_index%4==3 else fixture_index%2)
                rows=[row];before=oracle.reset(rows,old);registry=oracle.registry();oracle.run(ENTRIES['mode'],[new]);after=[oracle.fields(o)for o in oracle.objects]
                setter=[e for e in oracle.trace if e['event']=='setter']
                assert oracle.registry()==registry
                if old==new:assert not oracle.trace and before==after
                else:
                    text=expected_bytes(row);assert len(setter)==1 and setter[0]['bytes']==text.hex()
                    assert [setter[0][k]for k in ['minimum','maximum','scale','forced']]==[4,12,1,0]
                    duration=max(4,min(12,f32(f32(len(text)) * f32(.15))))
                    assert after[0]['durationBits']==struct.unpack('<I',struct.pack('<f',duration))[0]
                    assert after[0]['elapsedBits']==0 and after[0]['timed']==row['timed'] and after[0]['sizeChoice']==0xffffffff
                    assert after[0]['full']==int(new==2)and after[0]['off']==int(new==0)
                    assert [e['event']for e in oracle.trace if e['event']in ['deactivate','activate','scene-first']]==(['deactivate']+([]if new==0 else ['activate','scene-first'])if row['active']else [])
                cases.append(dict(name=fixture['name'],oldMode=old,newMode=new,rows=rows,before=before,after=after,trace=oracle.trace,registryUnchanged=True))
        # One heterogeneous registry proves iteration order and inactive/hover inclusion.
        for new in [0,1,2]:
            old=(new+1)%3;rows=[dict(lines=fixtures[i]['lines'],active=bool(i%2),timed=i%2,portrait=bool(i==1))for i in [2,5,8]]
            before=oracle.reset(rows,old);registry=oracle.registry();oracle.run(ENTRIES['mode'],[new])
            assert oracle.registry()==registry
            assert [e['index']for e in oracle.trace if e['event']=='setter']==[0,1,2]
            cases.append(dict(name='mixed-registry',oldMode=old,newMode=new,rows=rows,before=before,after=[oracle.fields(o)for o in oracle.objects],trace=oracle.trace,registryUnchanged=True))
        for active in [0,1]:
            for mode in [0,1,2]:
                for font in ['ttf fnt_default 14','ttf fnt_default_hr 16']:
                    rows=[dict(lines=['48656c6c6f'],active=bool(i%2),timed=i%3)for i in range(3)]
                    before=oracle.reset(rows,mode);registry=oracle.registry();oracle.wi(oracle.font_owner+0x28,active)
                    requested=b'fixture logical '+font.encode('ascii');mapped=font.encode('ascii')
                    oracle.u.mem_write(oracle.requested_font,requested+b'\0');oracle.u.mem_write(oracle.remapped_font,mapped+b'\0')
                    oracle.run(ENTRIES['font'],[oracle.font_owner])
                    after=[oracle.fields(o)for o in oracle.objects]
                    assert before==after and oracle.registry()==registry
                    assert [e['index']for e in oracle.trace if e['event']=='caption-font']==([0,1,2]if active else [])
                    assert all(e['requested']==requested.hex()for e in oracle.trace if e['event']=='font-remap')
                    assert all(e['font']==mapped.hex()for e in oracle.trace if e['event']=='caption-font')
                    assert not any(e['event']=='setter'for e in oracle.trace)
                    fonts.append(dict(guiInitialized=active,mode=mode,requestedFont=requested.hex(),remappedFont=mapped.hex(),before=before,after=after,trace=oracle.trace,registryUnchanged=True))
        result=dict(success=True,schema='native-overhead-mode-change-original-v1',binarySha256=PIN,scope=__doc__,cases=cases,fontCases=fonts,
                    executedRanges={k:dict(start=hex(lo),endExclusive=hex(hi),sha256=sha(oracle.pe.get_data(lo-oracle.base,hi-lo)))for k,(lo,hi)in oracle.ranges.items()},
                    originalInstructions=sum(oracle.instructions.values()),originalInstructionAddresses=len(oracle.instructions),inputHashes=inputs,
                    lowerCallbacksCaptured=True,enginesRun=0,networkConnections=0,liveProcessAccess=False,productionChanged=False)
    except Exception as error:
        result=dict(success=False,schema='native-overhead-mode-change-original-v1',binarySha256=PIN,scope=__doc__,error=str(error),rip=hex(oracle.u.reg_read(UC_X86_REG_RIP)),trace=oracle.trace,cases=cases,fontCases=fonts,inputHashes=inputs)
    result['elapsedSeconds']=time.monotonic()-started
    assert sha(SOURCE.read_bytes())==PIN
    assert all(sha((ROOT/p).read_bytes())==h for p,h in inputs.items())
    out.parent.mkdir(parents=True,exist_ok=True);out.write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(dict(success=result['success'],cases=len(cases),fontCases=len(fonts),report=str(out),sha256=sha(out.read_bytes()),error=result.get('error'))))
    return 0 if result['success']else 1

if __name__=='__main__':raise SystemExit(main())
