import test from 'node:test';
import assert from 'node:assert/strict';
import {GameObjectArray} from '../src/game_object_array.js';
import {WorldObjects} from '../src/world_objects.js';
test('area view detachment preserves canonical IDs and other objects sharing the same tag',()=>{
 const registry=new GameObjectArray(),view=new WorldObjects(1,registry),render={userData:{}},a=view.add('creature','a',{tag:'same'},render),b=view.add('creature','b',{tag:'same'}),next=[...registry.nextObjectId];
 assert.deepEqual(view.remove(a.id),{object:a,render});assert.equal(registry.get(a.id),a);assert.equal(registry.get(b.id),b);assert.deepEqual([...registry.nextObjectId],next);
 assert.equal(view.get(a.id),undefined);assert.equal(view.renderBindings.has(a.id),false);assert.equal(view.sources.has('a'),false);assert.deepEqual(view.byTag('same'),[b]);
 registry.delete(b.id);view.remove(b.id);assert.equal(view.objects.size,0);assert.equal(view.remove(b.id),null);
});
