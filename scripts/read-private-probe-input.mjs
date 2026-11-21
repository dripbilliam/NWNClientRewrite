// One-use encrypted in-memory input; no credential argv/files/environment.
import net from 'node:net';
import crypto from 'node:crypto';
export async function readPrivateProbeInput(){
 const option=name=>process.argv.find(value=>value.startsWith('--'+name+'='))?.slice(name.length+3),port=Number(option('private-input-port')),token=option('private-input-token');
 if(!Number.isInteger(port)||port<1||port>65535||!/^[0-9a-f]{64}$/.test(token??''))throw new Error('Private content-test input is unavailable');
 const pair=crypto.generateKeyPairSync('x25519'),stream=net.connect({host:'127.0.0.1',port}),chunks=[];let size=0;stream.setTimeout(10000,()=>stream.destroy(new Error('Private input timed out')));
 stream.write(JSON.stringify({token,publicKey:pair.publicKey.export({format:'der',type:'spki'}).toString('base64')})+'\n');
 for await(const chunk of stream){size+=chunk.length;if(size>32768){stream.destroy();throw new Error('Private input exceeds the supported size');}chunks.push(chunk);}
 const envelope=JSON.parse(Buffer.concat(chunks).toString('utf8')),publicKey=crypto.createPublicKey({key:Buffer.from(envelope.publicKey,'base64'),format:'der',type:'spki'}),shared=crypto.diffieHellman({privateKey:pair.privateKey,publicKey}),key=Buffer.from(crypto.hkdfSync('sha256',shared,Buffer.from(token),'nwn-renderer-probe-input',32));shared.fill(0);let bytes;
 try{const decipher=crypto.createDecipheriv('aes-256-gcm',key,Buffer.from(envelope.iv,'base64'));decipher.setAuthTag(Buffer.from(envelope.tag,'base64'));bytes=Buffer.concat([decipher.update(Buffer.from(envelope.ciphertext,'base64')),decipher.final()]);return JSON.parse(bytes.toString('utf8'));}
 finally{key.fill(0);bytes?.fill(0);for(const chunk of chunks)chunk.fill(0);}
}
