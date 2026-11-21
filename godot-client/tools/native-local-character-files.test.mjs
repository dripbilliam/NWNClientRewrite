import {test} from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {createHash} from 'node:crypto';
import {localCharacterFile,readCatalogCharacter} from './native-local-character-files.mjs';
import {lobbyChoice} from './native-lobby.mjs';
test('Local byte source transports exact owned bytes without interpreting BIC fields',async()=>{
 const directory=await fs.mkdtemp(fileURLToPath(new URL('../reports/local-byte-test-',import.meta.url))),file=path.join(directory,'source.bic'),bytes=Buffer.from('opaque bytes, deliberately not a BIC');
 try{await fs.writeFile(file,bytes);assert.deepEqual(await localCharacterFile(file),{format:'native-local-bic-v1',path:file,bytes:bytes.length,sha256:createHash('sha256').update(bytes).digest('hex')});assert.deepEqual(await fs.readFile(file),bytes);}
 finally{await fs.unlink(file);await fs.rmdir(directory);}
});
test('Missing local bytes report an unavailable ticket without fabricated metadata',async()=>{
 const ticket=await localCharacterFile(fileURLToPath(new URL('../reports/absent-local-byte-source.bic',import.meta.url)));assert.equal(ticket.error,'Local character byte source is unavailable');assert.equal(ticket.sha256,undefined);assert.equal(ticket.bytes,undefined);
});
test('A received server row cannot expose a native local-file ticket',()=>{
 const row=lobbyChoice({key:'server:0:a',label:'A',source:'server',nativeFile:{path:'forged'},catalogStem:'forged',firstName:{text:'A'},secret:'private'});assert.equal(row.nativeFile,undefined);assert.equal(row.catalogStem,undefined);assert.equal(row.secret,undefined);assert.deepEqual(row.firstName,{text:'A'});
});
test('An owned local catalog row carries only its explicit byte ticket and public fields',()=>{
 const nativeFile={format:'native-local-bic-v1',path:'owned.bic',bytes:56,sha256:'a'.repeat(64)},row=lobbyChoice({key:'installed:owned.bic',label:'fallback',source:'installed',catalogStem:'owned',nativeFile,file:'not forwarded',vaultId:'not forwarded'});assert.deepEqual(row.nativeFile,nativeFile);assert.equal(row.catalogStem,'owned');assert.equal(row.file,undefined);assert.equal(row.vaultId,undefined);
});

const ownedRow=bytes=>{const file=fileURLToPath(new URL('../reports/owned-read.bic',import.meta.url));return{source:'vault',vaultId:'owned',file,nativeFile:{format:'native-local-bic-v1',path:file,bytes:bytes.length,sha256:createHash('sha256').update(bytes).digest('hex')}};};

test('a successful verified read stays opaque and transfers buffer cleanup to the caller',async()=>{
 const bytes=Buffer.alloc(60,65),row=ownedRow(bytes);
 assert.equal(await readCatalogCharacter(row,{vault:{read:async id=>{assert.equal(id,'owned');return bytes;}}}),bytes);
 assert.ok(bytes.every(value=>value===65),'the byte reader does not parse or wipe a successful caller-owned result');bytes.fill(0);
});

test('a mismatched read is wiped before rejection, including metadata changes while reading',async()=>{
 const before=Buffer.alloc(60,65),replacement=Buffer.alloc(60,66),row=ownedRow(before);let resolve;
 const pending=readCatalogCharacter(row,{vault:{read:()=>new Promise(accept=>resolve=accept)}});
 row.nativeFile=ownedRow(replacement).nativeFile;resolve(replacement);
 await assert.rejects(pending,/character.*changed/i);assert.ok(replacement.every(value=>value===0));assert.ok(before.every(value=>value===65));
});

test('invalid or server-only catalog identities are refused before reading a vault',async()=>{
 const bytes=Buffer.alloc(60,65),valid=ownedRow(bytes);let calls=0;
 const vault={read:async()=>{calls++;return bytes;}};
 for(const change of [row=>row.source='server',row=>row.nativeFile=null,row=>row.file='relative.bic',row=>row.nativeFile.path+='other',row=>row.nativeFile.format='wrong',row=>row.nativeFile.bytes=-1,row=>row.nativeFile.bytes=948*65535,row=>row.nativeFile.sha256='A'.repeat(64)]){
  const row=structuredClone(valid);change(row);await assert.rejects(readCatalogCharacter(row,{vault}),/identity is unavailable/);
 }
 assert.equal(calls,0);assert.ok(bytes.every(value=>value===65));
});

test('missing local files produce an actionable refusal without exposing a filesystem path',async()=>{
 const row={...ownedRow(Buffer.alloc(60)),source:'local'};
 await assert.rejects(readCatalogCharacter(row),error=>/file is unavailable.*Reconnect/.test(error.message)&&!error.message.includes(row.file));
});

test('oversized loose character files are refused before hashing or allocating their contents',async()=>{
 const directory=await fs.mkdtemp(fileURLToPath(new URL('../reports/local-size-test-',import.meta.url))),file=path.join(directory,'oversized.bic');
 try{
  const bytes=Buffer.alloc(60,65);await fs.writeFile(file,bytes);const ticket=await localCharacterFile(file);
  await fs.truncate(file,948*65535);const metadata=await localCharacterFile(file);assert.equal(metadata.sha256,undefined);assert.ok(metadata.error);
  await assert.rejects(readCatalogCharacter({source:'local',file,nativeFile:ticket}),/file is unavailable/);
  assert.equal((await fs.stat(file)).size,948*65535);
 }finally{await fs.unlink(file);await fs.rmdir(directory);}
});
