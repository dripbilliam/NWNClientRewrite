// Explicit opt-in pipe only. Never echo input, parse errors, or key material.
async function savePrivateLogin(input,settings){
 const chunks=[];let size=0,login,stage='read';
 try{
  for await(const chunk of input){const bytes=Buffer.from(chunk);chunks.push(bytes);size+=bytes.length;if(size>16384)throw Error();}
  const bytes=Buffer.concat(chunks);
  stage='decode';try{login=JSON.parse(bytes.toString('utf8').replace(/^\uFEFF/,''));}finally{bytes.fill(0);}
  stage='validate';
  if(!login||Object.keys(login).length!==1||typeof login.cdKey!=='string'||! /^(?:[A-Z0-9]{5}-){6}[A-Z0-9]{5}$/.test(login.cdKey))throw Error();
  const {createHash,timingSafeEqual}=require('node:crypto');
  const digest=createHash('sha256').update(login.cdKey).digest();
  stage='store';await settings.update(login);
  // Return only an in-memory equality predicate; never publish the digest/key.
  return key=>typeof key==='string'&&timingSafeEqual(digest,createHash('sha256').update(key).digest());
 }catch{throw Error(`Could not save the private login key (${stage})`);}
 finally{for(const bytes of chunks)bytes.fill(0);if(login)login.cdKey='';}
}
// Test-participant credentials are read in memory without updating main settings.
async function readPrivateKey(input){
 const chunks=[];let size=0,login,bytes;
 try{
  for await(const chunk of input){const copy=Buffer.from(chunk);chunks.push(copy);size+=copy.length;if(size>16384)throw Error();}
  bytes=Buffer.concat(chunks);login=JSON.parse(bytes.toString('utf8').replace(/^\uFEFF/,''));
  if(!login||Object.keys(login).length!==1||typeof login.cdKey!=='string'||! /^(?:[A-Z0-9]{5}-){6}[A-Z0-9]{5}$/.test(login.cdKey))throw Error();
  return login.cdKey;
 }catch{throw Error('Could not read private participant credentials');}
 finally{bytes?.fill(0);for(const chunk of chunks)chunk.fill(0);if(login)login.cdKey='';}
}
function connectPrivatePipe(name){
 if(!/^nwn-private-login-[a-f0-9]{32}$/.test(name))throw Error('Invalid private login pipe');
 const socket=require('node:net').createConnection('\\\\.\\pipe\\'+name);socket.setTimeout(15000,()=>socket.destroy(Error('Private login timed out')));return socket;
}
module.exports={savePrivateLogin,readPrivateKey,connectPrivatePipe};
