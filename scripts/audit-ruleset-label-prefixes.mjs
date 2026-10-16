// Read-only source/active-label audit. A suffix match is a candidate for
// binary investigation, not proof that a lookup should change.
import fs from 'node:fs/promises';
import {execFileSync} from 'node:child_process';
import {openLocalModule} from './local-module.mjs';
import {parse2da} from '../src/area.js';
import {decodeResourceText} from '../src/resource_archive.js';
const install=process.argv[2]??'../FullDecomp/NwnRootInstall',resolver=await openLocalModule(install,`${install}/data/nwm/Prelude.nwm`),table=parse2da(decodeResourceText(await resolver.getResource('ruleset',2017))),labels=new Set(table.orderedRows.map(row=>row.Label)),candidates=[];
for(const file of execFileSync('rg',['--files','src','--glob','*.js'],{encoding:'utf8'}).trim().split(/\r?\n/)){
 const source=await fs.readFile(file,'utf8');for(const match of source.matchAll(/['"`]([A-Z][A-Z0-9_]{3,})['"`]/g)){
  const value=match[1];if(labels.has(value))continue;const full=[...labels].filter(label=>label.length===value.length+1&&label.endsWith(value));
  if(full.length)candidates.push({file,line:source.slice(0,match.index).split('\n').length,value,activeCandidates:full});
 }
}
console.log(JSON.stringify({activeLabels:labels.size,candidates,limits:'Static one-character suffix matches against active installed ruleset labels; requires original hash-seed/call verification before edits.'},null,2));
