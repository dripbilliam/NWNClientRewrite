// Authored native-server fixture, staging only. No game reads, server/client
// launches, credentials, installed-file changes or renderer performance claims.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
import {fileURLToPath} from 'node:url';
import {gffField as field,gffRecord as record,writeGff} from '../../../../src/gff_writer.js';
import {parseGff,getGffFieldTypes} from '../../../../src/gff.js';
import {parseErf} from '../../../../src/resource_archive.js';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..');
const label=process.argv[2];
if(process.argv.length!==3||!/^base-reuse-fixture-[a-z0-9-]+$/.test(label??''))throw Error('Use one fresh base-reuse-fixture-* label');
const folder=path.join(project,'.cache/native-presentation-parity/root',label);
if(fs.existsSync(folder))throw Error('Existing fixture preserved');
const hash=b=>crypto.createHash('sha256').update(b).digest('hex');
const B=x=>field(0,x),W=x=>field(2,x),D=x=>field(4,x),I=x=>field(5,x),F=x=>field(8,x),S=x=>field(10,x),R=x=>field(11,x),T=x=>field(12,x),L=x=>field(15,x);
const r=(x,type=0xffffffff)=>record(x,type),empty=()=>L([]);
const moduleName='BaseReuse1',areaKeys=['reuse_a','reuse_b'],appearances=[7,8,9,10];
function area(key){return r({
 Tag:S(key),Name:T('Authored Base Reuse '+key.at(-1)),ResRef:R(key),Version:D(88),Flags:D(0),Creator_ID:I(0),ID:I(0),Comments:S('Small functional reuse fixture; not a performance benchmark'),Expansion_List:empty(),
 Width:I(8),Height:I(8),Tileset:R('ttr01'),DayNightCycle:B(0),IsNight:B(0),SunAmbientColor:D(0x777777),SunDiffuseColor:D(0xdddddd),SunFogAmount:B(0),SunFogColor:D(0),SunShadows:B(0),MoonAmbientColor:D(0x777777),MoonDiffuseColor:D(0),MoonFogAmount:B(0),MoonFogColor:D(0),MoonShadows:B(0),LightingScheme:B(0),ShadowOpacity:B(50),ChanceRain:I(0),ChanceSnow:I(0),ChanceLightning:I(0),WindPower:I(0),PlayerVsPlayer:B(3),NoRest:B(0),LoadScreenID:W(0),OnEnter:R(''),OnExit:R(''),OnHeartbeat:R(''),OnUserDefined:R(''),
 Tile_List:L(Array.from({length:64},(_,i)=>r({Tile_ID:I(50),Tile_Orientation:I(i%4),Tile_Height:I(0),Tile_MainLight1:B(0),Tile_MainLight2:B(0),Tile_SrcLight1:B(0),Tile_SrcLight2:B(0),Tile_AnimLoop1:B(1),Tile_AnimLoop2:B(1),Tile_AnimLoop3:B(1)},1))),
});}
function git(key){const other=areaKeys.find(x=>x!==key);return r({
 AreaProperties:field(14,r({AmbientSndDay:I(0),AmbientSndNight:I(0),AmbientSndDayVol:I(0),AmbientSndNitVol:I(0),EnvAudio:I(0),MusicBattle:I(0),MusicDay:I(0),MusicNight:I(0),MusicDelay:I(0)},100)),
 'Creature List':empty(),'Door List':empty(),'Encounter List':empty(),List:empty(),SoundList:empty(),StoreList:empty(),
 'Placeable List':L(Array.from({length:128},(_,i)=>r({Tag:S(`${key}_prop_${i}`),LocName:T(`Authored static ${i}`),Description:T('Authored static non-useable fixture object'),TemplateResRef:R(''),Appearance:D(appearances[i%appearances.length]),X:F(10+i%16*3),Y:F(10+Math.floor(i/16)*3),Z:F(0),Bearing:F(0),Static:B(1),Useable:B(0),HasInventory:B(0),Plot:B(1),HP:field(3,20),CurrentHP:field(3,20),Hardness:B(5),Faction:D(2),AnimationState:B(0),InventoryList:empty()},9))),
 WaypointList:L([r({Appearance:B(1),Tag:S(`entry_${key}`),LocalizedName:T('Clear fixture entry'),TemplateResRef:R(''),LinkedTo:S(''),Description:T(''),HasMapNote:B(0),MapNote:T(''),MapNoteEnabled:B(0),XPosition:F(50),YPosition:F(50),ZPosition:F(0),XOrientation:F(0),YOrientation:F(1)},5)]),
 TriggerList:L([r({Tag:S(`exit_${key}`),TemplateResRef:R(''),LocalizedName:T('Other fixture area'),Type:I(1),Faction:D(2),Cursor:B(1),HighlightHeight:F(0),LinkedTo:S(`entry_${other}`),LinkedToFlags:B(2),LoadScreenID:W(0),TrapFlag:B(0),XPosition:F(70),YPosition:F(70),ZPosition:F(0),XOrientation:F(0),YOrientation:F(0),ZOrientation:F(0),Geometry:L([[-2,-1],[2,-1],[2,1],[-2,1]].map(([x,y])=>r({PointX:F(x),PointY:F(y),PointZ:F(0)},3)))},1)]),
});}
const ifo={Mod_ID:field(13,crypto.createHash('sha256').update('Authored BaseReuse1 v1').digest().subarray(0,16)),Mod_MinGameVer:S('1.77'),Mod_Creator_ID:I(0),Mod_Version:D(3),Expansion_Pack:W(3),Mod_Name:T('Authored Base Reuse'),Mod_Tag:S(moduleName),Mod_Description:T('Two small functional streaming areas; 128 authored static props each'),Mod_IsSaveGame:B(0),Mod_CustomTlk:S(''),Mod_Entry_Area:R(areaKeys[0]),Mod_Entry_X:F(50),Mod_Entry_Y:F(50),Mod_Entry_Z:F(0),Mod_Entry_Dir_X:F(0),Mod_Entry_Dir_Y:F(1),Mod_Expan_List:empty(),Mod_DawnHour:B(6),Mod_DuskHour:B(18),Mod_MinPerHour:B(2),Mod_StartMonth:B(6),Mod_StartDay:B(1),Mod_StartHour:B(13),Mod_StartYear:D(1372),Mod_XPScale:B(10),Mod_StartMovie:R(''),Mod_CutSceneList:empty(),Mod_GVar_List:empty(),Mod_Area_list:L(areaKeys.map(key=>r({Area_Name:R(key)},6))),Mod_HakList:empty(),Mod_CacheNSSList:empty()};
for(const name of ['Mod_OnHeartbeat','Mod_OnModLoad','Mod_OnModStart','Mod_OnClientEntr','Mod_OnClientLeav','Mod_OnActvtItem','Mod_OnAcquirItem','Mod_OnUsrDefined','Mod_OnUnAqreItem','Mod_OnPlrDeath','Mod_OnPlrDying','Mod_OnPlrEqItm','Mod_OnPlrLvlUp','Mod_OnSpawnBtnDn','Mod_OnPlrRest','Mod_OnPlrUnEqItm','Mod_OnCutsnAbort','Mod_OnPlrChat'])ifo[name]=R('');
const entries=[['module',2014,writeGff('IFO ',r(ifo))]];
for(const key of areaKeys)entries.push([key,2012,writeGff('ARE ',area(key))],[key,2023,writeGff('GIT ',git(key))]);
const count=entries.length,keys=160,resources=keys+count*24,data=resources+count*8;
const bytes=Buffer.alloc(data+entries.reduce((n,e)=>n+e[2].length,0));
bytes.write('MOD V1.0');bytes.writeUInt32LE(count,16);bytes.writeUInt32LE(160,20);bytes.writeUInt32LE(keys,24);bytes.writeUInt32LE(resources,28);
let cursor=data;for(const[i,[name,type,value]]of entries.entries()){assert.ok(name.length<=16);bytes.write(name,keys+i*24,16,'ascii');bytes.writeUInt32LE(i,keys+i*24+16);bytes.writeUInt16LE(type,keys+i*24+20);bytes.writeUInt32LE(cursor,resources+i*8);bytes.writeUInt32LE(value.length,resources+i*8+4);bytes.set(value,cursor);cursor+=value.length;}
const archive=parseErf(bytes);assert.equal(archive.entries.size,5);
for(const key of areaKeys){
 const a=parseGff(archive.entries.get(`${key}:2012`),'ARE ').root;assert.equal(a.Tile_List.length,64);
 const g=parseGff(archive.entries.get(`${key}:2023`),'GIT ').root;assert.equal(g['Placeable List'].length,128);
 const tags=new Set();for(const p of g['Placeable List']){assert.equal(p.Static,1);assert.equal(p.Useable,0);assert.equal(p.HasInventory,0);assert.equal(getGffFieldTypes(p).Static,0);assert.equal(getGffFieldTypes(p).Appearance,4);assert.ok(appearances.includes(p.Appearance));assert.ok(p.Y<=31);tags.add(p.Tag);}assert.equal(tags.size,128);
 assert.equal(g.TriggerList[0].LinkedTo,`entry_${areaKeys.find(x=>x!==key)}`);assert.equal(g.WaypointList[0].YPosition,50);
}
const reference=path.resolve(project,'../scripts/create-dense-server-fixture.mjs');
fs.mkdirSync(path.join(folder,'module'),{recursive:true});
const files=[path.join(folder,'module',moduleName+'.mod'),path.join(folder,'module',moduleName+'.nwm')];
for(const file of files)fs.writeFileSync(file,bytes,{flag:'wx'});
const report={version:1,kind:'authored-live-reuse-functional-fixture-stage',module:moduleName,areas:areaKeys,tilesPerArea:64,staticNonUseablePropsPerArea:128,appearanceRows:appearances,minimumBaseWavesAt64Rows:2,clearEntry:[50,50,0],transitionCenters:[70,70,0],files:files.map(file=>({file,sha256:hash(bytes),bytes:bytes.length})),builder:{file:fileURLToPath(import.meta.url),sha256:hash(fs.readFileSync(fileURLToPath(import.meta.url)))},shapeReference:{file:reference,sha256:hash(fs.readFileSync(reference))},authoredArchiveRoundtrip:true,nativeServerValidated:false,installedAppearanceModelsValidated:false,serverStarted:false,clientStarted:false,credentialsRead:false,installedContentCopied:false,profileFilesChanged:false,performanceAccepted:false,limits:['Only format/field/count checks ran; no original executable or native resource resolution.','Must validate native base model rows and actual received static metadata before relying on positive cache counts.','Fixture is for live-catalog/lifecycle behavior, not representative loading/FPS measurements.','No server profile/module was installed or switched; Prelude remains untouched.']};
fs.writeFileSync(path.join(folder,'fixture.json'),JSON.stringify(report,null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify({folder,module:moduleName,areas:2,staticPerArea:128,roundtrip:true,nativeServerValidated:false,serverStarted:false,sha256:hash(bytes)}));
