import test from 'node:test';import assert from 'node:assert/strict';
import {parseBitmapFont,bitmapGlyph} from '../src/native_bitmap_font.js';
const text='numchars 2\nfontheight 0.16\nbaselineheight 0.12\ntexturewidth 0.16\nspacingR 0.01\nupperleftcoords 2\n0 1 0\n0 0.5 0\nlowerrightcoords 2\n0.6875 0.5 0\n0.5 0 0\n';
test('TXI font metrics preserve native GUI scale, bottom-origin UVs, glyph advances and fallback index',()=>{
 const font=parseBitmapFont(text);assert.equal(font.height,16);assert.equal(font.baseline,12);assert.deepEqual(bitmapGlyph(font,0,16,32),{sx:0,sy:0,sw:11,sh:16,width:11,height:16,advance:12,missing:false});assert.deepEqual(bitmapGlyph(font,1,16,32),{sx:0,sy:16,sw:8,sh:16,width:8,height:16,advance:9,missing:false});assert.equal(bitmapGlyph(font,200,16,32).missing,true);
});
test('invalid/missing font metadata and out-of-atlas glyphs fail explicitly',()=>{
 for(const value of ['',text.replace('numchars 2','numchars 3'),text.replace('fontheight 0.16','fontheight NaN'),text.replace('0.6875 0.5 0','bad')])assert.throws(()=>parseBitmapFont(value));const font=parseBitmapFont(text);font.lower[0][0]=2;assert.throws(()=>bitmapGlyph(font,0,16,32));
});
