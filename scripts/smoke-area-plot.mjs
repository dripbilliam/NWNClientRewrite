// Real installed geometry, area route commit and existing native smoothing.
import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import {openLocalModule} from './local-module.mjs';
import {ModuleSession} from '../src/module_session.js';
import {PathInformation} from '../src/path_information.js';
import {plotLiveAreaPath} from '../src/area_path_providers.js';
import {smoothPath} from '../src/path_smoothing.js';
const [install,modulePath,areaName,sx,sy,gx,gy]=process.argv.slice(2),start=[Number(sx),Number(sy)],goal=[Number(gx),Number(gy)];
const s=await new ModuleSession(await openLocalModule(install,modulePath),{runStartupScripts:false,runNativeAI:false,serverPvpSetting:0}).initialize([],{character:await fs.readFile(`${install}/data/lcv/fighter.bic`)});
await s.enterArea(areaName,[start[0],0,-start[1]]);const area=s.currentArea,path=new PathInformation(s.player.id);
path.raw.setInt32(0x60,area.id,true);path.raw.setInt32(0x70,area.id,true);path.raw.setInt32(0x78,0,true);
start.concat(goal).forEach((v,n)=>path.raw.setFloat32([0x64,0x68,0x4c,0x50][n],v,true));
const movement=s.combat.movementProviders(),p={smooth:(area,path)=>smoothPath(area,path,{directLine:movement.testDirectLine})};
let result,passes=0;
do{result=await plotLiveAreaPath(s,area,path,12000,p);passes++;}while(result===1&&passes<100);
assert.equal(result,2,'Installed full area route must commit');assert.ok(path.raw.getInt32(0x7c,true)>=4);
console.log(JSON.stringify({validation:'PASS',start,goal,passes,waypoints:[...path.allocations.get(0x80)],exclusions:path.raw.getInt32(0xcc,true),limits:'Installed area commit and collision/smoothing; not authored AI encounter parity.'}));
