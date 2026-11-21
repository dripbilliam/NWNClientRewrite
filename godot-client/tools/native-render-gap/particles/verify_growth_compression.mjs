import fs from 'node:fs';import path from 'node:path';import crypto from 'node:crypto';import {fileURLToPath} from 'node:url';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..'),root=path.join(project,'.cache/prune-audit-20261108/growth-compress-a'),output=path.join(root,'final-audit.json');
if(fs.existsSync(output))throw Error('Retain earlier independent audit');
const hash=data=>crypto.createHash('sha256').update(data).digest('hex'),json=file=>JSON.parse(fs.readFileSync(file,'utf8').replace(/^\uFEFF/,''));
const manifestFile=path.join(root,'input-manifest.json'),manifest=json(manifestFile),summary=json(path.join(root,'summary.json'));
const lines=file=>fs.readFileSync(file,'utf8').trim().split(/\r?\n/).map(line=>JSON.parse(line));
const preflight=lines(path.join(root,'preflight.jsonl')),actions=lines(path.join(root,'actions.jsonl')),expected=new Map(manifest.map(row=>[row.file.toLowerCase(),row]));
const seen=new Set();let before=0,after=0;
for(const row of actions){
 const key=row.file.toLowerCase(),input=expected.get(key);
 if(!input||seen.has(key)||row.status!=='compressed'||row.bytes!==input.bytes||row.sha256!==input.expectedSha256||row.afterSha256!==input.expectedSha256||!row.contentUnchanged||fs.statSync(row.file).size!==input.bytes)throw Error('Per-file action proof differs');
 seen.add(key);before+=row.storedBytesBefore;after+=row.storedBytesAfter;
}
if(preflight.length!==505||preflight.some(row=>row.status!=='preflight'||!row.contentUnchanged)||actions.length!==505||seen.size!==505||summary.compressed!==505||summary.skipped!==0||!summary.success||before!==summary.storedBytesBefore||after!==summary.storedBytesAfter||hash(fs.readFileSync(manifestFile))!==summary.manifestSha256||summary.sourceBefore!==summary.sourceAfter)throw Error('Whole approved journal closure differs');
const result={success:true,files:505,expectedHashesMatchAllBeforeAfter:true,pathsRetained:true,currentLengthsMatch:true,logicalBytes:summary.logicalBytes,storedBytesBefore:before,storedBytesAfter:after,storedBytesReclaimed:before-after,volumeFreeGainBytes:summary.volumeFreeBytesAfter-summary.volumeFreeBytesBefore,sourceIdentity:summary.sourceAfter,manifestSha256:summary.manifestSha256,summarySha256:hash(fs.readFileSync(path.join(root,'summary.json'))),actionsSha256:hash(fs.readFileSync(path.join(root,'actions.jsonl'))),preflightSha256:hash(fs.readFileSync(path.join(root,'preflight.jsonl'))),scope:'Independent journal/metadata verification. File content was hashed under writer-excluding handles before and after compression by the retained executor; this audit does not rewrite or recompress any file.'};
fs.writeFileSync(output,JSON.stringify(result,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({output,...result},null,2));
