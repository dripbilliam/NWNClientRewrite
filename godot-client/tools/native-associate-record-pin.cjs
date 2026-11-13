'use strict';
const fs=require('node:fs/promises'),path=require('node:path'),crypto=require('node:crypto');
// Isolated fixture routing only. The peer still validates this exact key during
// the normal cryptographic handshake; no network, defaults or fallback here.
async function readAssociateRecordServerPin(directory){
 if(typeof directory!=='string'||!path.isAbsolute(directory)||path.basename(directory)!=='server')throw Error('Owned Associate Record server home unavailable');
 const home=await fs.realpath(directory),log=await fs.realpath(path.join(home,'logs/nwengineLog.txt'));
 if(path.dirname(log)!==path.join(home,'logs')||(await fs.stat(log)).size>4194304)throw Error('Owned Associate Record server log escapes its fixture');
 const bytes=await fs.readFile(log),text=bytes.toString('utf8'),pin=text.match(/cryptographic public identity is: ([A-Za-z0-9+/=]+)/)?.[1];
 if(!pin)throw Error('Owned Associate Record server identity is unavailable');
 return {pin,sourcePath:log,fileSha256:crypto.createHash('sha256').update(bytes).digest('hex'),identitySha256:crypto.createHash('sha256').update(Buffer.from(pin,'base64')).digest('hex')};
}
module.exports={readAssociateRecordServerPin};
