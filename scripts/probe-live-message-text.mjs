import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import {openLocalModule} from './local-module.mjs';
import {ModuleSession} from '../src/module_session.js';
import {NativeServerMessage,NativeMessageReader} from '../src/native_message.js';
import {writeAreaIdentityPrefix} from '../src/area_message_pack.js';
import {playerMessageLanguage,serverMessageLanguage} from '../src/native_message_text.js';
import {encodeGffText,decodeGffText} from '../src/gff_text.js';

const root=process.argv[2]??'../FullDecomp/NwnRootInstall',resolver=await openLocalModule(root,`${root}/data/nwm/Prelude.nwm`),s=await new ModuleSession(resolver,{runStartupScripts:false,runNativeAI:false,serverPvpSetting:0}).initialize([],{character:await fs.readFile(`${root}/data/lcv/wizard.bic`)});
const clients=[{nativePlayerId48:42,nativeLanguage4c:0}],reports=[];
for(const mode of [0,1])for(const area of s.areas.values()){
 const message=new NativeServerMessage(mode),resref=new Uint8Array(17);resref.set(encodeGffText(area.resRef).subarray(0,16));message.create(256,42,1);
 await writeAreaIdentityPrefix(message,area,resref,{server:()=>s,playerLanguage:(_s,id)=>playerMessageLanguage(clients,id),serverLanguage:serverMessageLanguage,warning:()=>assert.fail('Unexpected client-only localized writer')});
 // Explicit captured envelope. This is only the identity prefix of a pack,
 // not a complete Area/ClientArea message and is never sent to a transport.
 message.setPrefix(Uint8Array.of(80,4,1));const packet=message.getWriteMessage(),reader=new NativeMessageReader(mode);
 assert.equal(reader.setReadMessage(packet.data.subarray(3),packet.length-3,42,1),1);
 const value={id:reader.readObjectIdServer(),resref:Buffer.from(reader.readCResRef()).toString('hex'),custom:reader.readBool(),reference:reader.readBool()};
 if(value.reference){value.gender=reader.readByte(1);value.strRef=reader.readDword();}
 else{const text=reader.readCExoString();value.text={hex:text.bytes?Buffer.from(text.bytes).toString('hex'):null,length:text.length,capacity:text.capacity};}
 assert.equal(value.id,area.id);assert.equal(value.resref,Buffer.from(resref).toString('hex'));assert.equal(value.custom,0);
 const embedded=area.nativeName188.entries.find(e=>e.key===0)??area.nativeName188.entries[0];
 if(embedded){assert.equal(value.reference,0);const expected=embedded.bytes[0]===0?new Uint8Array():embedded.bytes;assert.equal(value.text.hex,expected.length?Buffer.from(expected).toString('hex'):null);}
 else if(area.nativeName188.strRef!==0xffffffff){assert.equal(value.reference,1);assert.equal(value.strRef,area.nativeName188.strRef);}
 assert.equal(reader.messageReadOverflow(),0);assert.equal(reader.messageReadUnderflow(),0);
 reports.push({format:mode,areaId:area.id,resRef:area.resRef,displayName:area.name,inlineName:value.text?decodeGffText(value.text.hex?Uint8Array.from(Buffer.from(value.text.hex,'hex')):new Uint8Array()):null,
  packetHex:Buffer.from(packet.data).toString('hex'),definedMaskHex:Buffer.from(packet.defined).toString('hex'),value});
}
const report={playerId:42,controlledObjectId:s.player.id,reports,limits:'Actual installed ARE localized names retained by normal ModuleSession loading, canonical area IDs and resource references through the verified area identity prefix. Explicit fixture language0/PLAYER_ID42/modes0,1; startup and general AI isolated. No full area pack, client receive/ready handshake or actual network send.'};
await fs.writeFile('backups/animations/live-message-text.json',JSON.stringify(report,null,2));console.log(JSON.stringify(report,null,2));
