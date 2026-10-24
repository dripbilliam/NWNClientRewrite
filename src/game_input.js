// Menus own their controls and hit boxes, not the world's movement keys.
export const worldDriveKeys=Object.freeze({KeyW:'forward',ArrowUp:'forward',KeyS:'back',ArrowDown:'back',KeyA:'left',ArrowLeft:'left',KeyD:'right',ArrowRight:'right',KeyQ:'strafeLeft',KeyE:'strafeRight'});
export const isWorldMoveKey=event=>Object.hasOwn(worldDriveKeys,event.code);
export const isControlArrow=event=>event.code?.startsWith('Arrow')&&Boolean(event.target?.closest?.('input,textarea,select,button,[role="slider"],[role="radio"],[role="tab"],[role="listbox"]'));
export const isTextEntry=target=>Boolean(target?.closest?.('textarea,select,[contenteditable]:not([contenteditable="false"]),input:not([type="button"]):not([type="submit"]):not([type="reset"]):not([type="checkbox"]):not([type="radio"]):not([type="range"]):not([type="color"]):not([type="file"]):not([type="hidden"])'));
