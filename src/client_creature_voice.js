// Native807240: SSF demand/read/release precedes the WAV existence gate.
// Only an admitted nonempty resource replaces this creature's voice source.
export function playCreatureVoice(state,code,positional,p){
 if((state.soundsetId&65535)===65535)return false;
 const set=p.demandSet(state.soundsetId&65535);if(!set)return false;
 let entry;try{entry=p.entry(set,code&65535);}finally{p.releaseSet(set);}
 const resRef=entry?.resRef??'';if(!resRef||!p.exists(resRef))return false;
 const priority=p.controlled()?6:p.player()?7:p.sizeCategory()<4?15:14;
 return startCreatureVoiceSource(state,resRef,{positional,priority,height:1.5},p);
}

// Shared source slot+e8. Quick-chat7aaa00 uses height0 and priority6/7;
// combat barks and server26/1 use807240 above. No gameplay state is written.
export function startCreatureVoiceSource(state,resRef,{positional,priority,height},p){
 state.delay=0;if(state.sound)p.destroySound(state.sound);
 const sound=state.sound=p.createSound(resRef);if(!sound)return false;
 p.sound3d(sound,positional);p.soundPriority(sound,priority);
 if(positional)p.updateSound(sound,p.position(),height);
 p.playSound(sound);return true;
}
