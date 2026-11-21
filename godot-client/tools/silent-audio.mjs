import {GameAudio} from '../../src/game_audio.js';
// Only the isolated resource staging build uses this class. It retains the
// lifetime/cache interface needed by the JS scene, with no browser output.
export class SilentAudio extends GameAudio {
 async unlock(){}
 async play(){}
 async loadBuffer(){return null;}
 effectSound(){return null;}
 ensureContext(){throw Error('Godot owns world audio output');}
}
