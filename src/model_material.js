import {FrontSide} from 'three';

// GLRender::ResetRenderStates1400b6050 enables CULL_FACE and CCW. The
// model basis (x,z,-y) preserves handedness, so MDL front faces stay CCW.
// Base geometry controllers apply even when no animation has an alpha track.
export function modelMaterialOptions(node) {
  const authoredAlpha = Number(node.alpha ?? node.properties?.alpha ?? 1);
  const opacity = Number.isFinite(authoredAlpha) ? Math.max(0,Math.min(1,authoredAlpha)) : 1;
  const hint = Boolean(Number(node.transparencyHint ?? node.properties?.transparencyhint ?? 0));
  return { side:FrontSide,opacity,visible:opacity > 0,transparent:hint || opacity < 1,depthWrite:!hint && opacity >= 1,
    userData:{mdlTransparencyHint:hint,mdlOpacityDriven:true} };
}
