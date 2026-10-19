// One-use encrypted loopback input for the owned renderer QA harness. Call from
// the persistent Node tool with credentials in memory; never pass them in argv,
// environment variables or files. Only the ephemeral port/token are returned.
import net from 'node:net';
import crypto from 'node:crypto';
export async function prepareRendererInput(request){
 const token=crypto.randomBytes(32).toString('hex'),body=Buffer.from(JSON.stringify(request));
 for(const key of Object.keys(request.credentials??{}))request.credentials[key]='';
 let accepted=false,cleaned=false,timer;const cleanup=()=>{if(cleaned)return;cleaned=true;body.fill(0);clearTimeout(timer);if(server.listening)server.close();};
 const server=net.createServer(stream=>{
  if(accepted){stream.destroy();return;}accepted=true;server.close();let chunks=[],size=0;stream.setTimeout(10000,()=>stream.destroy());
  stream.on('data',chunk=>{size+=chunk.length;if(size>4096){stream.destroy();return;}chunks.push(chunk);const bytes=Buffer.concat(chunks),end=bytes.indexOf(10);if(end<0)return;stream.removeAllListeners('data');
   let key,shared;try{const hello=JSON.parse(bytes.subarray(0,end).toString('utf8'));if(typeof hello.token!=='string'||hello.token.length!==64||!crypto.timingSafeEqual(Buffer.from(hello.token),Buffer.from(token)))throw new Error('Private input token is invalid');
    const publicKey=crypto.createPublicKey({key:Buffer.from(hello.publicKey,'base64'),format:'der',type:'spki'});if(publicKey.asymmetricKeyType!=='x25519')throw new Error('Private input peer key is invalid');
    const pair=crypto.generateKeyPairSync('x25519');shared=crypto.diffieHellman({privateKey:pair.privateKey,publicKey});key=Buffer.from(crypto.hkdfSync('sha256',shared,Buffer.from(token),'nwn-renderer-probe-input',32));const iv=crypto.randomBytes(12),cipher=crypto.createCipheriv('aes-256-gcm',key,iv),encrypted=Buffer.concat([cipher.update(body),cipher.final()]);
    stream.end(JSON.stringify({publicKey:pair.publicKey.export({format:'der',type:'spki'}).toString('base64'),iv:iv.toString('base64'),ciphertext:encrypted.toString('base64'),tag:cipher.getAuthTag().toString('base64')})+'\n');encrypted.fill(0);
   }catch{stream.destroy();}finally{key?.fill(0);shared?.fill(0);bytes.fill(0);for(const b of chunks)b.fill(0);chunks=[];cleanup();}
  });stream.on('error',()=>{});stream.on('close',cleanup);
 });
 await new Promise((resolve,reject)=>{server.once('error',reject);server.listen(0,'127.0.0.1',resolve);});timer=setTimeout(cleanup,120000);timer.unref();server.unref();return{port:server.address().port,token};
}
