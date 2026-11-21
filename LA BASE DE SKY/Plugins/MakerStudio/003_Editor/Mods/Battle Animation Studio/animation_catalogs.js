// Catalogs are organizational and runtime-addressable. None of the new kinds
// silently overrides Essentials' standard Move/Common dispatch.
export const BAS_ANIMATION_CATALOGS = Object.freeze([
    { type:"move", mode:"moves", es:"Moves", en:"Moves", trigger:"pbAnimation", subject:"duo" },
    { type:"common", mode:"common", es:"Common", en:"Common", trigger:"pbCommonAnimation", subject:"target" },
    { type:"custom", mode:"custom", es:"Custom", en:"Custom", trigger:"pbPlayBattleAnimationStudioCustom", subject:"duo" },
    { type:"subanimation", mode:"subanimation", es:"Subanimaciones", en:"Sub animations", trigger:"pbPlayBattleAnimationStudioCategory", subject:"target" },
    { type:"status", mode:"status", es:"Estados", en:"Status", trigger:"pbPlayBattleAnimationStudioCategory", subject:"target" },
    { type:"weather", mode:"weather", es:"Clima", en:"Weather", trigger:"pbPlayBattleAnimationStudioCategory", subject:"field" },
    { type:"terrain", mode:"terrain", es:"Terreno", en:"Terrain", trigger:"pbPlayBattleAnimationStudioCategory", subject:"field" },
    { type:"ability", mode:"ability", es:"Habilidades", en:"Abilities", trigger:"pbPlayBattleAnimationStudioCategory", subject:"user" },
    { type:"item", mode:"item", es:"Objetos", en:"Items", trigger:"pbPlayBattleAnimationStudioCategory", subject:"target" },
    { type:"entry", mode:"entry", es:"Entradas", en:"Send-out / Entry", trigger:"pbPlayBattleAnimationStudioCategory", subject:"user" },
    { type:"faint", mode:"faint", es:"Debilitamiento", en:"Faint", trigger:"pbPlayBattleAnimationStudioCategory", subject:"target" },
    { type:"field", mode:"field", es:"Campo", en:"Field", trigger:"pbPlayBattleAnimationStudioCategory", subject:"field" },
    { type:"transition", mode:"transition", es:"Transiciones", en:"Transitions", trigger:"pbPlayBattleAnimationStudioCategory", subject:"field" }
]);
export const BAS_ANIMATION_CATALOG_TYPES = BAS_ANIMATION_CATALOGS.map(x=>x.type);
export const BAS_ANIMATION_CATALOG_MODES = BAS_ANIMATION_CATALOGS.map(x=>x.mode);
export function normalizeBasCatalogType(type) {
    const v=String(type||"move").toLowerCase();
    return BAS_ANIMATION_CATALOG_TYPES.includes(v) ? v : "move";
}
export function basCatalogMode(type) {
    const t=normalizeBasCatalogType(type);
    return t==="move"?"moves":t;
}
export function basCatalogTypeFromMode(mode) {
    const t=String(mode||"moves").toLowerCase();
    return normalizeBasCatalogType(t==="moves"?"move":t);
}
export function basCatalogMetadata(type) {
    const t=normalizeBasCatalogType(type);
    return BAS_ANIMATION_CATALOGS.find(x=>x.type===t);
}
export function basCatalogOptionsHtml(escapeHtml, language="es", includeMove=true) {
    return BAS_ANIMATION_CATALOGS.filter(c=>includeMove||c.type!=="move")
        .map(c=>'<option value="'+escapeHtml(c.type)+'">'+escapeHtml(language==="en"?c.en:c.es)+'</option>').join("");
}
