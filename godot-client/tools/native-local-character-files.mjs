import fs from 'node:fs/promises';
import path from 'node:path';
import {createHash} from 'node:crypto';
import {MAX_NETWORK_CHARACTER_BYTES} from '../../src/network_character.js';
// Bound allocation and reads even when a loose file is replaced or grows after
// listing. readFile() would allocate the entire changed file before validation.
async function readBoundedCharacter(file){
 let handle,bytes;
 try{
  handle=await fs.open(file,'r');const info=await handle.stat();
  if(!info.isFile()||!Number.isSafeInteger(info.size)||info.size>MAX_NETWORK_CHARACTER_BYTES)throw Error('Invalid local character byte size');
  bytes=Buffer.alloc(info.size);let at=0;
  while(at<bytes.length){const {bytesRead}=await handle.read(bytes,at,bytes.length-at,at);if(!bytesRead)throw Error('Local character file changed');at+=bytesRead;}
  const extra=Buffer.alloc(1);if((await handle.read(extra,0,1,at)).bytesRead)throw Error('Local character file changed');
  return bytes;
 }catch(error){bytes?.fill(0);throw error;}
 finally{await handle?.close();}
}
// Raw filesystem identity/integrity only. Godot decodes BIC and active 2DAs.
export async function localCharacterFile(file){
 let bytes;
 try{bytes=await readBoundedCharacter(file);return{format:'native-local-bic-v1',path:file,bytes:bytes.length,sha256:createHash('sha256').update(bytes).digest('hex')};}
 catch{return{format:'native-local-bic-v1',path:file,error:'Local character byte source is unavailable'};}
 finally{bytes?.fill(0);}
}

// Read only the character version described by the current catalog row. A
// filename or application-vault entry can be replaced between listing and Play.
// The caller still owns parsing, session validation and wiping successful reads.
export async function readCatalogCharacter(row,{vault,expectedFile=row?.nativeFile}={}){
 const ticket=expectedFile,file=row?.file;
 if(!['installed','local','workshop','vault'].includes(row?.source)||typeof file!=='string'||!path.isAbsolute(file)||
  ticket?.format!=='native-local-bic-v1'||ticket.path!==file||!Number.isSafeInteger(ticket.bytes)||ticket.bytes<56||ticket.bytes>MAX_NETWORK_CHARACTER_BYTES||
  typeof ticket.sha256!=='string'||!/^[a-f0-9]{64}$/.test(ticket.sha256))throw Error('The local character file identity is unavailable. Reconnect to refresh the character list.');
 const expectedBytes=ticket.bytes,expectedSha256=ticket.sha256;
 let bytes;
 try{bytes=row.source==='vault'?await vault.read(row.vaultId):await readBoundedCharacter(file);}
 catch{throw Error('The local character file is unavailable. Reconnect to refresh the character list.');}
 if(bytes.length!==expectedBytes||createHash('sha256').update(bytes).digest('hex')!==expectedSha256){
  bytes.fill(0);
  throw Error('The local character changed since the list was loaded. Reconnect to refresh the character list before selecting it again.');
 }
 return bytes;
}
