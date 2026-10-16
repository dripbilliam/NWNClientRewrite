import {nativeAtan2f} from './native_math.js';
import {OBJECT_INVALID} from './game_object_array.js';
import {spellStringEntry} from './spell_metadata.js';
const f=Math.fround,cvtt=n=>{n=f(n);return n>=-2147483648&&n<2147483648?Math.trunc(n)|0:-2147483648;};

// CNWSPlayer::SetAreaTransitionBMP1404be490. User text changes only for1.
export function setAreaTransitionBmp(client,index,text=''){
 index|=0;
 if(index===1)client.nativeUserTransitionBmp28=String(text);
 client.nativeAreaTransitionBmp20=index|0;
}
// CNWSPlayerLastUpdateObject::ClearAutoMapData1404c2ac0. This is the
// client's last-sent single-area buffer, separate from creature exploration.
export function clearLastSentAutomap(lastUpdate){
 lastUpdate.nativeLastSentMapArea178=OBJECT_INVALID;lastUpdate.nativeLastSentMap170=null;
}
// Decoded ReadFLOAT fields from LoadModule140480962..1404809e9; these
// are the module ENTRY coordinates passed as INTs to PackAreaIntoMessage.
export function importAreaPackEntry(module,ifo){
 const entry=module.nativeField108??={};
 for(const [key,name]of [['float14','Mod_Entry_X'],['float18','Mod_Entry_Y'],['float1c','Mod_Entry_Z']]){
  if(Object.hasOwn(ifo,name)&&typeof ifo[name]!=='number')throw new Error(`Native module entry FLOAT ${name} is unavailable`);entry[key]=f(ifo[name]??0);
 }
}
// LoadAreaHeader1403604d4..1403604fb reads WORD, default0.
export function importAreaLoadScreen(area,are){
 if(Object.hasOwn(are,'LoadScreenID')&&!Number.isInteger(are.LoadScreenID))throw new Error('Native ARE loading-screen WORD is unavailable');
 area.nativeLoadScreenId350=(are.LoadScreenID??0)&65535;
}
// C2DA GetCExoStringEntry1401a68f0 returns0 for empty/missing cells,
// copying the table default only when the physical row/column is unavailable.
export function loadingScreenString(table,row,column){
 const rows=table.orderedRows??[...table.rows.values()],available=row>=0&&row<rows.length&&table.columns.some(k=>k.toLowerCase()===column.toLowerCase()),value=spellStringEntry(table,row,column);
 return{status:Number(available&&value.length!==0),value};
}
// Decoded ExecuteCommandSetAreaTransitionBMP14053df30. The scripting
// context selects the client; an uncontrolled NPC cannot alter a player's choice.
export async function scriptSetAreaTransitionBmp([index,text=''],self,p){
 const client=await p.client(self>>>0);if(client)await p.setBmp(client,index|0,String(text));
}
// ResRef/2DA tileset names are ASCII. Avoid inventing CRT locale behavior for
// non-ASCII data; CompareNoCase14016ae00 first compares stored string lengths.
export function sameTilesetName(a,b){
 if(typeof a!=='string'||typeof b!=='string'||/[^\x00-\x7f]/.test(a+b))throw new Error('Native loading-screen tileset comparison is unavailable');
 return a.length===b.length&&a.split('\0')[0].replace(/[A-Z]/g,c=>c.toLowerCase())===b.split('\0')[0].replace(/[A-Z]/g,c=>c.toLowerCase());
}

// SendServerToPlayerArea_ClientArea1404cd9d0..1404ce035. The original
// serialization/area exporter and packet transport remain supplied owners.
// Never interpret this decoded coordinator as a complete wire-protocol claim.
export async function sendClientArea(message,client,area,point,orientation,flag,p){
 const nativePoint=point.map(f);
 const module=await p.module(),mode=await p.serverMode();
 if((mode&65535)!==2||!module)return 0;
 const info=module.nativeField108;
 if(!await p.clientObject(client))return 0;
 if(client.nativeLastUpdateObjectA8)await p.clearLastMap(client.nativeLastUpdateObjectA8);
 if(!area)return 0;
 if(!Number.isInteger(client.nativePlayerId48))throw new Error('Native client PLAYER_ID is unavailable');
 await p.create(message,65536,client.nativePlayerId48,1);
 if(!Number.isInteger(client.nativeAreaTransitionBmp20))throw new Error('Native client loading-screen state is unavailable');
 if(client.nativeAreaTransitionBmp20===-1||client.nativeAreaTransitionBmp20===1){
  if(!Number.isInteger(area.nativeLoadScreenId350))throw new Error('Native ARE loading-screen ID is unavailable');
  await p.setBmp(client,area.nativeLoadScreenId350&65535,'');
 }
 const initialCount=await p.loadingCount();if(!Number.isInteger(initialCount)||initialCount<0)throw new Error('Native loading-screen row count is unavailable');
 if(client.nativeAreaTransitionBmp20>=initialCount)await p.setBmp(client,0,'');
 if(client.nativeAreaTransitionBmp20===0){
  const tileset=p.tileset(area),count=await p.loadingCount();let matches=0,selected=0;
  if(!Number.isInteger(count)||count<0)throw new Error('Native loading-screen row count is unavailable');
  for(let row=2;row<count;row++){
   const result=await p.loadingString(row,'TileSet');if(result.status===1&&sameTilesetName(tileset,result.value))matches++;
  }
  if(matches>0){
   const wanted=(await p.random())%matches;let match=0;
   for(let row=2;row<count;row++){
    const result=await p.loadingString(row,'TILESET');
    if(result.status===1&&sameTilesetName(tileset,result.value)){if(match===wanted)selected=row;match++;}
   }
  }
  if(selected===0){if(count<=2)throw new Error('Native loading-screen random selection divides by zero');selected=(await p.random())%(count-2)+2;}
  if(selected===1)await p.warning('selected');
  await p.writeInt(message,selected,32);
 }else{
  if(client.nativeAreaTransitionBmp20===1)await p.warning('player');
  await p.writeInt(message,client.nativeAreaTransitionBmp20,32);
 }
 await p.setBmp(client,-1,'');
 // Original facing angle is atan2f(Y,X), not the renderer's yaw convention.
 for(const value of [...nativePoint,nativeAtan2f(orientation[1],orientation[0])])await p.writeFloat(message,value,1,32);
 await p.writeBool(message,flag|0);
 if(!info||['float14','float18','float1c'].some(key=>typeof info[key]!=='number'))throw new Error('Native area-pack module field108 is unavailable');
 if(await p.packArea(area,cvtt(info.float14),cvtt(info.float18),cvtt(info.float1c),client)!==1)return 0;
 const payload=await p.payload(message);if(payload.status===0)return 0;
 return await p.send(message,client.nativePlayerId48,4,1,payload.data,payload.length);
}
