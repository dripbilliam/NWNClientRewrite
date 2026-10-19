const configKey='server.log.debug-mode-sends-to-players.enabled';
const cString=value=>{if(typeof value!=='string')throw new Error('Native script log string is unavailable');return value.split('\0')[0];};
const call=(p,name,...args)=>{if(typeof p?.[name]!=='function')throw new Error(`Native script log provider ${name} is unavailable`);return p[name](...args);};

// CExoDebugInternal::GetCurrentTimestamp140165230..140165335 uses local
// ctime64 and "%.19s". Keep its C-locale names, space-padded day and seconds;
// the diagnostic journal's independent ISO timestamp is not a substitute.
export function scriptLogTimestamp(date){
 if(!(date instanceof Date)||!Number.isFinite(date.getTime()))throw new Error('Native script log wall clock is unavailable');
 const weekdays=['Sun','Mon','Tue','Wed','Thu','Fri','Sat'],months=['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'],two=n=>String(n).padStart(2,'0');
 return `${weekdays[date.getDay()]} ${months[date.getMonth()]} ${String(date.getDate()).padStart(2,' ')} ${two(date.getHours())}:${two(date.getMinutes())}:${two(date.getSeconds())}`;
}

// Complete ExecuteCommandPrintLogEntry1405397b0..140539a61. Mandatory typed
// pop precedes every side effect. Logger always runs; only the player echo is
// gated. Capture count once, but read each live pointer in native list order.
export async function scriptLogEntry(p){
 const read=call(p,'pop','string');if(!read.ok)return -639;
 const text=cString(read.value),timestamp=cString(call(p,'timestamp'));
 call(p,'log',`[${timestamp}] ${text}\n`,{flags:[1,2],function:'ExecuteCommandPrintLogEntry',file:'game\\servercore\\nwsvmachinecommands.cpp',line:0x62bf,format:'[%s] %s\n',timestamp,text});
 const mode=call(p,'debugMode');if(!Number.isInteger(mode))throw new Error('Native server debug mode is unavailable');
 if((mode|0)!==0&&call(p,'configBool',configKey,false)){
  const formatted=`[ServerLog:${timestamp}] ${text}`,list=call(p,'players');
  if(!Number.isInteger(list?.count)||!Array.isArray(list.entries))throw new Error('Native script log player list is unavailable');
  const count=list.count|0;
  for(let index=0;index<count;index++){
   const player=list.entries[index],message=call(p,'message');
   await call(p,'send',message,player,formatted); // native ignores send result
  }
 }
 return 0;
}

// Complete CNWSMessage::SendServerToPlayerDebugInfo_String1404d5ce0..5da3.
// Message/string codec and transport remain explicit, independently checked
// lower boundaries. Copy the by-value string; never consume the caller's data.
export function writeDebugInfoString(message,string,p){
 if(!(string?.bytes instanceof Uint8Array)||!Number.isInteger(string.length)||string.length<0||string.length>string.bytes.length)throw new Error('Native debug string storage is unavailable');
 call(p,'create',message,(string.length+4)>>>0,0xffffffff,1);
 const copied=call(p,'copyString',string);call(p,'writeString',message,copied,32);
 return call(p,'payload',message);
}
export async function sendDebugInfoString(message,player,string,p){
 const payload=writeDebugInfoString(message,string,p);if(!payload.status)return 0;
 return call(p,'transport',message,call(p,'playerId',player),33,5,payload.data,payload.length);
}
