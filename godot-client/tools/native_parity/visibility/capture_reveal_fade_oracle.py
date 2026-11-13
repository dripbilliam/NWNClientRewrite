"""Full original target-alpha7630e0 and fade-update762e40 instruction oracle.
Object-kind/PlayerInfo lookup, effect override, WorldTimer getters/arithmetic
and render-wrapper calls are captured. No world clock, renderer or network.
"""
import argparse, importlib, itertools, json, struct, sys
from pathlib import Path
ROOT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(ROOT / 'scripts'))
m = importlib.import_module('inspect-native-intratile-coordinator'); u = m.u; u.hook_del(m.hook_handle)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
SHA = '3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a'
if m.digest != SHA: raise RuntimeError('PE identity')
ACTOR, VTABLE, CREATURE, STATS, APP, CONTEXT, PLAYER, RECORDS, RECORD, TIMER, WRAPPER, WRAPPER_TABLE = [m.heap + i * 0x1000 for i in range(1, 13)]
GET_CREATURE, SET_ALPHA, VISIBLE = [m.stop + i * 0x100 for i in range(1, 4)]
current = None; calls = []; target_index = 0
RANGES = [(0x1407630e0, 0x1407631ea), (0x140762e40, 0x140763072)]
def fw(v): return int.from_bytes(struct.pack('<f', v), 'little')
def raw(a): return int.from_bytes(u.mem_read(a, 4), 'little')
def ret_float(bits): u.reg_write(UC_X86_REG_XMM0, bits); m.finish()
def state(): return dict(status=u.mem_read(ACTOR+0xa8,1)[0], desired=u.mem_read(ACTOR+0xa9,1)[0], opacity_word=raw(ACTOR+0xb0), expiry_enabled=raw(ACTOR+0xac), expiry_ms=raw(ACTOR+0xa4), start_day=raw(ACTOR+0x9c), start_ms=raw(ACTOR+0xa0))
def hook(_u, address, _size, _data):
    global target_index
    x,y,z,w=[u.reg_read(reg) for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
    if address==m.stop: u.emu_stop()
    elif address==GET_CREATURE:
        if x!=ACTOR: raise AssertionError('Creature owner')
        calls.append(dict(kind='creature_view')); m.finish(CREATURE if current['input']['is_creature'] else 0)
    elif address==0x1406ac1a0:
        calls.append(dict(kind='player_info')); m.finish(PLAYER if current['input']['player_info_present'] else 0)
    elif address==0x140763420:
        calls.append(dict(kind='effect_override')); ret_float(current['input']['effect_override_word'])
    elif address==0x1407630e0 and current['operation']=='fade':
        value=current['targets'][target_index]; target_index+=1
        calls.append(dict(kind='target_alpha',alpha_word=value)); ret_float(value)
    elif address==0x1406ac330: calls.append(dict(kind='world_timer')); m.finish(TIMER)
    elif address==0x140597050:
        calls.append(dict(kind='snapshot_difference')); m.finish(current['timing']['snapshot_us'])
    elif address==0x140597180:
        calls.append(dict(kind='world_time')); m.wi(y,current['timing']['now_day']); m.wi(z,current['timing']['now_ms']); m.finish()
    elif address==0x140597a20:
        sp=u.reg_read(UC_X86_REG_RSP)
        calls.append(dict(kind='world_elapsed')); m.wi(m.q(sp+0x30),0);m.wi(m.q(sp+0x38),current['timing']['elapsed_world_ms']);m.finish()
    elif address==SET_ALPHA:
        if x!=WRAPPER or z&255!=255: raise AssertionError('Alpha wrapper ABI')
        calls.append(dict(kind='set_alpha',scope=255,alpha_word=u.reg_read(UC_X86_REG_XMM1)&0xffffffff));m.finish()
    elif address==VISIBLE:
        if x!=WRAPPER or y&0xffffffff!=0: raise AssertionError('Visibility wrapper ABI')
        calls.append(dict(kind='render_owner_virtual8',argument=0));m.finish()
    elif not any(lo<=address<=hi for lo,hi in RANGES): raise RuntimeError(f'Uncaptured reveal/fade dependency {address:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(value):
    global current,calls,target_index
    current,calls,target_index=value,[],0
    u.mem_write(m.heap,bytes(0xe000));u.mem_write(m.stack,bytes([0xa5])*0x20000)
    m.wq(0x1412df970,APP);m.wq(APP,CONTEXT);m.wq(ACTOR,VTABLE);m.wq(VTABLE+0x58,GET_CREATURE)
    m.wi(ACTOR+8,0xffffffff);m.wq(CREATURE+0x3b0,STATS)
    info=value['input'];m.wi(STATS+0x114,info['creature114']);m.wi(STATS+0x110,info['creature110'])
    m.wq(PLAYER+0x3f0,RECORDS);m.wi(PLAYER+0x3f8,1 if info['matching_perception_present'] else 0)
    m.wq(RECORDS,RECORD);m.wi(RECORD,0xffffffff)
    flags=info['perception'];u.mem_write(RECORD+4,bytes([(2 if flags[0] else 0)|(1 if flags[1] else 0)|(16 if flags[2] else 0)]))
    m.wq(ACTOR+0x78,WRAPPER if value['render_owner_present'] else 0);m.wq(WRAPPER,WRAPPER_TABLE);m.wq(WRAPPER_TABLE+8,VISIBLE);m.wq(WRAPPER_TABLE+0xe8,SET_ALPHA)
    for key,offset in [('opacity_word',0xb0),('expiry_enabled',0xac),('expiry_ms',0xa4),('start_day',0x9c),('start_ms',0xa0)]: m.wi(ACTOR+offset,value['state'][key])
    u.mem_write(ACTOR+0xa8,bytes([value['state']['status'],value['state']['desired']]))
    if value['operation']=='target': u.mem_write(ACTOR+0xa9,bytes([info['revealed']]))
    sp=m.stack+0x1fe08;m.wq(sp,m.stop);u.reg_write(UC_X86_REG_RSP,sp);u.reg_write(UC_X86_REG_RCX,ACTOR);u.reg_write(UC_X86_REG_MXCSR,0x1f80)
    u.emu_start(0x1407630e0 if value['operation']=='target' else 0x140762e40,m.stop,count=15000)
    if u.reg_read(UC_X86_REG_RIP)!=m.stop:raise AssertionError('Normal return absent')
    return dict(case=value,calls=list(calls),state=state(),alpha_word=u.reg_read(UC_X86_REG_XMM0)&0xffffffff,completion_requested=bool(u.reg_read(UC_X86_REG_RAX)&0xffffffff),target_queries=target_index)
def main():
    parser=argparse.ArgumentParser();parser.add_argument('--output',required=True);args=parser.parse_args()
    output=Path(args.output).resolve();boundary=(ROOT/'godot-client/.cache/native-presentation-parity/render-agent').resolve()
    if not output.is_relative_to(boundary) or output.exists():raise RuntimeError('Fresh owned output required')
    default=dict(operation='target',input=dict(is_creature=True,revealed=1,player_info_present=True,matching_perception_present=True,perception=[False,True,False],creature114=0,creature110=0,effect_override_word=fw(-1)),state=dict(status=1,desired=1,opacity_word=fw(.75),expiry_enabled=0,expiry_ms=500,start_day=10,start_ms=12),timing=dict(snapshot_us=16666,now_day=11,now_ms=24,elapsed_world_ms=499),targets=[fw(.5),fw(.25)],render_owner_present=True)
    rows=[]
    for creature,revealed,player,record,flags,c114,c110,override in itertools.product([False,True],[0,1,2],[False,True],[False,True],list(itertools.product([False,True],repeat=3)),[0,1],[0,1],[fw(-1),fw(.25),0x7fc12345]):
        rows.append(run(default|dict(input=default['input']|dict(is_creature=creature,revealed=revealed,player_info_present=player,matching_perception_present=record,perception=flags,creature114=c114,creature110=c110,effect_override_word=override))))
    for status,desired,opacity,target,snapshot,expiry in itertools.product([0,1,2,3],[0,1,2],[fw(-.1),0,fw(.25),fw(.75),fw(1.1),0x80000000,0x7fc12345],[0,fw(.5),fw(1),0x7fc54321],[0,999,1000,16666,4294967296000],[0,1]):
        rows.append(run(default|dict(operation='fade',state=default['state']|dict(status=status,desired=desired,opacity_word=opacity,expiry_enabled=expiry),targets=[target,fw(.375)],timing=default['timing']|dict(snapshot_us=snapshot))))
    for elapsed in [0,499,500,501,0xffffffff]:
        rows.append(run(default|dict(operation='fade',state=default['state']|dict(expiry_enabled=1),timing=default['timing']|dict(elapsed_world_ms=elapsed))))
    result=dict(binarySha256=m.digest,scope=__doc__,cases=len(rows),rows=rows,notCovered=['WorldTimer calendar arithmetic','actual target providers during fade body','renderer','network','fade setter and entry triggers'])
    output.parent.mkdir(parents=True,exist_ok=True);output.write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(dict(output=str(output),cases=len(rows))))
if __name__=='__main__':main()
