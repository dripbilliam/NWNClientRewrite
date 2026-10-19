import {isNetworkBytes} from './network_bytes.js';
import {NativeMessageReader} from './native_message.js';
import {readServerResourceRequirements} from './network_resources.js';
import {decodeGffText} from './gff_text.js';
import {satisfiesNativeBuild} from './network_build.js';
import {readClientArea} from './network_area.js';
import {readPlayerList} from './network_players.js';
import {readObjectUpdates} from './network_object_updates.js';
import {readNetworkDialog} from './network_dialog.js';
import {readInventoryResponse} from './network_inventory_response.js';
import {readSafeProjectileHeader} from './client_projectile_message.js';
import {readNetworkQuickbar} from './network_quickbar.js';
import {readNetworkParty} from './network_party.js';
import {readNetworkCamera} from './network_camera_message.js';
import {readNetworkObjectVisual,readNetworkAreaVisual} from './network_object_visual.js';
import {readNetworkJournal,readNetworkTiming,readNetworkAttitude,readNetworkMapPin} from './network_hud_messages.js';
import {readNetworkExamine} from './network_examine.js';

// HandlePlayerToServerMessage458b90 requires lowercase p (server replies use
// uppercase P); status45d140 accepts subtype0 with no body.
export const serverStatusRequest=()=>Uint8Array.from([112,1,0]);
// HandlePlayerToServerModuleMessage459760, subtype2, after character loading.
export const moduleReadyRequest=()=>Uint8Array.from([112,3,2]);
// Area handler4435a0 accepts empty subtype3, changes player load state1->2,
// then calls MovePlayerToArea. Module-ready alone does not enter the world.
export const clientAreaReadyRequest=()=>Uint8Array.from([112,4,3]);
const text=reader=>{const value=reader.readCExoString();return value.bytes?decodeGffText(value.bytes):'';};
const ref=reader=>{const bytes=reader.readCResRef(),end=bytes.indexOf(0);return decodeGffText(end<0?bytes:bytes.subarray(0,end));};
function moduleInfo(reader,build){
 if(!build||![build.number,build.revision,build.postfix].every(Number.isInteger))throw new Error('Native client build for module information is unavailable');
 const atLeast=(number,revision,postfix)=>satisfiesNativeBuild(build,{number,revision,postfix});
 const resourceName=text(reader),name=reader.readBool()?{gender:reader.readByte(1),strRef:reader.readDword()}:{text:text(reader)};
 const minutesPerHour=reader.readByte(),entryArea=ref(reader),count=reader.readDword(),areas=[];
 // Every area record requires at least OBJECTID + string length. Bound the loop
 // to the actual byte stream instead of allocating from an untrusted count.
 if(count>Math.floor((reader.byteSize40-reader.byteCursor44)/8))throw new Error('Invalid native module area count');
 for(let i=0;i<count;i++)areas.push({id:reader.readObjectIdClient(),name:text(reader)});
 const officialCampaign=reader.readByte(),serverFlags={field158:reader.readBool(),field164:reader.readBool()};
 if(atLeast(8193,34,0))serverFlags.field168=reader.readBool();if(atLeast(8193,35,0))serverFlags.field16c=reader.readBool();
 return{resourceName,name,minutesPerHour,entryArea,areas,officialCampaign,serverFlags};
}

