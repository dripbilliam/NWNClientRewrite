import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {presentMapPin,playerMapPosition} from '../src/map_pin_presentation.js';
import {tileMapImageRef} from '../src/tile_map_image.js';
import {encodeGffText,decodeGffText} from '../src/gff_text.js';
const data=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-map-presentation-observations.json',import.meta.url)));
test('complete pin presentation matches660 original executions: exact1 visibility, CVTT, FLOAT rounding and attachment',async()=>{
 assert.equal(data.pins.length,660);
 for(const row of data.pins){const c=row.case,trace=[],map={width:c.width,height:c.height,zoom514:c.zoom,container1e8:{},view110:{}},pin={nativeStateE8:c.attached};let reads=0;
  const result=await presentMapPin(map,pin,c.force,{position:()=>{const point=c.positions[Math.min(reads++,c.positions.length-1)];trace.push(['position',point]);return point;},tileState:()=>c.tileState,attach:()=>{trace.push(['attach']);if(c.attachSetsFlag)pin.nativeStateE8=1;return c.attachResult;},model:()=>({}),viewOrigin:()=>{trace.push(['viewOrigin']);return c.origin;},transform:(_m,_root,point,quat)=>trace.push(['transform',point,quat])});
  assert.deepEqual({result,attached:pin.nativeStateE8,trace},{result:row.result,attached:row.attached,trace:row.trace},JSON.stringify(c));
 }
});
test('ImageMap2D branch matches32 original executions with actual INI missing/empty reads and ResRef copying',()=>{
 assert.equal(data.images.length,32);
 for(const row of data.images){const c=row.case,raw=c.hex===null?'':decodeGffText(Buffer.from(c.hex,'hex')),value=c.missingSection||c.missingKey?undefined:raw,ref=tileMapImageRef(value),bytes=new Uint8Array(17);bytes.set(encodeGffText(ref));assert.equal(Buffer.from(bytes).toString('hex'),row.resrefHex,JSON.stringify(c));}
});
test('player marker projection matches48 original bounded executions without pin pixel-rounding',()=>{
 assert.equal(data.players.length,48);for(const row of data.players)assert.deepEqual(playerMapPosition({width:row.case.width,height:row.case.height,zoom514:row.case.zoom},row.case.point),row.position,JSON.stringify(row.case));
});
