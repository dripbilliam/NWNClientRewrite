import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import {openLocalModule} from './local-module.mjs';
import {ModuleSession} from '../src/module_session.js';
import {GameText,parseTalkTable} from '../src/talk_table.js';
import {runtimeDiagnostics} from '../src/runtime_diagnostics.js';
const install=process.argv[2]??'../FullDecomp/NwnRootInstall',output=process.argv[3]??'backups/animations/installed-initial-map-pins-v1.json',report={areas:[]};
try{
 const s=await new ModuleSession(await openLocalModule(install,`${install}/data/nwm/Prelude.nwm`),{runStartupScripts:false,runNativeAI:false,serverPvpSetting:0,onCombatMessage:()=>{}}).initialize([],{character:await fs.readFile(`${install}/data/lcv/wizard.bic`)});
 s.mapPins.text=new GameText({base:parseTalkTable(await fs.readFile(`${install}/lang/en/data/dialog.tlk`))});report.loadDiagnostics=[...runtimeDiagnostics.records];const begin=runtimeDiagnostics.records.length,cursor=s.registry.nextObjectId[0];
 for(const area of s.areas.values()){
  s.scheduler.events=[];await s.enterArea(area.resRef,[4,0,-4]);const scene=s.mapPins.scene;assert.ok(scene?.initialLoaded);assert.equal(scene.areaId,area.id);assert.equal(scene.clientObjectId,s.player.id);
  const expected=[...area.nativeSpatial.view()].map(id=>s.registry.get(id)).filter(o=>o?.objectType===12&&o.nativeMessageFields[0x308]!==0),pins=scene.nativeMapPins2b8;
  assert.deepEqual(pins.map(o=>o.nativeReference188),expected.map(o=>(o.id|0x80000000)>>>0));assert.ok(pins.every(o=>o.nativeType18c===0));assert.deepEqual(pins.map(o=>o.nativeEnabled170),expected.map(o=>o.nativeMessageFields[0x30c]&1));assert.equal(s.registry.nextObjectId[0],cursor);
  report.areas.push({id:area.id,resRef:area.resRef,pins:pins.map(o=>({reference:o.nativeReference188,type:o.nativeType18c,enabled:o.nativeEnabled170,position:o.nativePosition38,text:new TextDecoder('windows-1252').decode(o.nativeText178)}))});
 }
 const area=s.currentArea,locals=s.player.locals;locals.setInt('NW_TOTAL_MAP_PINS',2);
 for(const[index,text,areaId]of[[0,'Zero index note',area.id],[1,'Wrong area note',0x123456],[2,'Inclusive upper note',area.id],[3,'Beyond total note',area.id]]){
  locals.setString(`NW_MAP_PIN_NTRY_${index}`,text);locals.setObject(`NW_MAP_PIN_AREA_${index}`,areaId);for(const[axis,value]of[['X',10+index],['Y',20+index],['Z',3]])locals.setFloat(`NW_MAP_PIN_${axis}POS_${index}`,value);
 }
 const original=s.mapPins.scene;await s.mapPins.loadArea({force:true});assert.notEqual(s.mapPins.scene,original);const users=s.mapPins.scene.nativeMapPins2b8.filter(p=>p.nativeType18c===1);assert.deepEqual(users.map(p=>p.nativeReference188),[0,2]);assert.deepEqual(users.map(p=>p.nativeEnabled170),[1,1]);assert.deepEqual(users.map(p=>p.nativePosition38),[[10,20,3],[12,22,3]]);report.userPins=users.map(p=>({reference:p.nativeReference188,position:p.nativePosition38,text:new TextDecoder('windows-1252').decode(p.nativeText178)}));
 const same=await s.mapPins.loadArea();assert.equal(same,s.mapPins.scene);assert.equal(s.registry.nextObjectId[0],cursor);assert.equal(s.mapPins.loading,null);
 report.cursor=cursor;report.diagnostics=runtimeDiagnostics.records.slice(begin);assert.deepEqual(report.diagnostics.filter(r=>r.severity==='error'),[]);report.validation='PASS';report.limits='Installed Prelude all areas, actual area-entry client scene loads, canonical waypoint ordering/external wire IDs/enabled low bits, real base TLK, no extra canonical allocations. RAM-only player-local variables exercise index0 and inclusive upper2, wrong area/beyond-total filtering, string/position/type1 state and forced reload. Separate local body writer/reader section, not full client Area packet/scene loading, map bitmap/viewport/pin GUI parity or campaign completion.';
}catch(error){report.failure={message:error.message,stack:error.stack};report.diagnostics=[...runtimeDiagnostics.records];}
await fs.writeFile(output,JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify({validation:report.validation,areas:report.areas.map(a=>({area:a.resRef,pins:a.pins.length})),userPins:report.userPins,cursor:report.cursor,failure:report.failure}));if(report.failure)process.exitCode=1;
