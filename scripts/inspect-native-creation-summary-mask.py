"""Original live-draft Character SetData entry through the mask/header/ability/
HP/AC region, stopping at provider-confirmed instruction1409b72a5. The complete
88b180 title routine also executes. This is not the complete Character routine.
String allocation/formatting, GUI text, race/class/alignment/name/TLK queries,
ability modifiers and HP/AC getters are explicit lower providers. No live game,
GPU, packet or character saving is involved.
"""
from pathlib import Path
import importlib.util, itertools, json, re, struct
root=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('pinned_image',root/'scripts/inspect-native-intratile-coordinator.py')
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
u=m.u;u.hook_del(m.hook_handle)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
page,creature,stats,sheet,tlk,vtable=[m.heap+n*0x4000 for n in range(6)]
offsets=[0x188]+[0x220+n*0x98 for n in range(14)]+[0x988]
def byte(a,v):u.mem_write(a,bytes([v&255]))
def word(a,v):u.mem_write(a,struct.pack('<H',v&65535))
def string(a):
    result=bytearray()
    if a:
        for i in range(8192):
            value=bytes(u.mem_read(a+i,1))
            if value==b'\0':break
            result+=value
    return bytes(result).decode('cp1252')
def descriptor(a,value):
    global allocation
    data=value.encode('cp1252')+b'\0';pointer=m.heap+0x30000+allocation;allocation+=len(data)+16
    u.mem_write(pointer,data);m.wq(a,pointer);m.wi(a+8,len(data)-1);m.wi(a+12,len(data))
    return a
def object_string(value):
    global allocation
    dest=m.heap+0x30000+allocation;allocation+=16
    return descriptor(dest,value)
def signed(value):return struct.unpack('<i',struct.pack('<I',value&0xffffffff))[0]
def text(widget,value):output[hex(widget_offsets[widget])]=value
def hook(_u,a,_size,_data):
    if a in [m.stop,0x1409b72a5]:u.emu_stop();return
    x,y,z,w=[u.reg_read(r) for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
    rsp=u.reg_read(UC_X86_REG_RSP)
    if a==0x140c113c0:m.finish(u.reg_read(UC_X86_REG_RAX))
    elif a==0x140800c90:m.finish(creature)
    elif a==0x140c10370:m.finish()
    elif a==0x1407f67c0:descriptor(y,case['race']);m.finish(y)
    elif a==0x1407ef210:descriptor(y,case['alignment']);m.finish(y)
    elif a==0x1407ef6a0:m.finish(112)
    elif a==0x1407f1a40:descriptor(y,case['class']);m.finish(y)
    elif a==0x1407f3f00:descriptor(y,case['name']);m.finish(y)
    elif a==0x140198c60:descriptor(z,case['prefix']);m.finish(1)
    elif a==0x14016afb0:
        pattern=string(y);tokens=list(re.finditer(r'%[sd]',pattern));values=[z,w]+[m.q(rsp+0x28+i*8) for i in range(max(0,len(tokens)-2))]
        parts=[];at=0
        for match,value in zip(tokens,values):
            parts+=[pattern[at:match.start()],string(value) if match.group()=='%s' else str(signed(value))];at=match.end()
        parts.append(pattern[at:]);descriptor(x,''.join(parts));m.finish()
    elif a==m.stop+0x10:text(x,string(y));m.finish()
    elif a==0x14081b220:text(m.q(x+0x10),string(y));m.finish()
    elif a==0x1409bef10:text(m.q(x+0x90),str(signed(y)));m.finish()
    elif a==0x1407ec3a0:m.finish(((y&255)-10)//2)
    elif a==0x1407f5e20:m.finish(case['maximumHP'])
    elif a==0x1407ef9c0:m.finish(case['armorBase'])
    elif a==0x1407f1ed0:m.finish(case['armorItems'])
    elif a==0x140115890:raise RuntimeError('Unexpected original warning')
    elif not(0x1409b6380<=a<0x1409b72a5 or 0x14088b180<=a<=0x14088b3db or 0x140c10410<=a<=0x140c10430):raise RuntimeError(f'Unmapped dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def invoke(entry,first,second,third=0):
    rsp=m.stack+0x1fe08;u.mem_write(m.stack,bytes(0x20000));m.wq(rsp,m.stop)
    u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,first);u.reg_write(UC_X86_REG_RDX,second);u.reg_write(UC_X86_REG_R8,third)
    u.emu_start(entry,m.stop,count=50000)
    expected=0x1409b72a5 if entry==0x1409b6380 else m.stop
    assert u.reg_read(UC_X86_REG_RIP)==expected
def run(value):
    global case,output,allocation,widget_offsets
    case=value;output={};allocation=0;u.mem_write(m.heap,bytes(0x100000))
    m.wq(creature+0x3b0,stats);m.wq(0x1412df968,tlk)
    m.wq(vtable+0xd0,m.stop+0x10);widget_offsets={}
    for n,off in enumerate(offsets):
        widget=m.heap+0x1a000+n*0x20;widget_offsets[widget]=off;m.wq(widget,vtable)
        m.wq(page+off,widget)
    # The title uses a different sheet, not the page's numeric label slots.
    title_widget=m.heap+0x1c000;widget_offsets[title_widget]=0x988;m.wq(title_widget,vtable);m.wq(sheet+0x988,title_widget)
    byte(sheet+0x150,value['mask']);m.wi(sheet+0x8e0,7)
    for n,score in enumerate(value['scores']):byte(stats+0x70+n,score)
    for n,adjustment in enumerate(value['adjustments']):byte(stats+0x7d+n,adjustment)
    byte(stats+0x7c,value['dexterity']);word(stats+0x86,value['currentHP']);word(stats+0x88,value['temporaryHP'])
    invoke(0x1409b6380,page,7,value['mask']);invoke(0x14088b180,sheet,7)
    return dict(input=value,labels=output)
if __name__=='__main__':
    path=root/'backups/animations/native-creation-summary-mask-v1.json'
    if path.exists():raise RuntimeError('Evidence already exists')
    common=dict(race='Human',alignment='Neutral Good',**{'class':'Wizard (1)'},name='Native Draft',prefix='Character Record',scores=[8,11,12,13,18,20],adjustments=[0,0,0,0,0,0],dexterity=0,currentHP=7,temporaryHP=2,maximumHP=15,armorBase=10,armorItems=3)
    cases=[run(common|dict(mask=mask)) for mask in range(32)]
    cases += [run(common|dict(mask=mask,race='',alignment='Lawful Evil',**{'class':''},name='',prefix='Server record')) for mask in [0,1,2,4,8,16,31]]
    path.write_text(json.dumps(dict(binarySha256=m.digest,scope=__doc__,region=['0x1409b6380','0x1409b72a5'],title='0x14088b180',cases=cases),indent=2)+'\n')
    print(json.dumps(dict(output=str(path),cases=len(cases),binarySha256=m.digest)))
