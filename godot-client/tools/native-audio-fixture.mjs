// Authored tones/tables only; no installed game audio is persisted in tests.
export function voiceWave({bits=16,format=1,channels=1,sampleRate=8000,frames=4000}={}){
 const size=frames*channels*bits/8,b=Buffer.alloc(44+size);b.write('RIFF');b.writeUInt32LE(b.length-8,4);b.write('WAVEfmt ',8);b.writeUInt32LE(16,16);b.writeUInt16LE(format,20);b.writeUInt16LE(channels,22);b.writeUInt32LE(sampleRate,24);b.writeUInt32LE(sampleRate*channels*bits/8,28);b.writeUInt16LE(channels*bits/8,32);b.writeUInt16LE(bits,34);b.write('data',36);b.writeUInt32LE(size,40);
 for(let i=0;i<frames*channels;i++){const value=Math.sin(i/channels*2*Math.PI*220/sampleRate)*0.25,at=44+i*bits/8;if(format===3){if(bits===32)b.writeFloatLE(value,at);else b.writeDoubleLE(value,at);}else if(bits===8)b[at]=Math.round(value*127+128);else if(bits===16)b.writeInt16LE(Math.round(value*32767),at);else if(bits===24)b.writeIntLE(Math.round(value*8388607),at,3);else b.writeInt32LE(Math.round(value*2147483647),at);}
 return b;
}
export function voiceSet({empty=[]}={}){const b=Buffer.alloc(40+49*24);b.write('SSF V1.0');b.writeUInt32LE(49,8);b.writeUInt32LE(40,12);for(let i=0;i<49;i++){if(empty.includes(i))continue;const p=40+49*4+i*20;b.writeUInt32LE(p,40+i*4);b.write('sample'+i,p);b.writeUInt32LE(0xffffffff,p+16);}return b;}
