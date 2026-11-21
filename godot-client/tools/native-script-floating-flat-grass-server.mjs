// Test-only authored control. No process launch, credentials or production writes.
import fs from 'node:fs/promises';
import path from 'node:path';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
import {fileURLToPath} from 'node:url';
import {prepare as prepareBase,read as readBase,owned} from './native-script-floating-server.mjs';
import {parseErf,decodeResourceText} from '../../src/resource_archive.js';
import {parseGff} from '../../src/gff.js';
import {parseModel} from '../../src/model_parser.js';
import {parseWalkmesh} from '../../src/walkmesh.js';
import {openServerResourceContext} from '../../electron/server_resource_context.mjs';

const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const install=path.resolve(project,'../../FullDecomp/NwnRootInstall');
export const TILE_ID=120;
const corners=['TopRight','BottomRight','BottomLeft','TopLeft'];
const edges=['Top','Right','Bottom','Left'];
const fields={Tile_ID:TILE_ID,Tile_Orientation:0,Tile_Height:0};
const digest=bytes=>crypto.createHash('sha256').update(bytes instanceof ArrayBuffer?new Uint8Array(bytes):bytes).digest('hex');
function sections(text){const result={};let current;for(const line of text.split(/\r?\n/)){const match=line.match(/^\s*\[([^\]]+)\]\s*$/);if(match){current=match[1].toUpperCase();result[current]={};continue;}const at=line.indexOf('=');if(current&&at>=0)result[current][line.slice(0,at).trim()]=line.slice(at+1).trim();}return result;}

export function patchArea(input){
 const before=Buffer.from(input),root=parseGff(before,'ARE ').root;
 assert.equal(root.Tileset.toLowerCase(),'ttr01','Only the verified rural fixture is supported');
 assert.equal(root.Width,10);assert.equal(root.Height,10);assert.equal(root.Tile_List.length,100);
 const output=Buffer.from(before),view=new DataView(output.buffer,output.byteOffset,output.byteLength);
 const header=Array.from({length:12},(_,i)=>view.getUint32(8+i*4,true));
 const [structOffset,structCount,fieldOffset,fieldCount,labelOffset,labelCount]=header;
 // The explicit header fields below avoid depending on a re-encoded GFF layout.
 const fiOffset=view.getUint32(40,true),fiSize=view.getUint32(44,true),liOffset=view.getUint32(48,true),liSize=view.getUint32(52,true);
 const label=index=>{assert.ok(index<labelCount);return output.subarray(labelOffset+index*16,labelOffset+(index+1)*16).toString('ascii').replace(/\0.*$/s,'');};
 const structFields=index=>{assert.ok(index<structCount);const at=structOffset+index*12,count=view.getUint32(at+8,true),data=view.getUint32(at+4,true);if(!count)return[];if(count===1)return[data];assert.equal(data%4,0);assert.ok(data+count*4<=fiSize);return Array.from({length:count},(_,i)=>view.getUint32(fiOffset+data+i*4,true));};
 const find=(index,name)=>{const matches=structFields(index).filter(id=>{assert.ok(id<fieldCount);return label(view.getUint32(fieldOffset+id*12+4,true))===name;});assert.equal(matches.length,1,name);return fieldOffset+matches[0]*12;};
 const list=find(0,'Tile_List');assert.equal(view.getUint32(list,true),15);const listAt=view.getUint32(list+8,true);assert.equal(listAt%4,0);assert.ok(listAt+4+100*4<=liSize);assert.equal(view.getUint32(liOffset+listAt,true),100);
 const scalarOffsets=new Set(),changes=[];
 for(let i=0;i<100;i++){
  const index=view.getUint32(liOffset+listAt+4+i*4,true);
  for(const [name,value]of Object.entries(fields)){
   const at=find(index,name);assert.equal(view.getUint32(at,true),5,'Original tile field must remain GFF INT');
   const old=view.getInt32(at+8,true);view.setInt32(at+8,value,true);
   for(let n=0;n<4;n++)scalarOffsets.add(at+8+n);
   if(old!==value)changes.push({tile:i,field:name,before:old,after:value,offset:at+8});
  }
 }
 const after=parseGff(output,'ARE ').root;
 const expected=parseGff(before,'ARE ').root;for(const tile of expected.Tile_List)Object.assign(tile,fields);
 assert.deepEqual(after,expected,'All semantic ARE data except the three tile fields must survive');
 for(let i=0;i<before.length;i++)if(!scalarOffsets.has(i))assert.equal(output[i],before[i],'Non-tile ARE byte changed at '+i);
 return{bytes:output,changes,root:after,preservedBytes:before.length-scalarOffsets.size};
}

