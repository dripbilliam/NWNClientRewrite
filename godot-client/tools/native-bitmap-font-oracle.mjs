// Offline reference only; supplies no runtime pixels, fonts or layout.
import fs from 'node:fs/promises';import path from 'node:path';import {createHash} from 'node:crypto';
import {openServerResourceContext} from '../../electron/server_resource_context.mjs';
import {parseBitmapFont,bitmapGlyph} from '../../src/native_bitmap_font.js';
import {parseNativeTga} from '../../src/native_tga.js';
import {resolveTextureResource} from '../../src/texture_resource.js';
import {loadRasterTexture} from '../../src/raster_texture.js';
const hash=b=>createHash('sha256').update(b).digest('hex'),install=path.resolve('../FullDecomp/NwnRootInstall');
const name=process.argv.find(v=>v.startsWith('--run='))?.slice(6)??'native-bitmap-font-oracle-v5';if(!/^[a-z0-9-]+$/.test(name))throw Error('Invalid report name');
const resolver=await openServerResourceContext({install,module:path.join(install,'data/nwm/Prelude.nwm')}),fonts=[];
for(const name of ['fnt_galahad14','fnt_floaty_smal']){
 const selected=await resolveTextureResource(resolver,name),raw=Buffer.from(await resolver.getResource(name,2022)),raster=Buffer.from(selected.bytes),tga=Buffer.from(await resolver.getResource(name,3)),metrics=parseBitmapFont(raw.toString('ascii')),image=parseNativeTga(tga),glyphs=[];
 let mipSha256=null;
 if(selected.type!==3){const texture=await loadRasterTexture(resolver,name);mipSha256=hash(texture.mipmaps[0].data);texture.dispose();}
 for(const byte of [0,32,33,65,87,97,128,149,151,233,255]){
  const glyph=bitmapGlyph(metrics,byte,image.width,image.height),pixels=Buffer.alloc(glyph.sw*glyph.sh*4);
  for(let y=0;y<glyph.sh;y++)pixels.set(image.data.subarray(((glyph.sy+y)*image.width+glyph.sx)*4,((glyph.sy+y)*image.width+glyph.sx+glyph.sw)*4),y*glyph.sw*4);
  glyphs.push({byte,...glyph,tgaSha256:hash(pixels)});
 }
 fonts.push({name,atlasType:selected.type,metricsSha256:hash(raw),atlasSha256:hash(raster),mipSha256,tgaSha256:hash(tga),width:image.width,height:image.height,metrics:{count:metrics.count,height:metrics.height,baseline:metrics.baseline,width:metrics.width,spacingR:metrics.spacingR,spacingB:metrics.spacingB},glyphs});
}
const sources={};for(const source of ['src/native_bitmap_font.js','src/native_tga.js','src/raster_texture.js','src/texture_resource.js','src/bioware_dds.js','src/s3tc_decode.js'])sources[source]=hash(await fs.readFile(source));
const report='godot-client/reports/'+name+'.json';await fs.writeFile(report,JSON.stringify({fonts,sources,scope:'Independent original TXI metrics, selected raster source/compressed mip hashes and TGA glyph-region hashes. DDS publication is tested against Godot Image decompression, not claimed byte-identical to original GPU interpolation. No pixels saved; no native runtime JS dependency.'},null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({report,fonts:fonts.length,glyphs:fonts.reduce((n,v)=>n+v.glyphs.length,0)}));
