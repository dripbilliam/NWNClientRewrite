// Native GUI-client player-list1407a8c60: All replaces the roster silently;
// Add announces the explicit server event; Delete uses the pre-removal record.
// Journal28/12 ->1407a2890 ->1406dab60 -> feedback184, TLK6395 + space + title.
// These describe presentation only; no object, quest or player is manufactured.
export function networkSystemNotices(message,{previousPlayers=new Map(),ready=true}={}){
 if(message.kind==='journal'&&message.operation===12)return[{category:'journal',title:message.title,quest:message.quest,changed:message.changed,strRef:6395,color:'#ffff01',sound:message.changed?'gui_quest_done':'gui_journaladd'}];
 if(message.kind==='player-list-add')return message.players.filter(p=>!p.isDM||message.server140).map(p=>({category:'player',playerId:p.playerId,playerName:p.name,strRef:p.isDM?6611:6610,color:'#bfbfbf',suffix:'.'}));
 if(message.kind==='player-list-delete'){
  const player=previousPlayers.get(message.playerId);if(!ready||!player||player.isDM&&!message.server140)return[];
  return[{category:'player',playerId:player.playerId,playerName:player.name,strRef:player.isDM?6613:6612,color:'#bfbfbf',suffix:'.'}];
 }
 return[];
}
