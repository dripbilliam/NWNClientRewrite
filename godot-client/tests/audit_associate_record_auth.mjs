// Whitelisted derived evidence only: never serialize runtime log lines or keys.
import fs from 'node:fs/promises';
import path from 'node:path';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {fileURLToPath} from 'node:url';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..'),project=path.join(root,'godot-client'),sha=bytes=>createHash('sha256').update(bytes).digest('hex');
const runs=[['accepted_npc14','associate-record-server-tests/20261103-044013-ddad9d2a'],['accepted_disclosures8','associate-record-gui-server-tests/20261103-052543-0c687cf9'],['rejected_login0','associate-record-gui-server-tests/20261103-052842-1d9f845d']];
const records=[];
for(const[label,relative]of runs){
 const directory=path.join(project,'.cache',relative),log=await fs.readFile(path.join(directory,'server/logs/nwengineLog.txt'),'utf8'),lines=log.split(/\r?\n/),tag=log.match(/Connection Attempt made by [^\r\n]* \(([A-Z0-9]{8})\)/)?.[1];
 const events=[];
 for(const[index,line]of lines.entries()){
  let kind=null;
  if(line.includes('UDP initialised on port 5127'))kind='owned_udp_bound';
  else if(line.includes('Loading Module:'))kind='module_loading_started';
  else if(line.includes('Masterserver became available'))kind='master_control_plane_available';
  else if(line.includes('Server hidden: Requested not to be listed'))kind='public_listing_disabled';
  else if(line.includes('Connection Attempt made by'))kind='client_connection_attempt';
  const rejection=line.match(/Rejected key auth[^\r\n]*:\s*(\d+) at window\s*(\d+)/);
  if(rejection)events.push({line:index+1,kind:'server_key_auth_rejected',result:Number(rejection[1]),window:Number(rejection[2])});
  else if(kind)events.push({line:index+1,kind,time:line.match(/\[(\d\d:\d\d:\d\d)\]/)?.[1]??null});
 }
 const config=[];
 for(const name of ['settings.tml','nwn.ini','nwnplayer.ini'])try{const data=await fs.readFile(path.join(directory,'server',name));config.push({name,sha256:sha(data)});}catch(error){if(error.code!=='ENOENT')throw error;}
 records.push({label,directory:path.relative(root,directory).replaceAll('\\','/'),participantPublicTagHash:tag?sha(tag):null,events,config});
}
assert.ok(records.every(row=>row.participantPublicTagHash));
const oldRunner=await fs.readFile(path.join(project,'tests/run-native-associate-record-server-tests.ps1'),'utf8'),newRunner=await fs.readFile(path.join(project,'tests/run-native-associate-record-gui-server-tests.ps1'),'utf8');
const defaultProfile=/runtime-logs\/local-multiplayer-server\/native-barter-main\.dpapi/;
const ciphertext=path.join(root,'runtime-logs/local-multiplayer-server/native-barter-main.dpapi'),stat=await fs.stat(ciphertext);
const out={success:true,participantPublicIdentityEqual:records.every(row=>row.participantPublicTagHash===records[0].participantPublicTagHash),defaultProtectedProfilePathEqual:defaultProfile.test(oldRunner)&&defaultProfile.test(newRunner),currentProtectedCiphertextSha256:sha(await fs.readFile(ciphertext)),currentProtectedProfileLastWriteUtc:stat.mtime.toISOString(),historicalCiphertextHashAvailable:false,
 readinessPredicate:'Both wrappers wait only for owned UDP endpoint/PID, not an authoritative key-authentication-ready state.',
 authConfig:{samePort:5127,publicServerFlag0:[oldRunner,newRunner].every(text=>text.includes("'-publicserver','0'")),natOff:[oldRunner,newRunner].every(text=>text.includes("NWN_DO_NOT_NAT_PUNCH")&&text.includes("$true")),automaticKeySwap:false,authenticationBypass:false},records,
 scope:'Derived static/profile/public-identity equality and whitelisted readiness ordering. Authentication result2 is observed, semantic meaning remains unestablished. No raw log lines, key tags, private key material or payloads included.'};
assert.ok(out.participantPublicIdentityEqual&&out.defaultProtectedProfilePathEqual&&out.authConfig.publicServerFlag0&&out.authConfig.natOff);
const report=path.join(project,'.cache/associate-record-gui-server-tests/20261103-052842-1d9f845d/auth-config-audit.json');await fs.writeFile(report,JSON.stringify(out,null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify({success:out.success,participantPublicIdentityEqual:out.participantPublicIdentityEqual,defaultProtectedProfilePathEqual:out.defaultProtectedProfilePathEqual,historicalCiphertextHashAvailable:false,report:path.relative(root,report)}));