export function compatibleJoins(area,tile){
 const edge=(entry,side)=>tile[edges[(side+entry.Tile_Orientation)&3]];
 const corner=(entry,side)=>tile[corners[(side+entry.Tile_Orientation)&3]]+':'+(entry.Tile_Height+Number(tile[corners[(side+entry.Tile_Orientation)&3]+'Height']));
 let joins=0;
 for(let y=0;y<area.Height;y++)for(let x=0;x<area.Width;x++){
  const a=area.Tile_List[y*area.Width+x];
  if(x+1<area.Width){const b=area.Tile_List[y*area.Width+x+1];assert.equal(edge(a,1),edge(b,3));assert.equal(corner(a,0),corner(b,3));assert.equal(corner(a,1),corner(b,2));joins++;}
  if(y+1<area.Height){const b=area.Tile_List[(y+1)*area.Width+x];assert.equal(edge(a,0),edge(b,2));assert.equal(corner(a,3),corner(b,2));assert.equal(corner(a,0),corner(b,1));joins++;}
 }
 return joins;
}

async function verifiedTile(){
 const resolver=await openServerResourceContext({install});
 const setBytes=await resolver.getResource('ttr01',2013),set=sections(decodeResourceText(setBytes)),tile=set['TILE'+TILE_ID];
 assert.equal(tile.Model,'ttr01_p03_01');assert.equal(tile.Doors,'0');
 for(const corner of corners){assert.equal(tile[corner],'Grass');assert.equal(tile[corner+'Height'],'0');}
 for(const edge of edges)assert.equal(tile[edge],'');
 const mdl=await resolver.getResource(tile.Model,2002),wok=await resolver.getResource(tile.Model,2016),model=parseModel(mdl),triangles=parseWalkmesh(wok);
 const textures=[...new Set(model.nodes.map(n=>n.bitmap).filter(Boolean))];assert.deepEqual(textures,['TTR01_grass02']);
 const ground=model.nodes.filter(n=>n.bitmap==='TTR01_grass02');assert.equal(ground.length,1);assert.equal(ground[0].verts.length,40);assert.equal(ground[0].faces.length,32);
 assert.ok(ground[0].verts.every(v=>v[2]===0));assert.deepEqual(ground[0].position,[0,0,0]);
 assert.equal(triangles.length,8);assert.ok(triangles.every(t=>t.surfaceType===3&&t.vertices.every(v=>v[1]===0)));
 const area=triangles.reduce((sum,{vertices:[a,b,c]})=>sum+Math.abs((b[0]-a[0])*(c[2]-a[2])-(c[0]-a[0])*(b[2]-a[2]))/2,0);assert.equal(area,100);
 return{resource:'ttr01:2013',sha256:digest(setBytes),id:TILE_ID,fields:tile,model:{resource:tile.Model+':2002',sha256:digest(mdl),texturedGroundVertices:40,texturedGroundFaces:32,textures,groundHeight:0},walkmesh:{resource:tile.Model+':2016',sha256:digest(wok),triangles:8,surface:3,height:0,areaSquareMetres:area}};
}

function patchModule(input){
 const before=Buffer.from(input),entries=parseErf(before).entries,output=Buffer.from(before),changes=[];
 const count=output.readUInt32LE(16),keyAt=output.readUInt32LE(24),resourceAt=output.readUInt32LE(28);assert.equal(count,entries.size);
 for(let i=0;i<count;i++){
  const keyStart=keyAt+i*24,name=output.subarray(keyStart,keyStart+16).toString('ascii').replace(/\0.*$/s,'').toLowerCase(),type=output.readUInt16LE(keyStart+20),key=name+':'+type;
  if(type!==2012)continue;
  assert.ok(['dense_a:2012','dense_b:2012'].includes(key),'Unexpected ARE must not be silently changed');
  const at=output.readUInt32LE(resourceAt+i*8),size=output.readUInt32LE(resourceAt+i*8+4),original=before.subarray(at,at+size),patched=patchArea(original);assert.equal(patched.bytes.length,size);output.set(patched.bytes,at);
  changes.push({resource:key,sha256Before:digest(original),sha256After:digest(patched.bytes),tileCount:100,changedScalarFields:patched.changes.length,changedFields:patched.changes,preservedNonTileBytes:patched.preservedBytes,root:patched.root});
 }
 assert.equal(changes.length,2);
 const after=parseErf(output).entries;for(const[key,bytes]of entries)if(!key.endsWith(':2012'))assert.deepEqual(after.get(key),bytes,key+' must be byte-identical');
 return{bytes:output,changes};
}

