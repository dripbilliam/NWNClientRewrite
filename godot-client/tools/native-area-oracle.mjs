// Offline reference only. Original art stays in the installation/module.
import fs from 'node:fs/promises';
import path from 'node:path';
import {createHash} from 'node:crypto';
import {parseKey,parseErf} from '../../src/resource_archive.js';
import {parseGff} from '../../src/gff.js';
import {parseTileset,parseAreaModule} from '../../src/area.js';
import {writeGff,gffRecord as record,gffField as f} from '../../src/gff_writer.js';
const install=path.resolve('../FullDecomp/NwnRootInstall'),modulePath=path.resolve('runtime-logs/local-multiplayer-server/modules/GodotFeedback1.mod');
const hash=b=>createHash('sha256').update(b).digest('hex'),resources=new Map();
for(const name of ['data/nwn_retail.key','data/nwn_base.key']){const key=parseKey(await fs.readFile(path.join(install,name)));for(const [id,row]of key.resources)if(!resources.has(id))resources.set(id,{...row,bif:key.bifNames[row.bifIndex]});}
async function original(name,type){const row=resources.get(name+':'+type);if(!row)throw Error('Missing original '+name);const file=await fs.open(path.join(install,row.bif),'r');try{const h=Buffer.alloc(20);await file.read(h,0,20,0);const v11=h.toString('ascii',4,8)==='V1.1',stride=v11?20:16,p=v11?8:4,r=Buffer.alloc(stride);await file.read(r,0,stride,h.readUInt32LE(16)+row.resourceIndex*stride);if(r.readUInt32LE(p+8)!==type)throw Error('Type mismatch');const b=Buffer.alloc(r.readUInt32LE(p+4));if((await file.read(b,0,b.length,r.readUInt32LE(p))).bytesRead!==b.length)throw Error('Truncated original');return b;}finally{await file.close();}}
const moduleBytes=await fs.readFile(modulePath),module=parseErf(moduleBytes),areas=[];
for(const [id,bytes]of module.entries){if(!id.endsWith(':2012'))continue;const area=parseGff(bytes).root,setBytes=await original(area.Tileset,2013),set=parseTileset(setBytes.toString('latin1'));
 areas.push({name:id.split(':')[0],width:area.Width,height:area.Height,tileset:area.Tileset,are_sha256:hash(bytes),set_sha256:hash(setBytes),tiles:area.Tile_List.map((tile,index)=>({model:set.tiles[tile.Tile_ID].model,position:[index%area.Width*10+5,tile.Tile_Height*set.transition,-(Math.floor(index/area.Width)*10+5)],rotation_y:tile.Tile_Orientation*Math.PI/2}))});
}
const setText='; Authored\n[general]\nTransition=2.5\n[TILES]\nCount=3\n[TILE0]\nModel=DEMO_A\nPathNode=7\n[TILE1]\nModel=demo_b\n[TILE2]\nModel=demo_c\n';
const authored={Width:4,Height:2,Tileset:'auth_set',Tile_List:Array.from({length:8},(_,i)=>({Tile_ID:i%3,Tile_Height:i%2,Tile_Orientation:i%4}))};
function are(root){return Buffer.from(writeGff('ARE ',record({Width:f(5,root.Width),Height:f(5,root.Height),Tileset:f(11,root.Tileset),Tile_List:f(15,root.Tile_List.map(row=>record(Object.fromEntries(Object.entries(row).map(([k,v])=>[k,f(5,v)])))))})));}
const gff=are(authored),git=Buffer.from(writeGff('GIT ',record({}))),resolver={getResource:async(_name,type)=>type===2012?gff:type===2023?git:type===2013?Buffer.from(setText):Buffer.from('2DA V2.0\n\nName\n')};
const reference=await parseAreaModule('auth_area',resolver);
const expected=reference.tiles.map((t,i)=>({model:t.model,position:[i%reference.width*10+5,t.height*reference.tileHeight,-(Math.floor(i/reference.width)*10+5)],rotation_y:t.orientation*Math.PI/2}));
const fixture={scope:'Offline original SET/owned local ARE metadata only; authored parser cases; no art copied',install,module:modulePath,moduleSha256:hash(moduleBytes),areas,authored:{area:authored,setText,expected},sourceSha256:{'src/area.js':hash(await fs.readFile('src/area.js')),'godot-client/tools/native-area-oracle.mjs':hash(await fs.readFile('godot-client/tools/native-area-oracle.mjs'))}};
await fs.writeFile('godot-client/reports/native-area-oracle-v1.json',JSON.stringify(fixture,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({areas:areas.map(a=>({name:a.name,tiles:a.tiles.length,models:[...new Set(a.tiles.map(t=>t.model))]})),authoredTiles:expected.length}));
