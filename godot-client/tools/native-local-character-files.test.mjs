import {test} from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {createHash} from 'node:crypto';
import {localCharacterFile} from './native-local-character-files.mjs';
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
