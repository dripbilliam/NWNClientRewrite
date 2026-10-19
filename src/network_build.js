// CNetLayerPlayerInfo::SatisfiesBuild24ff10. Number and revision are separate
// lower bounds; a higher build number does not bypass its revision check.
export function satisfiesNativeBuild(build,required,{formatMode=1,pretendOldBuild=false}={}){
 if(![build?.number,build?.revision,build?.postfix,required?.number,required?.revision,required?.postfix].every(Number.isInteger))throw new Error('Native build comparison fields are unavailable');
 return !pretendOldBuild&&(formatMode===0||(build.number>=required.number&&(build.revision>required.revision||(build.revision===required.revision&&build.postfix>=required.postfix))));
}
