"""Execute unchanged original TrueType glyph and bitmap-box getters.

The decoded SFNT font-info fixture supplies table offsets; original InitFont,
CFF fonts, glyph rasterization, atlas packing and enhancement remain excluded.
There are no substituted reached calls: finite floorf/ceilf execute unchanged.
The glyph indices and binary32 pixel-height scales come from the retained
original 1536-case glyph-metric oracle, without rewriting its proof.
"""
from pathlib import Path
import hashlib,json,struct,sys
root=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(root/'backups/research-python'))
import pefile
from unicorn import Uc,UC_ARCH_X86,UC_MODE_64,UC_HOOK_CODE
from unicorn.x86_const import *

def arg(name,default):
    return next((x.split('=',1)[1] for x in sys.argv[1:] if x.startswith('--'+name+'=')),str(default))

source_path=root.parent/'FullDecomp/NwnRootInstall/bin/win32/nwmain.exe'
source=source_path.read_bytes();digest=hashlib.sha256(source).hexdigest()
assert digest=='3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a'
pe=pefile.PE(data=source);base=pe.OPTIONAL_HEADER.ImageBase
u=Uc(UC_ARCH_X86,UC_MODE_64);u.mem_map(base,(pe.OPTIONAL_HEADER.SizeOfImage+4095)&~4095);u.mem_write(base,pe.get_memory_mapped_image())
heap,stack,stop,font_address=0x200000000,0x300000000,0x400000000,0x500000000
u.mem_map(heap,0x10000);u.mem_map(stack,0x20000);u.mem_map(stop,0x1000);u.mem_map(font_address,0x400000)
info=heap+0x1000;outputs=heap+0x2000
ranges=[(0x140104c00,0x140104d09),(0x1401046d0,0x1401048de),(0x1400fd8c0,0x1400fd99b),(0x140c7ed44,0x140c7edbf),(0x140c7fef0,0x140c7ff76)]
def hook(engine,at,size,context):
    if at==stop: engine.emu_stop();return
    assert any(lo<=at<=hi for lo,hi in ranges),f'Uncaptured original glyph-box dependency {at:x}'
u.hook_add(UC_HOOK_CODE,hook)
def wq(at,value):u.mem_write(at,struct.pack('<Q',value))
def wi(at,value):u.mem_write(at,struct.pack('<i',value))
def s16(data,at):return struct.unpack_from('>h',data,at)[0]
def u16(data,at):return struct.unpack_from('>H',data,at)[0]
def fbits(value):return int.from_bytes(struct.pack('<f',value),'little')
def prepare(data):
    assert len(data)<0x400000
    u.mem_write(heap,bytes(0x10000));u.mem_write(font_address,data)
    tables={data[12+n*16:16+n*16].decode('ascii'):struct.unpack_from('>II',data,20+n*16) for n in range(u16(data,4))}
    assert all(name in tables for name in ['head','maxp','loca','glyf'])
    wq(info+8,font_address);wi(info+0x14,u16(data,tables['maxp'][0]+4));wi(info+0x18,tables['loca'][0]);wi(info+0x20,tables['glyf'][0]);wi(info+0x3c,s16(data,tables['head'][0]+50))
    return {'tables':{key:{'offset':value[0],'length':value[1]}for key,value in tables.items()},'glyph_count':u16(data,tables['maxp'][0]+4),'loca_format':s16(data,tables['head'][0]+50)}
def start(glyph):
    u.mem_write(stack,bytes(0x20000));u.mem_write(outputs,bytes(16));sp=stack+0x1fe08;wq(sp,stop)
    for reg,value in [(UC_X86_REG_RSP,sp),(UC_X86_REG_RCX,info),(UC_X86_REG_RDX,glyph)]:u.reg_write(reg,value)
    return sp
def finish(at):
    u.emu_start(at,stop,count=10000);assert u.reg_read(UC_X86_REG_RIP)==stop
    return list(struct.unpack('<4i',u.mem_read(outputs,16)))
def glyph_box(glyph):
    sp=start(glyph)
    u.reg_write(UC_X86_REG_R8,outputs);u.reg_write(UC_X86_REG_R9,outputs+4);wq(sp+0x28,outputs+8);wq(sp+0x30,outputs+12)
    box=finish(0x140104c00);return bool(u.reg_read(UC_X86_REG_RAX)&0xffffffff),box
def bitmap_box(glyph,scale,shift_x=0.,shift_y=0.):
    sp=start(glyph);u.reg_write(UC_X86_REG_XMM2,fbits(scale));u.reg_write(UC_X86_REG_XMM3,fbits(scale))
    u.mem_write(sp+0x28,struct.pack('<f',shift_x));u.mem_write(sp+0x30,struct.pack('<f',shift_y))
    for index in range(4):wq(sp+0x38+8*index,outputs+4*index)
    return finish(0x1401046d0)
def main():
    input_path=Path(arg('inputs',root/'godot-client/reports/native-ttf-metrics-current-v2.json'));oracle_path=Path(arg('oracle',root/'backups/animations/native-ttf-metrics-v1.json'));report=Path(arg('report',root/'godot-client/reports/native-ttf-glyph-boxes-v1.json'))
    assert not report.exists(),'Preserve previous glyph-box evidence'
    inputs=json.loads(input_path.read_text(encoding='utf-8-sig'));oracle=json.loads(oracle_path.read_text());fonts=[]
    for resource in inputs['resources']:
        data=Path(resource['path']).read_bytes();assert hashlib.sha256(data).hexdigest()==resource['sha256']
        prior=next(row for row in oracle['fonts'] if row['name']==resource['name']);assert prior['font_sha256']==resource['sha256'];decoded=prepare(data);sizes=[]
        for size in prior['sizes']:
            rows=[]
            for row in size['glyphs']:
                present,box=glyph_box(row['glyph']);bitmap=bitmap_box(row['glyph'],size['native_scale'])
                rows.append({'byte':row['byte'],'codepoint':row['codepoint'],'glyph':row['glyph'],'present':present,'font_units':box,'bitmap_box':bitmap,'shifted_bitmap_box':bitmap_box(row['glyph'],size['native_scale'],.25,.5),'scale':size['native_scale']})
            sizes.append({'height':size['requested_height'],'glyphs':rows})
        fonts.append({'name':resource['name'],'sha256':resource['sha256'],'decoded_fixture':decoded,'sizes':sizes})
    report.write_text(json.dumps({'scope':__doc__,'binarySha256':digest,'harnessSha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'metricOracleSha256':hashlib.sha256(oracle_path.read_bytes()).hexdigest(),'unchangedInstructionRanges':[[hex(lo),hex(hi)]for lo,hi in ranges],'substitutedCalls':[],'fonts':fonts,'gameServerConnections':0,'gpu':False,'sourceAssetsExported':False},indent=2)+'\n')
    print(json.dumps({'report':str(report),'fonts':len(fonts),'glyphRows':sum(len(size['glyphs'])for font in fonts for size in font['sizes'])}))
if __name__=='__main__':main()
