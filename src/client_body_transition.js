// Generic transition selector from SetBaseAnimation140764300..140765470.
// Creature weapon/emote hooks, existing fire-and-forget queue and timers
// belong to separate client owners; this returns extra transition clips.
export function clientBodyTransition(previous,requested){
  previous&=65535;requested&=65535;
  const known=id=>id<=170||id>=250&&id<=253||[261,267,273].includes(id);
  if(!known(previous)||!known(requested))return null;
  if(previous===requested)return [];
  if(clientAnimationCategory(5,requested)===0)return [];
  if([0,1].includes(previous)&&[0,1].includes(requested))return [];
  let animation=0,reaction=0,reactionDuration=0;
  // Later comparisons override earlier choices, including leave clips.
  for(const [state,enter,leave] of [[59,255,256],[60,257,258],[36,239,240],[47,211,212],[97,282,283],[98,284,285],
    ...Array.from({length:70},(_,i)=>[101+i,286+i*2,287+i*2])]){
    if(requested===state)animation=enter;if(previous===state)animation=leave;
  }
  if([32,33].includes(requested))animation=237;
  if([32,33].includes(previous))animation=238;
  if(requested===22)animation=previous===50?302:303;
  if(previous===22)animation=requested===50?300:301;
  if(requested===75)animation=402;if(previous===75)animation=403;
  if(requested===73)animation=401;if(previous===73)animation=400;
  if(requested===72)animation=404;
  if(previous===6){animation=225;if(requested!==5){reaction=223;reactionDuration=1000;}}
  else if(previous===8){animation=226;if(requested!==7){reaction=224;reactionDuration=1000;}}
  else if(previous===5)animation=223;
  else if(previous===7)animation=224;
  if(requested===5)animation=219;
  else if(requested===7)animation=220;
  else if(requested===63)animation=267;
  else if(requested===95)animation=273;
  else if(requested===62)animation=266;
  else if(requested===94)animation=272;
  else if(requested===6){animation=219;reaction=221;reactionDuration=1000;}
  else if(requested===8){animation=220;reaction=222;reactionDuration=1000;}
  if([30,38,39,40,41].includes(requested))animation=271;
  return animation?[{animation,reaction,reactionDuration}]:[];
}
// Animation-base category140762530, verified leaf. WORD IDs and BYTE object
// types select looping base states; movement2/3/4 is handled by its owner.
export function clientAnimationCategory(objectType,id){
  objectType&=255;id&=65535;
  const bit=(mask,n)=>Boolean(mask>>BigInt(n)&1n);
  if(objectType===5)return Number(id<=33&&bit(0x3400181e3n,id)||
    ((id-36)&65535)<=62&&bit(0x6e0000000de1083dn,(id-36)&65535)||
    ((id-101)&65535)<=69||((id-250)&65535)<=3||id===261);
  if(objectType===10)return Number(id<=51&&bit(0xc000000400001n,id)||id===72);
  if(objectType===9)return Number(((id-72)&65535)<=4||id===0);
  return 0;
}

