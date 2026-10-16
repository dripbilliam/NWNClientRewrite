import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {ModuleSession} from '../src/module_session.js';
test('all effect public/internal/state translations match the complete native mapping, independently of application support',()=>{
 const data=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-effect-script-type-observations-v3.json',import.meta.url))),s=new ModuleSession(null);assert.equal(data.rows.length,470);
 for(const row of data.rows){const e={type:row.type,integers:Array(8).fill(0)};e.integers[0]=row.integer0??0;e.integers[3]=row.integer3??0;assert.equal(s.commands.GetEffectType([e,row.all]),row.value,JSON.stringify(row));}
});
