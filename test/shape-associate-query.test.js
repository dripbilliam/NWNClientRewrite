import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {objectInShape} from '../src/shape_query.js';
import {scriptGetAssociate} from '../src/associate_query.js';
import {ModuleSession} from '../src/module_session.js';
const capture=JSON.parse(readFileSync(new URL('../backups/animations/native-shape-associate-observations.json',import.meta.url))),f=Math.fround;
test('shape queries match622 complete native sphere/cube/cylinder/cone/filter/LOS/cursor executions',async()=>{
  assert.equal(capture.shapes.length,622);
  for(const row of capture.shapes){const c=row.case,calls=[],a={nativeObjectCursor238:c.cursor},objects=new Map(c.objects.map(o=>[o.id,{...o,objectType:o.kind}]));let line=0;
    const result=await objectInShape(c.first,c.self?{id:10,point:c.origin}:null,c.shape,c.size,{areaId:77,position:c.center},c.los,c.filter,c.origin,{
      area:()=>c.hasArea?a:null,position:o=>o.point,isDM:o=>o.dm,object:id=>objects.get(id),spatialIds:()=>c.objects.map(o=>o.id),
      firstByX:(_a,x)=>{calls.push(['first',x]);const n=c.objects.findIndex(o=>f(o.point[0])>=x);return n===-1?null:n;},
      lineOfSight:(_a,from,to,...args)=>{calls.push(['los',from.slice(),to.slice(),...args]);return c.losResults[line++%c.losResults.length];}});
    assert.deepEqual({pushed:result,cursor:a.nativeObjectCursor238,calls},{pushed:row.pushed,cursor:row.cursor,calls:row.calls},JSON.stringify(c));
  }
});
test('henchman query matches54 native optional-master/nth wrapper executions',()=>{
  assert.equal(capture.henchmen.length,54);
  for(const row of capture.henchmen){const c=row.case,s=new ModuleSession({});
    for(const o of c.objects)s.registry.addObjectAtPos(o.id,{objectType:o.kind,associateType:o.associate});
    if(c.self)s.registry.addObjectAtPos(10,{objectType:5,associateIds:c.list,nativeStatsIsPCb0:1});
    const args=c.argc===0?[]:c.argc===1?[10]:[10,c.nth];assert.equal(s.commands.GetHenchman(args,{self:10}),row.pushed,JSON.stringify(c));
  }
});
test('associate query matches630 native physical-list, type, PC/default, stale/duplicate and nth executions',()=>{
  assert.equal(capture.associates.length,630);
  for(const row of capture.associates){const c=row.case,objects=new Map(c.objects.map(o=>[o.id,{...o,objectType:o.kind,associateType:o.associate}]));
    const result=scriptGetAssociate(c.self?{associateIds:c.list,nativeStatsIsPCb0:c.pc}:null,c.type,c.nth,id=>{const o=objects.get(id);return o?.objectType===5?o:null;});
    assert.equal(result,row.pushed,JSON.stringify(c));
  }
});
