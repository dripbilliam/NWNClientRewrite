import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
const folder=path.dirname(fileURLToPath(import.meta.url));
const parent=path.resolve(folder,'../particles/check.mjs'),target=path.join(folder,'check-clock-pose.mjs');
if(fs.existsSync(target))throw Error('Existing adapted checker preserved');
const bytes=fs.readFileSync(parent),sha256=crypto.createHash('sha256').update(bytes).digest('hex');
let code=bytes.toString('utf8');
const changes=[
 ["const receiptFile=path.join(project,'.cache/native-140fps/particles-agent',label,'candidate-built-sources.json'),receipt=JSON.parse(fs.readFileSync(receiptFile));","const receiptFile=path.join(project,'.cache/native-140fps/render-agent',label,'manifest.json'),sourceReceipt=JSON.parse(fs.readFileSync(receiptFile)),receipt={...sourceReceipt,sourceProject:sourceReceipt.project,sourcePins:sourceReceipt.pins,isolatedBuildFinalized:sourceReceipt.builds===1};"],
 ["const stage=path.join(project,'.cache/native-140fps/particles-agent/checks',run)","const stage=path.join(project,'.cache/native-140fps/render-agent/checks',run)"]
];
for(const [from,to]of changes){if(code.split(from).length!==2)throw Error('Checker adaptation boundary changed');code=code.replace(from,to);}
code=`// Isolated rendering-agent adaptation of particles/check.mjs SHA-256 ${sha256}.\n// Only receipt shape and owned check-directory root changed; child close/error/source guards retained.\n`+code;
fs.writeFileSync(target,code,{flag:'wx'});
console.log(JSON.stringify({target,parent,parentSha256:sha256,changes:changes.length,enginesStarted:0}));
