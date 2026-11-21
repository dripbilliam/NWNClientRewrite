// Entirely authored original-server fixture. Installed resources are
// referenced by resref; no game binary, scripts or assets are copied.
import fs from 'node:fs/promises';
import path from 'node:path';
import {createHash} from 'node:crypto';
import {openLocalModule} from './local-module.mjs';
import {decodeResourceText} from '../src/resource_archive.js';
import {parseScriptApi,parseNcs} from '../src/ncs.js';
import {parseGff} from '../src/gff.js';
import {OracleScript,writeMod,writeGff,field as f,record as r} from './native-oracle-data.mjs';
const [install,source,output='backups/native-perception-oracle/home/modules/codex_perception_oracle.mod']=process.argv.slice(2);
if(!install||!source)throw new Error('Usage: node scripts/build-perception-oracle.mjs <install> <resolver module> [output]');
const resolver=await openLocalModule(install,source),api=parseScriptApi(decodeResourceText(await resolver.getResource('nwscript',2009)));
const tileset=decodeResourceText(await resolver.getResource('ttr01',2013));
const flat=[...tileset.matchAll(/\[TILE(\d+)\]([\s\S]*?)(?=\[|$)/g)].find(([, ,body])=>
  ['TopLeft','TopRight','BottomLeft','BottomRight'].every(side=>new RegExp(`^${side}=Grass\\s*$`,'m').test(body)&&new RegExp(`^${side}Height=0\\s*$`,'m').test(body))&&
  ['Top','Right','Bottom','Left'].every(side=>new RegExp(`^${side}=\\s*$`,'m').test(body)));
if(!flat)throw new Error('Installed flat grass tile unavailable');
const resources=[],add=(name,type,bytes)=>resources.push([name,type,bytes]);
const gff=(name,type,signature,node)=>{const bytes=writeGff(signature,node);parseGff(bytes,signature);add(name,type,bytes);};
const call=(name,...args)=>({call:name,args}),self={self:true},integer=value=>call('IntToString',value),object=tag=>call('GetObjectByTag',tag,0);
const log=(...parts)=>call('PrintString',{concat:['PERCEPTION_ORACLE ',...parts,' second=',integer(call('GetTimeSecond'))]});
const script=(name,body)=>{const code=new OracleScript(api);body(code);const bytes=code.finish();parseNcs(bytes,name);add(name,2010,bytes);};
script('po_load',code=>{code.statement(log('LOAD'));for(const tag of ['po_observer','po_target'])code.statement(call('ExecuteScript','po_spawn',object(tag)));});
script('po_spawn',code=>{code.statement(call('SetAILevel',self,4));code.statement(log('SPAWN tag=',call('GetTag',self),' hide=',integer(call('GetSkillRank',5,self,0)),' spot=',integer(call('GetSkillRank',17,self,0))));});
script('po_notice',code=>code.statement(log('NOTICE target=',call('GetTag',call('GetLastPerceived')),
  ' heard=',integer(call('GetLastPerceptionHeard')),' seen=',integer(call('GetLastPerceptionSeen')),
  ' inaudible=',integer(call('GetLastPerceptionInaudible')),' vanished=',integer(call('GetLastPerceptionVanished')),
  ' cached_seen=',integer(call('GetObjectSeen',call('GetLastPerceived'),self)),' cached_heard=',integer(call('GetObjectHeard',call('GetLastPerceived'),self)))));
script('po_beat',code=>{
  const count=()=>call('GetLocalInt',self,'phase');code.statement(call('SetLocalInt',self,'phase',{add:[count(),1]}));
  const jump=x=>call('JumpToLocation',call('Location',call('GetArea',self),call('Vector',{float:x},{float:5},{float:0}),{float:0}));
  // Four stable phases: nearby, far, nearby, far. Native perception chooses
  // its own update time; no visibility flags or RNG seeds are injected.
  code.ifThen({ge:[count(),4]},()=>{code.statement(log('FAR_FINAL'));code.statement(jump(45));},()=>{
    code.ifThen({ge:[count(),3]},()=>{code.statement(log('NEAR'));code.statement(jump(6));},()=>{
      code.ifThen({ge:[count(),2]},()=>{code.statement(log('FAR'));code.statement(jump(45));});
    });
  });
});
const creature=(tag,x)=>r({TemplateResRef:f(11,tag),Tag:f(10,tag),FirstName:f(12,tag),LastName:f(12,''),Appearance_Type:f(2,1),Gender:f(0,0),Race:f(0,6),Phenotype:f(5,0),
  FactionID:f(2,1),Str:f(0,10),Dex:f(0,10),Con:f(0,10),Int:f(0,10),Wis:f(0,10),Cha:f(0,10),
  HitPoints:f(3,20),CurrentHitPoints:f(3,20),MaxHitPoints:f(3,20),NaturalAC:f(0,0),ClassList:f(15,[r({Class:f(5,4),ClassLevel:f(3,1)},2)]),
  SkillList:f(15,Array.from({length:27},()=>r({Rank:f(0,0)},0))),FeatList:f(15,[]),Equip_ItemList:f(15,[]),ItemList:f(15,[]),SpecAbilityList:f(15,[]),VarTable:f(15,[]),
  GoodEvil:f(0,50),LawfulChaotic:f(0,50),IsPC:f(0,0),IsImmortal:f(0,1),Plot:f(0,0),BodyBag:f(0,0),WalkRate:f(5,0),Interruptable:f(0,1),DecayTime:f(4,5000),PerceptionRange:f(0,8),
  ScriptSpawn:f(11,'po_spawn'),ScriptOnNotice:f(11,tag==='po_observer'?'po_notice':''),ScriptHeartbeat:f(11,tag==='po_target'?'po_beat':''),
  XPosition:f(8,x),YPosition:f(8,5),ZPosition:f(8,0),XOrientation:f(8,1),YOrientation:f(8,0)},4);
const actors=[creature('po_observer',5),creature('po_target',6)];for(const actor of actors)gff(actor.fields.Tag.value,2027,'UTC ',actor);
gff('po_arena',2023,'GIT ',r({'Creature List':f(15,actors),'Door List':f(15,[]),'Placeable List':f(15,[]),'TriggerList':f(15,[]),WaypointList:f(15,[]),StoreList:f(15,[]),'Encounter List':f(15,[]),SoundList:f(15,[])}));
gff('po_arena',2012,'ARE ',r({Tag:f(10,'po_arena'),Name:f(12,'Owned Perception Oracle'),Tileset:f(11,'ttr01'),Width:f(5,5),Height:f(5,1),Flags:f(4,0),ID:f(5,0),Version:f(4,1),PlayerVsPlayer:f(0,0),
  Tile_List:f(15,Array.from({length:5},()=>r({Tile_ID:f(5,Number(flat[1])),Tile_Height:f(5,0),Tile_Orientation:f(5,0),Tile_MainLight1:f(0,0),Tile_MainLight2:f(0,0),Tile_SrcLight1:f(0,0),Tile_SrcLight2:f(0,0),Tile_AnimLoop1:f(0,0),Tile_AnimLoop2:f(0,0),Tile_AnimLoop3:f(0,0)},1)))}));
gff('po_arena',2046,'GIC ',r({CreatureList:f(15,[])}));
gff('module',2014,'IFO ',r({Mod_Name:f(12,'Owned Perception Oracle'),Mod_Tag:f(10,'codex_perception_oracle'),Mod_Description:f(12,'Authored research fixture'),Mod_Area_list:f(15,[r({Area_Name:f(11,'po_arena')},6)]),
  Mod_MinGameVer:f(10,'1.69'),Mod_Creator_ID:f(5,0),Mod_IsSaveGame:f(0,0),Mod_ID:f(13,Buffer.alloc(16,2)),
  Mod_Entry_Area:f(11,'po_arena'),Mod_Entry_X:f(8,2),Mod_Entry_Y:f(8,2),Mod_Entry_Z:f(8,0),Mod_Entry_Dir_X:f(8,1),Mod_Entry_Dir_Y:f(8,0),Mod_MinPerHour:f(0,2),Mod_DawnHour:f(0,6),Mod_DuskHour:f(0,18),Mod_StartHour:f(0,12),Mod_StartDay:f(0,1),Mod_StartMonth:f(0,1),Mod_StartYear:f(5,1372),Mod_XPScale:f(0,100),Mod_Version:f(4,3),VarTable:f(15,[]),Mod_HakList:f(15,[]),Mod_CustomTlk:f(10,''),Mod_OnModLoad:f(11,'po_load'),Mod_OnModStart:f(11,''),Mod_OnClientEntr:f(11,'')}));
gff('repute',2038,'FAC ',r({FactionList:f(15,['PC','Observers'].map((name,i)=>r({FactionName:f(10,name),FactionParentID:f(4,i?0:0xffffffff),FactionGlobal:f(0,1)},0))),
  RepList:f(15,Array.from({length:4},(_,index)=>r({FactionID1:f(4,index%2),FactionID2:f(4,Math.floor(index/2)),FactionRep:f(4,100)},1)))}));
const bytes=writeMod(resources);await fs.mkdir(path.dirname(output),{recursive:true});await fs.writeFile(output,bytes);
console.log(JSON.stringify({output,bytes:bytes.length,sha256:createHash('sha256').update(bytes).digest('hex'),resources:resources.map(([name,type])=>({name,type})),flatTile:Number(flat[1])}));
