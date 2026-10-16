import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import {openLocalModule} from './local-module.mjs';
import {ModuleSession} from '../src/module_session.js';
import {NativeServerMessage} from '../src/native_message.js';
import {nativeMessageField} from '../src/area_message_metadata.js';
import {runtimeDiagnostics} from '../src/runtime_diagnostics.js';
import {areaPackCase} from './area-pack-case.mjs';

const root=process.argv[2]??'../FullDecomp/NwnRootInstall',resolver=await openLocalModule(root,`${root}/data/nwm/Prelude.nwm`),s=await new ModuleSession(resolver,{runStartupScripts:false,runNativeAI:false,serverPvpSetting:0}).initialize([],{character:await fs.readFile(`${root}/data/lcv/wizard.bic`)});
const client=s.combat.broadcastProviders().client(s.player.id);client.nativePlayerId48=42;client.nativeLanguage4c=0;const reports=[],cases=[],start=runtimeDiagnostics.records.length;
for(const format of [0,1])for(const area of s.areas.values()){
 const message=new NativeServerMessage(format);message.create(65536,42,1);let error=null,result;
 try{result=await s.areaMessages.pack(message,area,2,-3,4,client,{clients:[client],hasExpansion:()=>1});}catch(e){error=e.message;}
 // Keep every newly reached missing owner visible; do not replace unknown
 // object state with empty records. Expansion support is an explicit fixture.
 assert.equal(error,null);assert.equal(result,1);
 assert.equal(area.nativeMessageTiles.length,area.width*area.height);
 const fields=Object.fromEntries([8,0x98,0xa4,0xa8,0xe3,0xe4,0x104,0x108,0x230,0x330,0x334,0x344].map(offset=>[offset.toString(16),nativeMessageField(area,offset)]));
 const payload=message.getWriteMessage(),packetHex=Buffer.from(payload.data).toString('hex'),definedMaskHex=Buffer.from(payload.defined).toString('hex');
 const observation={result:payload.status,length:payload.length,byteLength:message.byteLength14,bitLength:message.bitLength24,bitOffset:message.bitOffset2c,total:message.total28,byteCapacity:message.byteStorage.bytes.length,bitCapacity:message.bitStorage.bytes.length,writing:message.writing30,flag:message.flag60,playerId:message.playerId64};
 reports.push({format,areaId:area.id,resRef:area.resRef,tiles:area.nativeMessageTiles.length,fields,firstTile:area.nativeMessageTiles[0].nativeMessageFields,packetBytes:payload.length,error,notTransmitted:true});
 cases.push({case:await areaPackCase(s,message,area,client,format),packetHex,definedMaskHex,observation});
}
const failures=runtimeDiagnostics.records.slice(start).filter(record=>record.context.operation==='native-pack-area-message');assert.equal(failures.length,reports.filter(r=>r.error!==null).length);
const report={playerId:42,controlledObjectId:s.player.id,reports,failures,limits:'Normal installed five-area loading and live GIT/ambient/waypoint/sound/placeable/calendar/spatial bindings feed the decoded complete packer. Explicit fixture expansion support/modes0,1/PLAYER_ID42/language0/entryINTs2,-3,4. Full area-pack bodies are produced; they lack the outer ClientArea fields/envelope and are never transmitted. No native ready integration; startup/general AI isolated.'};
await fs.writeFile('backups/animations/live-area-pack.json',JSON.stringify(report,null,2));console.log(JSON.stringify(report,null,2));
await fs.writeFile('backups/animations/live-area-pack-cases.json',JSON.stringify({limits:report.limits,cases},null,2));
