"""Execute original GLRender::RenderVertexStreamData instructions read-only.
Captures stream binding, shader selection and the final OpenGL draw entrypoints
instead of executing a driver or GPU. Verifies count/offset/index dispatch and
state invalidation, not driver timing, GPU pixels or complete shader behavior.
The original SHA-checked executable is neither launched nor modified.
"""
import importlib,itertools,json
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
stream=m.heap
draw_elements,draw_arrays=m.stop+0x10,m.stop+0x20

def hook(u,address,size,_):
    if address==m.stop:u.emu_stop();return
    x,y,z,w=[u.reg_read(reg) for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
    if address==0x1400bacc0:calls.append(dict(call='bind_stream',stream=x));m.finish()
    elif address==0x1400b7a40:calls.append(dict(call='select_program',kind=x));m.finish()
    elif address==draw_arrays:calls.append(dict(call='glDrawArrays',mode=x,first=y,count=z));m.finish()
    elif address==draw_elements:calls.append(dict(call='glDrawElements',mode=x,count=y,index_type=z,byte_offset=w));m.finish()
    elif not 0x1400b5c20<=address<0x1400b5dc0:raise RuntimeError(f'Unexpected native draw dependency {address:x}')
u.hook_add(UC_HOOK_CODE,hook)

def run(count,capacity,indexed,offset,custom,enabled,null=False):
    global calls
    calls=[];u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000))
    m.wq(0x140d7ca70,draw_elements);m.wq(0x140d7ca78,draw_arrays)
    m.wq(0x1413d2750,m.heap+0x8000 if custom else 0)
    m.wi(0x1413d2944,enabled);m.wi(0x1413d2948,17);m.wi(0x1413d2704,0)
    m.wi(stream+0x24,0x805);m.wi(stream+0x2c,capacity);u.mem_write(stream+8,bytes([indexed]))
    rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
    for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],[0 if null else stream,3,count,offset]):u.reg_write(reg,value)
    u.emu_start(0x1400b5c20,m.stop,count=10000)
    assert u.reg_read(UC_X86_REG_RIP)==m.stop
    draws=[call for call in calls if call['call'].startswith('glDraw')]
    expected=[] if null else [dict(call='glDrawElements',mode=4,count=count,index_type=0x1403,byte_offset=offset*2) if indexed else dict(call='glDrawArrays',mode=4,first=offset,count=count)]
    assert draws==expected
    assert m.q(0x1413d2750)==0 and m.si(0x1413d2948)==0
    assert m.si(0x1413d2944)==enabled&~0x240000
    assert m.si(0x1413d2704)==int(bool(enabled&0x200000))
    if custom and not null:assert [call for call in calls if call['call']=='select_program']==[dict(call='select_program',kind=14)]
    return dict(input=dict(vertices=count,capacity=capacity,indexed=indexed,offset=offset,custom_program=custom,enabled_states=enabled,null_stream=null),calls=calls)

if __name__=='__main__':
    out=m.root/'backups/animations/native-particle-draw-v1.json'
    assert not out.exists(),'Preserve original instruction observations'
    rows=[run(*case) for case in itertools.product([0,6,60,768],[768,1536],[0,1],[0,6],[False,True],[0,0x240000])]
    rows.extend(run(6,768,0,0,True,states,True) for states in [0,0x240000])
    out.write_text(json.dumps(dict(binarySha256=m.digest,scope=__doc__,rows=rows),indent=2))
    print(json.dumps(dict(success=True,output=str(out),cases=len(rows),gpu_execution=False,network_connections=0)))