export async function prepare(directory){
 const home=owned(directory),base=await prepareBase(home),before=await fs.readFile(path.join(home,'modules/ScriptFloat1.mod')),descriptorBytes=await fs.readFile(path.join(home,'fixture.json'));
 const tile=await verifiedTile(),patched=patchModule(before),beforePath=path.join(home,'flat-grass-before');await fs.mkdir(beforePath);
 await fs.writeFile(path.join(beforePath,'ScriptFloat1.mod'),before,{flag:'wx'});await fs.writeFile(path.join(beforePath,'fixture.json'),descriptorBytes,{flag:'wx'});
 const areas=patched.changes.map(({root,changedFields,...change})=>({...change,joins:compatibleJoins(root,tile.fields),changes:changedFields}));
 const provenance={version:1,kind:'authored-flat-grass-visual-control',sourceModuleSha256:base.moduleSha256,baselinePath:base.baselinePath,baselineSha256:base.baselineSha256,moduleSha256:digest(patched.bytes),tile,fields,areas,unchangedResources:[...parseErf(before).entries].filter(([key])=>!key.endsWith(':2012')).map(([resource,bytes])=>({resource,sha256:digest(bytes)})),scope:'Only private ARE tile ID/orientation/height scalar bytes changed. Objects, scripts, spawn, GIT/IFO and all other resources remain byte-identical to prepared ScriptFloat1. No engine/server/credential/GPU action.'};
 const provenanceBytes=Buffer.from(JSON.stringify(provenance,null,2)+'\n');
 for(const relative of ['modules/ScriptFloat1.mod','client/nwm/ScriptFloat1.nwm'])await fs.writeFile(path.join(home,relative),patched.bytes);
 await fs.writeFile(path.join(home,'flat-grass.json'),provenanceBytes,{flag:'wx'});
 const descriptor={...base,moduleSha256:provenance.moduleSha256,flatGrassControl:{version:1,provenance:'flat-grass.json',sha256:digest(provenanceBytes)}};
 await fs.writeFile(path.join(home,'fixture.json'),JSON.stringify(descriptor,null,2)+'\n');
 return read(home);
}

export async function read(directory){
 const home=owned(directory),base=await readBase(home),descriptor=JSON.parse(await fs.readFile(path.join(home,'fixture.json'),'utf8'));
 assert.deepEqual(Object.keys(descriptor.flatGrassControl??{}).sort(),['provenance','sha256','version']);assert.equal(descriptor.flatGrassControl.version,1);assert.equal(descriptor.flatGrassControl.provenance,'flat-grass.json');
 const bytes=await fs.readFile(path.join(home,'flat-grass.json'));assert.ok(bytes.length<131072);assert.equal(digest(bytes),descriptor.flatGrassControl.sha256);const p=JSON.parse(bytes);assert.equal(p.kind,'authored-flat-grass-visual-control');
 const before=await fs.readFile(path.join(home,'flat-grass-before/ScriptFloat1.mod'));assert.equal(digest(before),p.sourceModuleSha256);
 const oldDescriptor=JSON.parse(await fs.readFile(path.join(home,'flat-grass-before/fixture.json'),'utf8'));assert.equal(oldDescriptor.moduleSha256,p.sourceModuleSha256);assert.equal(oldDescriptor.baselineSha256,base.baselineSha256);
 const expected=patchModule(before),current=await fs.readFile(path.join(home,'modules/ScriptFloat1.mod'));assert.deepEqual(current,expected.bytes);assert.equal(base.moduleSha256,p.moduleSha256);
 const tile=await verifiedTile();assert.deepEqual(p.tile,tile);assert.deepEqual(p.fields,fields);
 const expectedAreas=expected.changes.map(({root,changedFields,...change})=>({...change,joins:compatibleJoins(root,tile.fields),changes:changedFields}));assert.deepEqual(p.areas,expectedAreas);assert.equal(p.areas.reduce((n,a)=>n+a.joins,0),360);
 return{...base,flatGrassControl:{...descriptor.flatGrassControl,tileId:TILE_ID,model:tile.fields.Model,areas:p.areas.map(a=>({resource:a.resource,tileCount:a.tileCount,joins:a.joins,changedScalarFields:a.changedScalarFields})),sourceModuleSha256:p.sourceModuleSha256},fixtureOnly:true};
}

if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url)){
 const verify=process.argv[2]==='--verify',directory=process.argv[verify?3:2];
 (verify?read(directory):prepare(directory)).then(value=>console.log(JSON.stringify(value))).catch(error=>{console.error(error.message);process.exitCode=1;});
}
