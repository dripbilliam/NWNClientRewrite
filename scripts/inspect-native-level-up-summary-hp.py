"""Execute unchanged838950 Summary HP block838b8c..838dd6. Explicit boundaries:
ability modifier getter, total/class getter, primary feat membership and active
ruleset lookup. Original signed/BYTE arithmetic and branches execute on CPU;
not a full finalizer, random-state, runtime or server proof.
"""
from pathlib import Path
import importlib.util,json,hashlib
root=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('summary_hp_image',root/'scripts/inspect-native-intratile-coordinator.py')
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
new,old,creature,rules=[m.heap+n for n in [0x1000,0x3000,0x5000,0x7000]]
def hook(u,address,size,unused):
    global rule
    if address==0x140838dd6:u.emu_stop();return
    if address==0x1407ec3a0:
        actor=u.reg_read(UC_X86_REG_RCX);score=u.reg_read(UC_X86_REG_RDX)&255
        assert actor in [new,old] and score in [11,22,33]
        m.finish(case[{11:'effectiveModifier',22:'newBaseModifier',33:'oldBaseModifier'}[score]])
    elif address==0x1407f5d70:m.finish(case['oldLevel'] if u.reg_read(UC_X86_REG_RCX)==old else case['newLevel'])
    elif address==0x1407ee620:
        actor=u.reg_read(UC_X86_REG_RCX);feat=u.reg_read(UC_X86_REG_RDX)&65535
        assert actor in [new,old] and feat in [40,891]
        m.finish(int(feat in case['oldFeats' if actor==old else 'newFeats']))
    elif address==0x1407f0f60:assert u.reg_read(UC_X86_REG_RCX)==new;m.finish(case['classId'])
    elif address==0x1407f1080:assert u.reg_read(UC_X86_REG_RCX)==new;m.finish(case['classLevel'])
    elif address==0x1402ae870:
        rule=bytes(u.mem_read(u.reg_read(UC_X86_REG_RCX),40)).split(b'\0')[0].decode();m.finish(1)
    elif address==0x1402a4130:
        values={'EAT_TOUGHNESS_HP_BONUS':case['toughness'],'EAT_DEATHLESS_VIGOR_HP_BONUS':case['deathless'],'EAT_EPIC_DEATHLESS_VIGOR_HP_BONUS':case['epicDeathless']}
        assert rule in values,rule;m.finish(values[rule])
    elif not 0x140838b8c<=address<0x140838dd6:raise AssertionError('Uncaptured Summary HP dependency '+hex(address))
u.hook_add(UC_HOOK_CODE,hook)
def run(value):
    global case,rule
    case=value;rule='';u.mem_write(m.heap,bytes(0x100000));m.wq(0x1412df8f8,rules);m.wq(creature+0x3b0,new)
    u.mem_write(new+0x72,b'\x0b');u.mem_write(new+0x78,b'\x16');u.mem_write(old+0x78,b'\x21');u.mem_write(new+0x84,(100).to_bytes(2,'little'))
    bp=m.stack+0x1f800;u.reg_write(UC_X86_REG_RSP,m.stack+0x1fe00);u.reg_write(UC_X86_REG_RBP,bp)
    for reg,value in [(UC_X86_REG_R15,new),(UC_X86_REG_R12,old),(UC_X86_REG_R14,creature),(UC_X86_REG_R13,0),(UC_X86_REG_RBX,case['roll'])]:u.reg_write(reg,value)
    u.emu_start(0x140838b8c,0x140838dd6,count=10000);assert u.reg_read(UC_X86_REG_RIP)==0x140838dd6
    byte=u.mem_read(bp-0x28,1)[0]
    return dict(case=case,gainByte=byte,displayGain=byte-256 if byte>=128 else byte,baseHP=int.from_bytes(u.mem_read(new+0x84,2),'little',signed=True))
if __name__=='__main__':
    out=root/'godot-client/reports/native-level-up-summary-hp-original-v1.json';assert not out.exists(),'Preserve evidence'
    rows=[]
    for i in range(384):
        flags=[[],[40],[40,891],[891]][(i//3)%4];old_flags=[[],[40],[891]][(i//11)%3]
        case=dict(roll=[0,1,8,127,128,255][i%6],effectiveModifier=[-128,-10,-1,0,2,127][(i//2)%6],newBaseModifier=[-3,-1,0,2,127][(i//5)%5],oldBaseModifier=[-3,-1,0,2,127][(i//7)%5],oldLevel=[2,20,128,254][(i//13)%4],classId=34 if i%3 else 0,classLevel=[1,10,11,14,15,20,255][(i//17)%7],oldFeats=old_flags,newFeats=flags,toughness=[1,5,-1,257][(i//19)%4],deathless=[3,9,-2][(i//23)%3],epicDeathless=[5,7,258][(i//29)%3]);case['newLevel']=(case['oldLevel']+1)&255
        rows.append(run(case))
    out.write_text(json.dumps(dict(binarySha256=m.digest,scope=__doc__,rows=rows,scriptSha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest()),indent=2)+'\n');print(json.dumps(dict(output=str(out),cases=len(rows))))
