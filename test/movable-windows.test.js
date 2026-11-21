import test from 'node:test';import assert from 'node:assert/strict';
import {clampWindowPosition} from '../src/movable_windows.js';
test('remembered menu coordinates stay inside resized viewports and survive oversized panels',()=>{
 assert.deepEqual(clampWindowPosition({x:900,y:600},{width:430,height:560},{width:1000,height:800}),{x:570,y:240});
 assert.deepEqual(clampWindowPosition({x:-80,y:-30},{width:430,height:560},{width:1000,height:800}),{x:0,y:0});
 assert.deepEqual(clampWindowPosition({x:20,y:20},{width:850,height:900},{width:640,height:480}),{x:0,y:0});
});
