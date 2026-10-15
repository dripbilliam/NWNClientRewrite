// Fresh installed BIC/module sessions. Replacement integration, not a native
// complete cast comparison. No spell effects, AI casting or UI acceptance.
import fs from 'node:fs/promises';
import path from 'node:path';
import assert from 'node:assert/strict';
import {spawn} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import {openLocalModule} from './local-module.mjs';
import {ModuleSession} from '../src/module_session.js';
import {creatureRoot} from '../src/creature_rules.js';
import {intEntry} from '../src/combat_stats.js';
import {runtimeDiagnostics} from '../src/runtime_diagnostics.js';
const [install,output,...options]=process.argv.slice(2),file=options.find(v=>v.startsWith('--file='))?.slice(7);
if(!install||!output)throw new Error('Usage: node scripts/smoke-spell-book.mjs INSTALL OUTPUT_DIRECTORY [--file=wizard.bic]');
await fs.mkdir(output,{recursive:true});
if(!file){
  const rows=[];
  for(const name of (await fs.readdir(path.join(install,'data/lcv'))).filter(f=>/\.bic$/i.test(f))){
    const code=await new Promise((resolve,reject)=>{const child=spawn(process.execPath,[fileURLToPath(import.meta.url),install,output,`--file=${name}`],{stdio:'inherit'});child.on('error',reject);child.on('exit',resolve);});
    let row;try{row=JSON.parse(await fs.readFile(path.join(output,`${name}.json`),'utf8'));}catch(error){row={file:name,fatal:error.message};}
    rows.push({...row,workerExit:code});
  }
  const importReady=rows.every(row=>row.workerExit===0&&!row.fatal&&row.errors?.length===0);
  await fs.writeFile(path.join(output,'summary.json'),JSON.stringify({importReady,limits:'Installed BIC import/live spell-use integration only; no cast timing, effects, rest or UI acceptance.',characters:rows},null,2)+'\n');
  console.log(JSON.stringify({characters:rows.length,consumed:rows.reduce((n,row)=>n+(row.consumed?.length??0),0),importReady,failures:rows.filter(row=>row.workerExit!==0||row.fatal)}));
  if(!importReady)process.exitCode=1;
}else{
  const s=await new ModuleSession(await openLocalModule(install,path.join(install,'data/nwm/Prelude.nwm')),{runStartupScripts:false,runNativeAI:false}).initialize([],{character:await fs.readFile(path.join(install,'data/lcv',file))});
  const o=s.player,root=creatureRoot(o),authored=JSON.stringify(o.authored),canonicalId=o.id,result={file,objectId:canonicalId,classes:[],spellLikeAbilities:o.nativeSpellLikeAbilities.length,consumed:[]};
  for(let index=0;index<root.ClassList.length;index++){
    const c=root.ClassList[index],state=o.nativeTalentClasses[index],memo=intEntry(s.characterRules.classes,c.Class&255,'MemorizesSpells').value!==0;
    result.classes.push({classType:c.Class,classIndex:index,known:state.known.reduce((n,a)=>n+a.length,0),memorized:state.memorized.reduce((n,a)=>n+a.filter(Boolean).length,0),ready:state.memorized.reduce((n,a)=>n+a.filter(v=>v&&v.ready!==0).length,0)});
    let selected;
    for(let level=0;level<10&&!selected;level++){
      const choices=memo?state.memorized[level].filter(v=>v&&v.ready!==0).map(v=>({id:v.id,meta:v.metamagic,domain:v.domain?(level-s.spellBook.metamagicCost(v.metamagic))&255:0})):state.known[level].map(id=>({id,meta:0,domain:0}));
      for(const choice of choices){
        const before=s.commands.GetSpellUsesLeft([o.id,c.Class,choice.id,choice.meta,choice.domain]);if(!before)continue;
        const consumed=s.spellBook.consume(o,choice.id,index,choice.domain,choice.meta,255);if(!consumed)continue;
        const after=s.commands.GetSpellUsesLeft([o.id,c.Class,choice.id,choice.meta,choice.domain]);assert.equal(after,(before-1)&255);
        selected={...choice,before,after};result.consumed.push({index,...selected});break;
      }
    }
  }
  assert.equal(o.id,canonicalId);assert.equal(s.registry.get(canonicalId),o);assert.equal(JSON.stringify(o.authored),authored,'Saved source is immutable');
  result.errors=runtimeDiagnostics.records.filter(r=>r.severity==='error').map(r=>({code:r.code,message:r.message}));
  await fs.writeFile(path.join(output,`${file}.json`),JSON.stringify(result,null,2)+'\n');console.log(JSON.stringify(result));
  assert.equal(result.errors.length,0);
}
