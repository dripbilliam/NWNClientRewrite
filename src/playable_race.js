// ExecuteCommandGetIsRacialTypePlayable140527660 compares the seven native
// race constants DAT140dc3e58..70 (0..6); it does not query PlayerRace. Invalid
// objects use race28, DAT140dc3eb8. Preserve WORD narrowing of the cached race.
export function playableRacialType(object){
  if(object?.objectType!==5)return 0;
  const race=object.stats?.race??(object.creatureData??object.authored)?.Race;
  if(!Number.isInteger(race))throw new Error('Native playable-race cache is unavailable');
  return Number((race&65535)<=6);
}
