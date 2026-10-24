import test from 'node:test';
import assert from 'node:assert/strict';
import {attachResourceAudit} from './resource-audit.mjs';
import {preparedModelFixtureSource} from '../prepared-model-fixture-source.mjs';

const fixture=()=>{const bytes=preparedModelFixtureSource();return {closed:false,world:{areaId:11},areaGeneration:1,async getResource(){return bytes;},async getTextureResource(){return {type:3,extension:'tga',bytes:new Uint8Array(16)};}};};
test('audit is transparent to success values and records texture type/size without saving payloads',async()=>{
  const session=fixture(),original=session.getTextureResource,audit=attachResourceAudit(session);const result=await session.getTextureResource('Map');
  assert.equal(result.bytes.byteLength,16);session.closed=true;const report=audit.finish();
  assert.equal(session.getTextureResource,original);assert.equal(report.reads[0].type,3);assert.equal(report.reads[0].name,'map');assert.equal(report.reads[0].bytes,16);assert.ok(!JSON.stringify(report).includes('"data"'));
});
test('model parsing waits for disconnect and saves hashes/counts only',async()=>{
  const session=fixture(),audit=attachResourceAudit(session);await session.getResource('model',2002);
  assert.throws(()=>audit.finish(),/after session disconnect/);session.closed=true;const result=audit.finish();assert.equal(result.models.length,1);assert.match(result.models[0].sha256,/^[0-9a-f]{64}$/);assert.ok(!result.models[0].parseFailure);assert.ok(!('verts' in result.models[0]));
});
test('errors preserve identity and retain only error code metadata',async()=>{
  const error=Object.assign(Error('private message'),{code:'RESOURCE_NOT_FOUND'}),session=fixture();session.getResource=async()=>{throw error;};
  const audit=attachResourceAudit(session);await assert.rejects(session.getResource('missing',6),value=>value===error);session.closed=true;const report=audit.finish();assert.equal(report.reads[0].error,'RESOURCE_NOT_FOUND');assert.ok(!JSON.stringify(report).includes('private message'));
});
test('area changes during reads retain both start and completion generations',async()=>{
  const session=fixture();session.getResource=async()=>{session.world.areaId=12;session.areaGeneration=2;return new Uint8Array(1);};const audit=attachResourceAudit(session);await session.getResource('table',2017);session.closed=true;
  const row=audit.finish().reads[0];assert.equal(row.areaId,11);assert.equal(row.generation,1);assert.equal(row.finishedAreaId,12);assert.equal(row.finishedGeneration,2);
});
test('audit caps model bytes and read metadata, marks incomplete and restores methods',async()=>{
  const session=fixture(),original=session.getResource,audit=attachResourceAudit(session,{maxModelBytes:0,maxReads:1});await session.getResource('model',2002);await session.getResource('other',2002);session.closed=true;
  const report=audit.finish();assert.equal(report.complete,false);assert.equal(report.droppedModels,2);assert.equal(report.droppedReads,1);assert.equal(report.models.length,0);assert.equal(session.getResource,original);audit.dispose();
});
test('repeated requests are counted separately but retain only one immutable model reference',async()=>{
  const session=fixture(),audit=attachResourceAudit(session);await session.getResource('model',2002);await session.getResource('MODEL',2002);session.closed=true;const report=audit.finish();assert.equal(report.models.length,1);assert.equal(report.groups[0].count,2);
});
