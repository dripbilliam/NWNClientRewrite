'use strict';
const {createHash}=require('node:crypto');
// Isolated fixture upload only: preserve the exact read bytes. The existing
// vault/protocol owners still validate the BIC; this helper invents no fields.
function exactNpcCharacter(input){
 if(!Buffer.isBuffer(input)||input.length===0)throw Error('NPC fixture requires its actual original character bytes');
 const sha256=createHash('sha256').update(input).digest('hex');
 return {bytes:input,metadata:{originalSha256:sha256,uploadedSha256:sha256,originalUnchanged:true,uploadedUnchanged:true,scope:'Byte-identical installed character for isolated NPC combat; no ActionCheck XP transform.'}};
}
module.exports={exactNpcCharacter};
