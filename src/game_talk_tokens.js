import {scriptStringBytes} from './script_string.js';
import {talkTokenHash} from './talk_tokens.js';
import {intEntry} from './combat_stats.js';
const integer=(value,name)=>{if(!Number.isInteger(value))throw new Error(`Native named-token ${name} is unavailable`);return value|0;};
const text=value=>{if(!(value instanceof Uint8Array))throw new Error('Native named-token bytes are unavailable');return value[0]===0?new Uint8Array():Uint8Array.from(value);};
const decimal=value=>scriptStringBytes(String(value|0));
// Client alignment STRREF leaf1407ef2f0: signed WORD scores, separate native
// uppercase/lowercase reference grids. These are engine text constants.
export function clientTokenAlignmentRef(law,good,lower){
 const bucket=value=>{value=(integer(value,'alignment score')<<16)>>16;return value<31?2:value>69?0:1;};return(lower?0x1351:0x70)+bucket(law)*3+bucket(good);
}
// OpenFile1999a0 uses physical columns0..6 and hashes only the first16 bytes.
export function loadNamedTalkTokens(table){
 if(!Array.isArray(table?.orderedRows)||!Array.isArray(table.columns))throw new Error('Native StringTokens table is unavailable');
 const records=table.orderedRows.map((row,index)=>{const name=scriptStringBytes(row[table.columns[0]]==='****'?'':row[table.columns[0]]??''),read=column=>{const result=intEntry(table,index,table.columns[column]);if(!result.found)throw new Error(`Native StringTokens numeric field import is unavailable at row${index}/column${column}`);return result.value|0;};return{sourceRow:index,name,hash:talkTokenHash(name,16),action:read(1),defaultRef:read(2),refs:[3,4,5,6].map(read)};});
 return records.sort((a,b)=>a.hash-b.hash);
}
// Game-derived token callback140704d40..705759. Client object/stats/rule/text
// getters are lower providers; physical flags and shared gender stay explicit.
export function gameTalkTokenValue(token,state,p){
 const action=integer(token.action,'action'),fetch=ref=>text(p.fetch(ref>>>0));
 if(action===0)return fetch(token.refs[0]);
 if(action===1){const g=integer(state.gender,'gender')&255;if(g>=token.refs.length)throw new Error('Native named-token gender indexes unknown row storage');return fetch(token.refs[g]);}
 if(action>=2&&action<=14||action===24){
  const context=p.context();if(!context)return fetch(token.defaultRef);
  if(!p.object(context))return scriptStringBytes('NO OBJECT');
  const creature=p.creature(context);if(!creature)return fetch(token.defaultRef);
  const stats=p.stats(creature);if(!stats)return scriptStringBytes('NO STATS');
  const gender=state.gender;let result;
  switch(action){
   case 2:result=p.fullName(stats);break;
   case 3:{const first=text(p.firstName(stats));result=first.length?first:p.lastName(stats);break;}
   case 4:{const last=text(p.lastName(stats));result=last.length?last:p.firstName(stats);break;}
   case 5:case 6:result=p.raceName(stats,action===6);break;
   case 7:result=p.subrace(stats);break;
   case 8:case 9:result=p.className(stats,action===9);break;
   case 10:result=decimal(integer(p.classLevel(stats),'first class level')&255);break;
   case 11:case 12:result=p.alignment(stats,action===12);break;
   case 13:case 14:{const score=(integer(p.alignmentScore(stats,action===13),'alignment score')<<16)>>16;result=fetch(token.refs[score<31?2:score>69?0:1]);break;}
   case 24:result=p.deity(stats);break;
  }state.gender=gender;return text(result);
 }
 if(action>=15&&action<=18){const world=p.world();
  if(action===15)return decimal(integer(world.native160,'world160'));
  if(action===17)return decimal(integer(world.native164,'world164'));
  const value=integer(world.native16c,'world16c')>>>0;
  if(action===16)return decimal((((value+11)>>>0)%12)+1); // native constant24/2
  const first=integer(world.native17c,'world17c')&255,last=integer(world.native17d,'world17d')&255,index=value<first||value>last?0:Math.floor((value-first)*3/(last-first+1))+1;return fetch(token.refs[index]);
 }
 if(action===19||action===20){state.suppression4c=integer(state.nativeBC,'BC');if(state.suppression4c!==0||integer(state.nativeB8,'B8')!==0)return new Uint8Array();return Uint8Array.of(60,99,...(action===19?[1,254,1]:[254,1,1]),62);}
 if(action===21)return integer(state.nativeB8,'B8')!==0?new Uint8Array():Uint8Array.of(60,99,1,1,254,62);
 if(action===22){const show=integer(state.suppression4c,'suppression4c')===0&&integer(state.nativeB8,'B8')===0;state.suppression4c=0;return show?scriptStringBytes('</c>'):new Uint8Array();}
 if(action===23){const result=p.playerName(integer(state.nativeC0,'C0')>>>0);return result===null?fetch(token.defaultRef):text(result);}
 p.warning(0x175);return null;
}
