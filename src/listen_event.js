// CNWSObject matched strings +1f0/count1f8/capacity1fc. These are copies of
// received captures, distinct from the parser's saved expression captures.
export class MatchedExpressionStrings{
  constructor(){this.entries=[];this.count=0;this.capacity=0;}
  // ClearMatchedExpressionStrings140491060 releases storage as well as entries.
  clear(){this.entries=[];this.count=0;this.capacity=0;}
  // AddMatchedExpressionString14048db90 allocates a new string and grows16/2x.
  append(value){if(this.count===this.capacity){this.capacity=this.capacity===0?16:this.capacity*2;this.entries.length=this.capacity;}
    this.entries[this.count++]=String(value);}
  get(index){index|=0;return index<0||index>=this.count?'':this.entries[index];}
}

// Creature event10/script7,14038f623..14038f888. Dispatch uses the original
// speaker/listen state and default conversation script, not direct AI orders.
// VM payload getters, possession and RunEventScript are separate boundaries.
export async function receiveListenEvent(actor,callerId,payload,p){
  const familiarId=await p.associateId(actor,3,1);
  if(p.client(familiarId))await p.unpossess(actor);
  actor.lastSpeakerId=callerId>>>0;
  actor.listenPatternNumber=p.integer(payload,1)|0;
  actor.lastSpokenText=p.string(payload,0);
  actor.lastVoiceChatId=p.integer(payload,2)|0;
  actor.lastSpeechVolume=p.integer(payload,3)|0;
  p.clearMatched(actor);
  let index=1;
  if((p.integer(payload,0)|0)>1){do{p.appendMatched(actor,p.string(payload,index));index++;}while(index<(p.integer(payload,0)|0));}
  let script=p.scriptName(actor);if(script===''||script==='default')script='NW_G0_Conversat';
  if(!await p.possessed(actor)||(await p.rulesetInt('ALL_ASSOCIATES_RUN_SCRIPTS',0)|0)!==0)await p.runScript(actor,7,script);
}

// VM178 gates out base game-object types0..4. VM179 reads the capture count
// after successful lookup without that type gate; unavailable raw storage must
// be diagnosed by the provider, rather than fabricating an area's field1f8.
export function matchedSubstring(object,index,p){return !object||object.objectType<=4?'':p.storage(object).get(index|0);}
export function matchedSubstringCount(object,p){return object?p.storage(object).count|0:0;}
