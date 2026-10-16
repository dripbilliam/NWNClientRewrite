// ExecuteCommandVersusEffect14054ac30. The typed VM owns argument copies;
// preserve that value boundary here, including null and unsupported effects.
// No linked-child traversal: the original handler modifies only its argument.
export function versusEffect(value,ordinal,first,second=0,raceCount=0){
  const effect=structuredClone(value),selector=first|0;
  if(ordinal===355&&(selector>>>0)>5||ordinal===356&&(selector<0||selector>(raceCount&255))||effect===null)return effect;
  const type=effect.type&65535;
  let raceIndex;
  if([10,11,13,14,48,49,55,56].includes(type))raceIndex=2;
  else if([22,47,63,76].includes(type))raceIndex=1;
  else if([26,27].includes(type))raceIndex=3;
  else return effect;
  if(ordinal===355){effect.integers[raceIndex+1]=selector;effect.integers[raceIndex+2]=second|0;}
  else if(ordinal===356)effect.integers[raceIndex]=selector;
  return effect;
}
