import test from 'node:test';
import assert from 'node:assert/strict';
import { WorldTimer } from '../src/world_timer.js';

function clock(counter=0n){let ticks=counter;const timer=new WorldTimer(()=>ticks);return{timer,set:v=>{ticks=v;timer.snapshot();}};}
test('world timer cancels arbitrary uint64 epoch and carries time over day boundaries',()=>{
  for(const epoch of [0n,1001n,123456789012345n,0xffffffffffffffffn]){
    const {timer}=clock(epoch);timer.setTime(7,7199999);
    assert.deepEqual(timer.time(),{day:7,time:7199999});
  }
  const {timer,set}=clock(123456789n);timer.setTime(7,7199999);
  set(123457789n);assert.deepEqual(timer.time(),{day:8,time:0});
  set(123457999n);assert.deepEqual(timer.time(),{day:8,time:0});
  set(123458000n);assert.deepEqual(timer.time(),{day:8,time:1});
});
test('world time handles unsigned negative offset before positive day carry',()=>{
  const {timer}=clock(1000000n);timer.setTime(0xffffffff,0);
  assert.deepEqual(timer.time(),{day:0xffffffff,time:0});
  timer.counter=1001000n;assert.deepEqual(timer.time(),{day:0xffffffff,time:1});
  timer.setTime(0xffffffff,timer.dayLength);assert.deepEqual(timer.time(),{day:0,time:0});
});
test('module clock uses byte and ushort authored fields, real minutes-per-hour and native missing-field defaults',()=>{
  const {timer}=clock();timer.loadModule({Mod_MinPerHour:2,Mod_StartYear:1372,Mod_StartMonth:4,Mod_StartDay:12,Mod_StartHour:6,
    Mod_StartMinute:1,Mod_StartSecond:2,Mod_StartMiliSec:3});
  assert.equal(timer.dayLength,2880000);assert.deepEqual(timer.time(),{day:1372*336+3*28+11,time:782003});
  timer.loadModule({});assert.equal(timer.minutesPerHour,1);assert.deepEqual(timer.time(),{day:1340*336+140,time:1380000});
  timer.loadModule({Mod_MinPerHour:256,Mod_StartMonth:262,Mod_StartDay:257,Mod_StartHour:279,Mod_StartMinute:65536});
  assert.deepEqual(timer.time(),{day:1340*336+140,time:1380000});
});
test('native calendar invalid values use mapped fallback year/month/hour/minute/second and normalize excess milliseconds',()=>{
  const {timer}=clock();timer.setMinutesPerHour(1);
  timer.setCalendar(32001,0,0,24,60,60,1440000);
  const raw=1380000+3540000+56000+1440000;
  assert.deepEqual(timer.time(),{day:1340*336+140+Math.trunc(raw/1440000),time:raw%1440000});
  timer.setCalendar(32000,12,28,23,59,59,999);
  assert.deepEqual(timer.time(),{day:32000*336+335+3,time:659999});
});
test('world timer pause retains time across snapshots and unpause cancels elapsed paused time',()=>{
  const {timer,set}=clock();timer.setTime(100,1);timer.pause();
  set(10000000n);assert.deepEqual(timer.time(),{day:100,time:1});
  timer.pause();timer.unpause();assert.deepEqual(timer.time(),{day:100,time:1});
  set(10001000n);assert.deepEqual(timer.time(),{day:100,time:2});
  timer.unpause();assert.deepEqual(timer.time(),{day:100,time:2});
});
test('fixed-rate native snapshots increment signed quotient and keep previous counter without wall clock reads',()=>{
  const {timer}=clock();timer.mode=1;timer.fixedRate=30;timer.setTime(7,0);
  timer.snapshot();assert.equal(timer.counter,33333n);assert.equal(timer.previousCounter,0n);
  assert.deepEqual(timer.time(),{day:7,time:33});timer.snapshot();assert.equal(timer.counter,66666n);
  timer.fixedRate=0;assert.throws(()=>timer.snapshot(),/divides by zero/);
});
test('calendar conversions honor28-day months, unsigned year fallback and native rate-dependent minutes',()=>{
  const {timer}=clock();
  assert.deepEqual(timer.calendar(0),{year:0,month:1,day:1});assert.deepEqual(timer.calendar(335),{year:0,month:12,day:28});
  assert.deepEqual(timer.calendar(32767*336+335),{year:32767,month:12,day:28});
  assert.deepEqual(timer.calendar(32768*336),{year:1340,month:1,day:1});
  assert.deepEqual(timer.calendar(0xffffffff),{year:1340,month:10,day:4});
  timer.setMinutesPerHour(5);assert.deepEqual(timer.timeParts(1859999),{hour:6,minute:0,second:59,millisecond:999});
  timer.setTime(1,1919007);assert.equal(timer.getHour(),6);assert.equal(timer.getMinute(),1);assert.equal(timer.getSecond(),59);
  timer.pause();timer.counter=99999999999n;assert.equal(timer.getSecond(),59);
  timer.minutesPerHour=0;assert.throws(()=>timer.timeParts(1),/divides by zero/);
});
