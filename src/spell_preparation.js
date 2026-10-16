const integer=(v,n)=>{if(!Number.isInteger(v))throw new Error(`Native spell preparation ${n} is unavailable`);return v|0;};

// HandlePlayerToServerInputMessage1404531b0 shared prelude and decoded
// subtype16(1404543de) /17(1404544b6). Return0 does not mean rejection.
// Byte/word codec and profiling are separate boundaries; there is no
// commandability/known-spell/possession check in these two server branches.
export async function receiveSpellPreparationInput(client,clear,p){
 const object=p.clientObject(client);let actor=object?p.asCreature(object):null;
 if(actor&&integer(actor.nativeField8ac,'creature field8ac')!==0)actor=null;
 if(p.overflow()!==0)return 0;
 const index=p.readByte()&255;
 if(clear){
  const level=p.readByte()&255,slot=p.readByte()&255;
  if(p.overflow()!==0||p.underflow()!==0||!actor)return 0;
  await p.clear(actor,index,level,slot);
 }else{
  const id=p.readDword()>>>0,slot=p.readByte()&255,domain=p.readByte()&255,meta=p.readByte()&255;
  if(p.overflow()!==0||p.underflow()!==0||!actor||!p.spell(id))return 0;
  await p.set(actor,index,slot,id,domain,meta,1);
 }
 return 0;
}

// Set-slot widget1409c2630 request slice1409c275e..27d7. Domain base
// level is the widget level minus active metamagic cost, with BYTE wrap.
export function preparationRequest(widget,p){
 let domain=0;
 if(integer(widget.domain,'widget domain')!==0){domain=integer(widget.level,'widget level')&255;
  if(integer(widget.metamagic,'widget metamagic')!==0)domain=(domain-p.metamagicCost(widget.metamagic&255))&255;}
 return{classIndex:integer(widget.classIndex,'widget class')&255,spellId:integer(widget.id,'widget spell')>>>0,
  slot:integer(widget.slot,'widget slot')&255,domainLevel:domain,metamagic:widget.metamagic&255};
}

// Full drop policy1409c21d0..2336. Presentation callbacks(SetSpell,
// ready tint) are explicit boundaries. Physical prepared slots exchange
// spells; a known-list source copies. The native domain flag is taken from
// the source even for the displaced record, so it must not be normalized.
export async function dropPreparation(destination,source,flags,p){
 flags=integer(flags,'drop flags');
 if((flags&31)!==0||source.type!==0x53704278||destination.kind!==0||source===destination||source.level!==destination.level)return flags;
 let result=0x88;const old=destination.id,id=source.id,meta=source.metamagic,domain=source.domain;
 if(old!==-1&&source.kind===0){
  await p.set(source,old,1,domain,destination.metamagic,destination.classIndex);source.ready=0;p.tint(source);result=8;
 }
 if(id<0)return flags|8;
 await p.set(destination,id,1,domain,meta,destination.classIndex);destination.ready=0;p.tint(destination);return flags|result;
}

// CPanelSpellbook::GetNextTreebuttonSpellID14088ddb0. cursor is INT;
// known getter accepts BYTE; domain duplicates are collapsed only against
// the other domain, not against the ordinary class list.
export function nextPreparationSpell(index,type,level,meta,state,p){
 index&=255;type&=255;level=integer(level,'list level');meta&=255;
 const actor=p.controlled();if(!actor)return -1;state.domain=0;
 if(p.restricted(type)!==0){
  if(state.cursor>=(p.knownCount(actor,index,level&255)&65535))return -1;
  if(state.cursor>=(p.knownCount(actor,index,level&255)&65535))return -1;
  do{const id=p.known(actor,index,level&255,state.cursor&255)|0,spell=p.spell(id>>>0);
   const allowed=meta===0?1:p.metamagic(spell)&meta;state.cursor=(state.cursor+1)|0;if(allowed!==0)return id;
  }while(state.cursor<(p.knownCount(actor,index,level&255)&65535));
  return -1;
 }
 if((p.classLevel(actor,index)&255)<integer(p.minCastingLevel(type),'minimum casting level'))return -1;
 const count=integer(p.spellCount(),'spell count');
 while(state.cursor<count){const id=state.cursor,spell=p.spell(id>>>0);
  if(spell&&(p.level(spell,type)&255)===level&&(meta===0||(p.metamagic(spell)&meta)!==0)){state.cursor=(state.cursor+1)|0;return id;}
  state.cursor=(state.cursor+1)|0;
 }
 if(p.pickDomains(type)===0)return -1;
 const first=p.domainSpell(p.domain(actor,index,0)&255,level&255)|0,second=p.domainSpell(p.domain(actor,index,1)&255,level&255)|0;
 if(state.cursor===count){state.cursor=(state.cursor+1)|0;
  if(first!==-1){const spell=p.spell(first>>>0);if(meta===0||(p.metamagic(spell)&meta)!==0){state.domain=1;return first;}}
 }
 if(state.cursor!==count+1)return -1;state.cursor=(state.cursor+1)|0;
 if(second===-1||first===second)return -1;
 const spell=p.spell(second>>>0);if(meta!==0&&(p.metamagic(spell)&meta)===0)return -1;state.domain=1;return second;
}
