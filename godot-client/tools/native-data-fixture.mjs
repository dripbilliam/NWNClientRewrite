// Only authored data is written. JS is an offline oracle, not a runtime helper.
import fs from 'node:fs/promises';
import path from 'node:path';
import {createHash} from 'node:crypto';
import assert from 'node:assert/strict';
import {parseErf,parseKey} from '../../src/resource_archive.js';
import {parseGff} from '../../src/gff.js';
import {writeGff,gffField as f,gffRecord as record} from '../../src/gff_writer.js';
import {parse2da} from '../../src/area.js';
const root=path.resolve('godot-client/reports/native-data-fixture-v1');
await fs.mkdir(root,{recursive:false});
const hash=bytes=>createHash('sha256').update(bytes).digest('hex');
const table='; authored\n2DA V2.0\n\nDEFAULT: "missing value"\n Name Name Value\n9 "quoted ""name""" second 1\n2 other ignored\n9 replacement duplicate 3\n';
const gff=Buffer.from(writeGff('ARE ',record({Byte:f(0,255),Char:f(1,-128),Word:f(2,65535),Short:f(3,-32768),Dword:f(4,0xffffffff),Int:f(5,-2147483648),U64:f(6,18446744073709551615n),I64:f(7,-9007199254740993n),Float:f(8,1.25),Double:f(9,-42.125),Text:f(10,'Caf\xe9 \u20ac\u0001\u0081'),Ref:f(11,'auth_resource'),Loc:f(12,{strRef:123,entries:[{languageId:0,text:'Localized \xe9'},{languageId:1,text:'Other'}]}),Void:f(13,Uint8Array.of(0,1,128,255)),Child:f(14,record({Value:f(5,37)},4)),List:f(15,[record({Name:f(10,'First')},7),record({},8)]),Quaternion:f(16,[0,0,0,1]),Vector:f(17,[1.25,-2.5,3]),StringRef:f(18,0xffffffff)},99)));
const parsed=parseGff(gff).root;
const expected=JSON.parse(JSON.stringify(parsed,(_k,v)=>typeof v==='bigint'?v.toString():v instanceof Uint8Array?[...v]:v));
expected.U64={unsigned64_low:0xffffffff,unsigned64_high:0xffffffff};
expected.Void=[...parsed.Void];
const entries=[{name:'shared',type:2017,bytes:Buffer.from(table)},{name:'auth_area',type:2012,bytes:gff},{name:'empty',type:4,bytes:Buffer.alloc(0)},{name:'unused',type:13,bytes:Buffer.alloc(1024*1024,71)}];
function bif(version){const stride=version==='V1.1'?20:16,start=20+entries.length*stride,result=Buffer.alloc(start+entries.reduce((n,e)=>n+e.bytes.length,0));result.write('BIFF'+version);result.writeUInt32LE(entries.length,8);result.writeUInt32LE(20,16);let cursor=start;entries.forEach((e,i)=>{const at=20+i*stride;result.writeUInt32LE(i,at);const p=at+(stride===20?8:4);result.writeUInt32LE(cursor,p);result.writeUInt32LE(e.bytes.length,p+4);result.writeUInt32LE(e.type,p+8);e.bytes.copy(result,cursor);cursor+=e.bytes.length;});return result;}
function key(version,bifName){const stride=version==='V1.1'?26:22,names=Buffer.from('data/unused.bif\0'+bifName+'\0'),start=64+24+entries.length*stride,result=Buffer.alloc(start+names.length);result.write('KEY '+version);result.writeUInt32LE(2,8);result.writeUInt32LE(entries.length,12);const h=version==='V1.1'?20:16;result.writeUInt32LE(64,h);result.writeUInt32LE(88,h+4);let cursor=start;for(const[i,name]of ['data/unused.bif',bifName].entries()){result.writeUInt32LE(cursor,64+i*12+4);if(version==='V1.1')result.writeUInt32LE(name.length+1,64+i*12+8);else result.writeUInt16LE(name.length+1,64+i*12+8);result.write(name+'\0',cursor);cursor+=name.length+1;}entries.forEach((e,i)=>{const at=88+i*stride;result.write(e.name,at,16);result.writeUInt16LE(e.type,at+16);result.writeUInt32LE(i+(version==='V1.1'?0:0x100000),at+18);if(version==='V1.1')result.writeUInt32LE(0x100000,at+22);});assert.equal(parseKey(result).resources.get('auth_area:2012').bifIndex,1);return result;}
function erf(version,stride){const rows=[{name:'shared',type:2017,bytes:Buffer.from('override')},{name:stride===40?'a_longer_resource_name_over16':'archive_only',type:4,bytes:Buffer.from('archive')}],keys=160,resources=keys+rows.length*stride,start=resources+rows.length*8,result=Buffer.alloc(start+15);result.write('HAK '+version);result.writeUInt32LE(rows.length,16);result.writeUInt32LE(keys,24);result.writeUInt32LE(resources,28);let cursor=start;for(const[i,e]of rows.entries()){const n=stride===40?32:16,at=keys+i*stride;result.write(e.name,at,n);result.writeUInt32LE(i,at+n);result.writeUInt16LE(e.type,at+n+4);result.writeUInt32LE(cursor,resources+i*8);result.writeUInt32LE(e.bytes.length,resources+i*8+4);e.bytes.copy(result,cursor);cursor+=e.bytes.length;}assert.equal(parseErf(result).entries.size,2);return result;}
await fs.mkdir(path.join(root,'data'));
const files={'base.key':key('V1  ','data/base.bif'),'retail.key':key('V1.1','data/retail.bif'),'data/base.bif':bif('V1  '),'data/retail.bif':bif('V1.1'),'override.hak':erf('V1.0',24),'long.hak':erf('V1.1',40),'legacy11.hak':erf('V1.1',24),'area.are':gff};
const corrupt=[];
for(const[kind,source]of [['key','base.key'],['erf','override.hak'],['bif','data/base.bif']]){const name='truncated-'+kind;files[name]=files[source].subarray(0,19);corrupt.push({kind,path:name});}
for(const[kind,source,countAt]of [['key','base.key',12],['erf','override.hak',16],['bif','data/base.bif',8]]){const name='count-'+kind;files[name]=Buffer.from(files[source]);files[name].writeUInt32LE(0xffffffff,countAt);corrupt.push({kind,path:name});}
const traversal=Buffer.from(files['base.key']),nameAt=traversal.readUInt32LE(68);traversal.write('../escape.bif\0',nameAt);files['traversal.key']=traversal;corrupt.push({kind:'key',path:'traversal.key'});
const badGffs=[];for(const offset of [0,8,12,20,28,36,44,52]){const bytes=Buffer.from(gff);bytes.writeUInt32LE(0xffffffff,offset);const name='bad-gff-'+offset;files[name]=bytes;badGffs.push(name);}
for(const[name,bytes]of Object.entries(files))await fs.writeFile(path.join(root,name),bytes,{flag:'wx'});
const two=parse2da(table);
const manifest={scope:'Authored archive/data validation; offline JS oracle, native Godot runtime',root,entries:entries.slice(0,3).map(e=>({name:e.name,type:e.type,sha256:hash(e.bytes),bytes:e.bytes.length})),expectedGff:expected,gffTypes:Object.fromEntries(Object.keys(parsed).map((k,i)=>[k,i])),table,expectedTable:{columns:two.columns,orderedCells:two.orderedCells,defaultValue:two.defaultValue},corrupt,badGffs};
await fs.writeFile(path.join(root,'fixture.json'),JSON.stringify(manifest,null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify({root,files:Object.keys(files).length,resources:entries.length}));
