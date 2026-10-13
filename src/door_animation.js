import { doorCollision } from './door.js';

// Door behavior is one consumer of the same model animator used by all objects.
export function animateDoorState(door, previousState = null, onSettled = () => {}) {
  const animator = door.animator;
  const rest = ['closed', 'opened1', 'opened2', 'dead'][door.animationState];
  if (!animator?.model.animations.some(clip => clip.name === rest)) return false;
  if (previousState === null) { animator.pose(rest); return true; }
  const clip = door.animationState === 0 ? `closing${previousState === 2 ? 2 : 1}` : `opening${door.animationState}`;
  door.transitionCollision = [...doorCollision(door, previousState), ...doorCollision(door, door.animationState)];
  door.animating = true;
  animator.gameplayTransition = true;
  const finish = () => {
    door.animating = false;
    animator.gameplayTransition = false;
    door.transitionCollision = null;
    animator.pose(rest);
    onSettled();
  };
  if (!animator.play(clip, { loop: false, onComplete: finish }) || !animator.clip.length) finish();
  return true;
}
