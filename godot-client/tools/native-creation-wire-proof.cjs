'use strict';
function creationWireProof({wire=[],vault=false,reconnect=false,selection=null}){
 const uploads=wire.filter(row=>row.major===2&&[1,19].includes(row.minor)),plays=wire.filter(row=>row.major===2&&[2,14,17].includes(row.minor));
 if(reconnect){const play=plays[0];return {success:uploads.length===0&&plays.length===1&&play.minor===17&&play.canonical===true&&selection?.success===true&&selection.serverSource===17&&play.source===17,uploads:uploads.length,plays:plays.length,play,source:'Actual outgoing login subtype17 compared byte-for-byte with the current original-server advertised account-vault row; no BIC upload'};}
 const upload=uploads[0],expected=vault?19:1;return {success:uploads.length===1&&plays.length===0&&upload.minor===expected&&upload.bytes>32,uploads:uploads.length,plays:plays.length,expectedSubtype:expected,upload,source:'Actual outgoing character-blob login subtype and immutable packet digest; authoritative admission/export is verified separately'};
}
module.exports={creationWireProof};
