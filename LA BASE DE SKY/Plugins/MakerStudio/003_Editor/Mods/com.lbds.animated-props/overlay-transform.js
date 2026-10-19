/**
 * Maker Studio's overlay renderInfo supplies tileSize ALREADY scaled by zoom
 * (observed 24 at 75%, 32 at 100%, 48 at 150%), while viewportX/Y are screen
 * pixel camera offsets. The overlay 2D context is identity CTM in this build.
 *
 * Screen/overlay coordinates: x = tileX * tileSize - viewportX.
 * Do NOT apply zoom a second time. Keep object positions in map tile units.
 * These values were verified against the in-editor Zoom Inspector screenshots.
 */
export function normalizedOverlayInfo(info={}) {
  const zoom=Number(info.zoom);
  const tileSize=Number(info.tileSize);
  return {
    mapId: Number.isInteger(info.mapId)?info.mapId:undefined,
    zoom:Number.isFinite(zoom)&&zoom>0?zoom:1,
    tileSize:Number.isFinite(tileSize)&&tileSize>0?tileSize:32,
    viewportX:Number(info.viewportX)||0,
    viewportY:Number(info.viewportY)||0,
    canvasWidth:Number(info.canvasWidth)||0,
    canvasHeight:Number(info.canvasHeight)||0,
  };
}

export function nativeScreenRect(x,y,w,h,info){
  const i=normalizedOverlayInfo(info);
  return {x:x*i.tileSize-i.viewportX,y:y*i.tileSize-i.viewportY,
          w:w*i.tileSize,h:h*i.tileSize};
}

// On the observed Maker Studio build, the draw context uses screen pixels too.
export function overlayCanvasRect(x,y,w,h,info){
  return nativeScreenRect(x,y,w,h,info);
}

export function nativeScreenToTile(screenX,screenY,info){
  const i=normalizedOverlayInfo(info);
  return {x:Math.floor((screenX+i.viewportX)/i.tileSize),
          y:Math.floor((screenY+i.viewportY)/i.tileSize)};
}
