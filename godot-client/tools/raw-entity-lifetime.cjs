// Use the existing snapshot projection's identities. The canonical known-run
// carrier is clientKnownLifetime; disclosureLifetime is the older DTO spelling.
// Neither this adapter nor its consumers allocate another identity/world store.
const uint=value=>Number.isInteger(value)&&value>=0&&value<=0xffffffff;
function rawEntityLifetime(row){
 const known=Object.hasOwn(row??{},'clientKnownLifetime')?row.clientKnownLifetime:row?.disclosureLifetime;
 return[['nativeLifetime',uint(row?.nativeLifetime),uint(row?.nativeLifetime)?row.nativeLifetime:null],
  ['disclosureLifetime',uint(known),uint(known)?known:null]];
}
module.exports={rawEntityLifetime};