export function readGameEnvelope(bytes){
 if(!isNetworkBytes(bytes)||bytes.length<3||bytes[0]!==80)throw new Error('Invalid native game-message envelope');
 const owned=Uint8Array.from(bytes);return{major:owned[1],minor:owned[2],body:owned.subarray(3)};
}
// Server sender4dcb50 defines mask-dependent fields. The independently verified
// CNWMessage scalar reader owns byte/bit stream boundaries. This decodes server
// clock changes only; local calendar/AI simulation must not run for this state.
export function decodeServerGameMessage(bytes,{clientBuild=null,objectRules={}}={}){
 const envelope=readGameEnvelope(bytes),{major,minor,body}=envelope;
 if(major===1&&(minor===1||minor===2)){
  if(body.length)throw new Error('Invalid native server availability message');return{kind:minor===1?'server-loading':'server-unavailable',major,minor};
 }
 if(major===2&&(minor===5||minor===16)){
  if(body.length)throw new Error('Invalid native character admission response');return{kind:minor===5?'character-confirmed':'character-needed',major,minor};
 }
 const characterFailure=major===2&&minor===18;
 const moduleMessage=major===3&&minor===1;
 const resourceMessage=major===1&&minor===3;
 const areaMessage=major===4&&minor===1;
 const objectControl=major===5&&minor===2||major===14&&minor===14;
 const playerList=major===10&&[1,2,3].includes(minor);
 const objectUpdates=major===5&&minor===1;
 const dialog=major===20&&[1,2,4,5].includes(minor);
 const inventoryResult=major===12&&minor>=1&&minor<=10;
 if(major===27&&minor>=2&&minor<=6){const errors=[],r=new NativeMessageReader(1,{diagnose:e=>errors.push(e)});if(!r.setReadMessage(body,body.length,0xffffffff,1))throw new Error('Invalid native examination streams');const value=readNetworkExamine(r,minor,clientBuild);if(r.messageReadOverflow()||r.messageReadUnderflow()||errors.length)throw new Error('Invalid native examination fields');return{...value,major,minor};}
 const projectile=major===34&&minor===1;
 const quickbar=major===30&&[1,2].includes(minor);
 const quickChat=major===22&&minor===0;
 const journal=major===28&&[1,2,3,4,5,6,7,8,9,12].includes(minor),timing=major===48&&minor===1,attitude=major===41&&minor===3,mapPin=major===32&&[1,6].includes(minor);
 const partyList=major===14&&[1,3,4].includes(minor);
 const cameraCommand=major===16&&(minor>=1&&minor<=10||minor===12),objectVisual=major===5&&minor===3,areaVisual=major===4&&minor===2;
 if(dialog&&minor===5){if(body.length)throw new Error('Invalid native dialog-close message');return{kind:'dialog-close',major,minor};}
 if(objectUpdates&&body.length===0)throw new Error('Invalid empty native object-update message');
 if(!journal&&!timing&&!attitude&&!mapPin&&!areaVisual&&!objectVisual&&!cameraCommand&&!partyList&&!quickChat&&!quickbar&&!projectile&&!inventoryResult&&!dialog&&!objectUpdates&&!playerList&&!areaMessage&&!objectControl&&!resourceMessage&&!characterFailure&&!moduleMessage&&(major!==3||minor!==3))return{kind:'unsupported',major,minor,length:bytes.length};
 const errors=[],reader=new NativeMessageReader(1,{diagnose:e=>errors.push(e)});
 if(!reader.setReadMessage(body,body.length,0xffffffff,1))throw new Error('Invalid native module-time bit streams');
 if(journal||timing||attitude||mapPin){const value=journal?readNetworkJournal(reader,minor):timing?readNetworkTiming(reader):attitude?readNetworkAttitude(reader):readNetworkMapPin(reader,minor);if(reader.messageReadOverflow()||reader.messageReadUnderflow()||errors.length)throw new Error('Invalid native HUD message fields');return{...value,major,minor};}
 if(cameraCommand){const value=readNetworkCamera(reader,minor);if(reader.messageReadOverflow()||reader.messageReadUnderflow()||errors.length)throw new Error('Invalid native camera fields');return{...value,major,minor};}
 if(areaVisual){const value=readNetworkAreaVisual(reader,clientBuild);if(reader.messageReadOverflow()||reader.messageReadUnderflow()||errors.length)throw new Error('Invalid native area visual fields');return{...value,major,minor};}
 if(objectVisual){const value=readNetworkObjectVisual(reader,clientBuild,objectRules);if(reader.messageReadOverflow()||reader.messageReadUnderflow()||errors.length)throw new Error('Invalid native object visual fields');return{...value,major,minor};}
 if(partyList){const value=readNetworkParty(reader,minor);if(reader.messageReadOverflow()||reader.messageReadUnderflow()||errors.length)throw new Error('Invalid native party-list fields');return{...value,major,minor};}
 if(quickChat){const objectId=reader.readObjectIdClient(),quickChat=reader.readWord();if(reader.messageReadOverflow()||reader.messageReadUnderflow()||errors.length)throw new Error('Invalid native quick-chat fields');return{kind:'quick-chat',major,minor,objectId,quickChat};}
 if(quickbar){const value=readNetworkQuickbar(reader,minor,clientBuild,objectRules);if(reader.messageReadOverflow()||reader.messageReadUnderflow()||errors.length)throw new Error('Invalid native quickbar fields');return{...value,major,minor};}
 if(projectile){const header=readSafeProjectileHeader({overflow:()=>reader.messageReadOverflow(),objectId:()=>reader.readObjectIdClient(),float:(scale,bits)=>reader.readFloat(scale,bits),dword:bits=>reader.readDword(bits),byte:(bits,tag)=>reader.readByte(bits,tag)});if(!header||reader.messageReadOverflow()||reader.messageReadUnderflow()||errors.length)throw new Error('Invalid native projectile fields');return{kind:'safe-projectile',major,minor,header};}
 if(inventoryResult){const value=readInventoryResponse(reader,minor);if(reader.messageReadOverflow()||reader.messageReadUnderflow()||errors.length)throw new Error('Invalid native inventory result');return{...value,major,minor};}
 if(dialog){const value=readNetworkDialog(reader,minor);if(reader.messageReadOverflow()||reader.messageReadUnderflow()||errors.length)throw new Error('Invalid native dialog fields');return{...value,major,minor};}
 if(objectUpdates){const updates=readObjectUpdates(reader,{clientBuild,...objectRules});if(reader.messageReadOverflow()||updates.complete&&reader.messageReadUnderflow()||errors.length)throw new Error('Invalid native object-update fields');return{kind:'object-updates',major,minor,...updates};}
 if(playerList){const list=readPlayerList(reader,minor);if(reader.messageReadOverflow()||reader.messageReadUnderflow()||errors.length)throw new Error('Invalid native player-list fields');return{...list,major,minor};}
 if(areaMessage){const entry=readClientArea(reader,clientBuild);if(reader.messageReadOverflow()||reader.messageReadUnderflow()||errors.length)throw new Error('Invalid native area-information fields');return{kind:'client-area',major,minor,...entry};}
 if(objectControl){const playerId=reader.readDword(),objectId=reader.readObjectIdClient();if(reader.messageReadOverflow()||reader.messageReadUnderflow()||errors.length)throw new Error('Invalid native object-control fields');return{kind:'object-control',major,minor,playerId,objectId};}
 if(moduleMessage){const module=moduleInfo(reader,clientBuild);if(reader.messageReadOverflow()||reader.messageReadUnderflow()||errors.length)throw new Error('Invalid native module-information fields');return{kind:'module-info',major,minor,module};}
 if(characterFailure){const reason=reader.readDword();if(reader.messageReadOverflow()||reader.messageReadUnderflow()||errors.length)throw new Error('Invalid native character rejection fields');return{kind:'character-rejected',major,minor,reason};}
 if(resourceMessage){const requirements=readServerResourceRequirements(reader);if(reader.messageReadOverflow()||reader.messageReadUnderflow()||errors.length)throw new Error('Invalid native server-resource message fields');return{kind:'server-resources',major,minor,requirements};}
 const mask=reader.readByte(),changes={};
 if(mask&1){changes.timeOfDay=reader.readByte();if(changes.timeOfDay===3||changes.timeOfDay===4)changes.transition=reader.readDword();}
 if(mask&2)changes.hour=reader.readByte();if(mask&4)changes.day=reader.readByte();if(mask&8)changes.month=reader.readByte();if(mask&16)changes.year=reader.readDword();
 if(reader.messageReadOverflow()||reader.messageReadUnderflow()||errors.length)throw new Error('Invalid native module-time message fields');
 return{kind:'module-time',major,minor,mask,changes};
}
