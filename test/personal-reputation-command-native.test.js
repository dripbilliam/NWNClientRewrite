import fs from 'node:fs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {personalReputationCommand} from '../src/personal_reputation_command.js';
const data=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-personal-reputation-command-observations.json',import.meta.url)));
test('personal reputation script commands match complete original default, pop and mutation ordering',()=>{
  assert.equal(data.rows.length,580);
  for(const row of data.rows){const c=row.case,calls=[],args=[99,98,c.decays??0,c.duration??180].slice(0,c.argc);let result=0;
    for(let i=1;i<=c.argc;i++){calls.push(['pop',i<=2?'object':i===3?'int':'float']);if(c.failPop===i){result=-639;break;}}
    if(result===0)personalReputationCommand(c.ordinal,args,97,c.context,{
      creature:id=>{calls.push(['creature',id]);return c.exists===false?null:{};},clear:(o,id)=>calls.push(['clear',id]),add:(o,id,n,decays,duration)=>calls.push(['add',id,n,decays,duration])});
    assert.deepEqual({result,calls},{result:row.result,calls:row.calls},JSON.stringify(c));
  }
});
