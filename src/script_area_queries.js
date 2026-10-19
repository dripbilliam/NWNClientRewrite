const flags=area=>{if(!Number.isInteger(area.flags))throw new Error('Native area flags+8 are unavailable');return area.flags&255;};
// Complete successful typed-pop bodies1405269d0/140526a50. A missing area
// has distinct defaults. Interior means EITHER low bit, not just the first.
export function scriptAreaAboveGround(area){return area?((~flags(area))>>>1)&1:-1;}
export function scriptAreaInterior(area){return area?Number((flags(area)&3)!==0):0;}
