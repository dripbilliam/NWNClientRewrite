'use strict';
// Exact five immutable REA evidence dossiers reviewed by root. No code/native/
// engine file is link eligible, even when its source is a sealed capsule.
const dossiers=Object.freeze({
 'tools/native_parity/visibility/evidence/native-actor-alpha-propagation-v1.json':'aac9d3ec01a8d53305f883c9f7e7da6121c202dc354fd4e78f42e9d7c6fe96a7',
 'tools/native_parity/visibility/evidence/native-actor-alpha-propagation-v2.json':'17287eb0630ae3debad3621899222c418efe28956d7b0b10c66b1b9c5b9e8e6e',
 'tools/native_parity/visibility/evidence/native-static-mesh-membership-fields-v1.json':'af3f89f7bd9946b302540713b2f13de0b452a479bbe91152d8ace2653777b67c',
 'tools/native_parity/visibility/evidence/native-static-placeable-spawntile-v1.json':'e80a0075b0beb4cabf1029a44f68d3465841f097fa6b9fecad15fe1d24fff1ab',
 'tools/native_parity/visibility/evidence/native-static-placeable-spawntile-v2.json':'2256174dfc55852f44420c5b1f0deb5444fb16ad91d027b701a3105fc0278500'
});
const mayLink=pin=>Object.hasOwn(dossiers,pin.relative)&&dossiers[pin.relative]===pin.sha256;
module.exports={dossiers,mayLink};
