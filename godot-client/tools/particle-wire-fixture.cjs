const fs=require('node:fs'),path=require('node:path'),{particlePackets}=require('./particle-wire.cjs');
const output=process.argv.find(arg=>arg.startsWith('--output='))?.slice(9);if(!output||!/^[-a-z0-9]+\.bin$/.test(path.basename(output)))throw Error('Provide unused --output=fixture.bin');
const positions=new Float32Array(96*3);for(let i=0;i<18;i++)positions[i]=i*.125;
const attributes=new Uint8Array(96*12);attributes.fill(10,0,72);
const packet=particlePackets({connection:1,areaId:2147483649,generation:2,transferId:3},{epoch:7,sequence:4,emitters:[{id:11,count:6,capacity:96,bounds:{min:[0,0,0],max:[3,3,3]},positions:positions.buffer,attributes:attributes.buffer}]})[0];
fs.writeFileSync(output,Buffer.concat([Buffer.from('{"kind":"chat","text":"é\u00b7"}\n'),packet,Buffer.from('{"kind":"particle-complete","sequence":4}\n')]),{flag:'wx'});
console.log(JSON.stringify({output,bytes:packet.length,scope:'Authored numeric streams and newline-valued attribute bytes, no game content'}));
