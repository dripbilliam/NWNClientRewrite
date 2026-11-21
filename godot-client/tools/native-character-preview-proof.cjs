// Owned-local diagnostic receipt validation only; no game/rules/rendering work.
const {isDeepStrictEqual}=require('node:util');
function previewProofMatches(proof,{connection,key,sha256},expected){
 if(!proof||!expected||!Number.isSafeInteger(connection)||typeof key!=='string'||!key||typeof sha256!=='string'||!/^[a-f0-9]{64}$/.test(sha256))return false;
 if(proof.connection!==connection||proof.key!==key||proof.sha256!==sha256||proof.native_only!==true||proof.title_matches!==true)return false;
 const input=proof.record_input;
 if(input?.success!==true||input.connection!==connection||input.key!==key||input.sha256!==sha256||!Array.isArray(input.checks)||input.checks.length!==12||!input.checks.every(row=>row?.passed===true))return false;
 return ['sha256','abilities','classes','skill_count','feat_count','spell_count'].every(field=>isDeepStrictEqual(proof[field],expected[field]));
}
module.exports={previewProofMatches};
