// Schema knowledge belongs to the existing received player-list owner. This
// module stores no roster and never equates controlled IDs with selected PCs.
const uint=value=>Number.isInteger(value)&&value>=0&&value<=0xffffffff;
const bool=value=>value===true||value===false||value===0||value===1;
const object=value=>value!==null&&typeof value==='object'&&!Array.isArray(value);
function localized(value){return object(value)&&(typeof value.text==='string'||uint(value.strRef)&&bool(value.gender));}
export function playerRosterEntryComplete(value){
 if(!object(value)||!uint(value.playerId)||!uint(value.objectId)||!bool(value.isDM)||typeof value.name!=='string'||!Number.isInteger(value.peerD8)||value.peerD8<0||value.peerD8>255||typeof value.peerC8!=='string')return false;
 if(!Object.hasOwn(value,'character'))return true; // complete wire schema's hasCharacter=false
 const c=value.character;return object(c)&&uint(c.id)&&localized(c.firstName)&&localized(c.lastName)&&Number.isInteger(c.portrait)&&c.portrait>=0&&c.portrait<=65535&&(c.portrait<65534||typeof c.portraitRef==='string');
}
export function stagePlayerRoster(message){
 if(!['player-list-all','player-list-add'].includes(message?.kind)||!Array.isArray(message.players))throw Error('Invalid native player roster');
 const rows=message.players.map(value=>{if(!object(value)||!uint(value.playerId)||!uint(value.objectId))throw Error('Invalid native player identity');return structuredClone(value);});
 const complete=message.kind==='player-list-all'&&rows.length<=255&&bool(message.server140)&&rows.every(playerRosterEntryComplete)&&new Set(rows.map(row=>row.playerId)).size===rows.length;
 return{rows,complete};
}
// Private host serialization view: same existing O(players) array conversion,
// no extra deep copy or second store. JSON framing detaches it before delivery.
export function playerRosterHeader(world){return{gameMasterPermission:world.gameMasterPermission,players:[...world.players],playerRosterKnown:world.playerRosterKnown};}
