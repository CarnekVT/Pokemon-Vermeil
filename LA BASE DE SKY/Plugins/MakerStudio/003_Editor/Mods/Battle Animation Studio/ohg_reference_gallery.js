import { OHG_VISUAL_REFERENCES } from "./ohg_visual_manifest.js";

// Documentation / visual reference ONLY. This module never edits BAS project state,
// creates clips, copies third-party assets or changes gameplay.
const OHG_ORIGIN = "https://originheartgold.github.io/";
const OHG_CATEGORIES = [
    ["all", "Todas", "All"],
    ["ubicaciones", "Ubicaciones y objetos", "Locations and items"],
    ["escenarios", "Escenarios", "Scenery"],
    ["escenas", "Escenas", "Scenes"],
    ["interfaz", "Interfaz", "Interface"]
];
function ohgSearchText(value) {
    return String(value || "").normalize("NFD").replace(/[\u0300-\u036f]/g, "").toLowerCase();
}
function ohgTextElement(tag, content, className) {
    const element = document.createElement(tag);
    if (className) element.className = className;
    element.textContent = content;
    return element;
}
function ohgLink(label, href) {
    const a = ohgTextElement("a", label);
    a.href = href;
    a.target = "_blank";
    a.rel = "noopener noreferrer";
    return a;
}
export function openOhgReferenceGallery(showStudioDialog, language = "es") {
    const en = String(language).toLowerCase().startsWith("en");
    if (typeof showStudioDialog !== "function") return;
    showStudioDialog({
        title: en ? "Origin HeartGold · Public visual references" : "Origin HeartGold · Referencias visuales públicas",
        width: "1080px",
        height: "740px",
        render(body) {
            body.innerHTML = `
<style>
.bas-ohg{font:inherit;display:grid;gap:12px;min-width:0;color:var(--text-primary,#e7e8ed)}
.bas-ohg a{color:var(--accent,#94baff);text-decoration:underline}
.bas-ohg-note{padding:10px 12px;border:1px solid rgba(160,175,205,.25);border-radius:9px;background:rgba(120,130,170,.07);font-size:12px;line-height:1.5}
.bas-ohg-note p{margin:0 0 7px}
.bas-ohg-links{display:flex;gap:16px;flex-wrap:wrap}
.bas-ohg-controls{display:grid;grid-template-columns:minmax(210px,1fr) minmax(190px,240px);gap:8px}
.bas-ohg-controls input,.bas-ohg-controls select{box-sizing:border-box;min-width:0;width:100%;border-radius:8px;border:1px solid rgba(170,175,195,.35);background:var(--bg-secondary,#252936);color:inherit;padding:9px 11px;font:inherit}
.bas-ohg-summary{font-size:12px;color:var(--text-secondary,#c3c6cf)}
.bas-ohg-grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(145px,1fr));gap:10px}
.bas-ohg-card{min-width:0;display:grid;gap:6px;padding:7px;border:1px solid rgba(170,175,195,.2);border-radius:10px;background:rgba(130,140,165,.06)}
.bas-ohg-thumb{display:flex;justify-content:center;align-items:center;min-height:110px;max-height:145px;overflow:hidden;border-radius:6px;background:rgba(0,0,0,.2)}
.bas-ohg-thumb img{max-width:100%;max-height:140px;object-fit:contain;image-rendering:auto}
.bas-ohg-card strong{overflow-wrap:anywhere;font-size:11px;line-height:1.35;font-weight:600}
.bas-ohg-card small{color:var(--text-secondary,#b9bccc);font-size:10px}
.bas-ohg-card a{font-size:11px}
.bas-ohg-pager{display:flex;gap:10px;align-items:center;justify-content:center;padding:10px 0}
.bas-ohg-pager button{border:1px solid rgba(170,175,195,.32);border-radius:7px;padding:6px 12px;background:var(--bg-secondary,#252936);color:inherit;cursor:pointer}
.bas-ohg-pager button:disabled{opacity:.4;cursor:default}
@media(max-width:700px){.bas-ohg-controls{grid-template-columns:1fr}.bas-ohg-grid{grid-template-columns:repeat(2,minmax(0,1fr))}}
</style>
<div class="bas-ohg">
<div class="bas-ohg-note">
<p data-role="ohg-description"></p>
<div class="bas-ohg-links" data-role="ohg-links"></div>
</div>
<div class="bas-ohg-controls">
<input data-role="ohg-search" type="search" autocomplete="off">
<select data-role="ohg-category"></select>
</div>
<div class="bas-ohg-summary" data-role="ohg-summary"></div>
<div class="bas-ohg-grid" data-role="ohg-grid"></div>
<div class="bas-ohg-pager">
<button type="button" data-role="ohg-prev"></button>
<span data-role="ohg-pagination"></span>
<button type="button" data-role="ohg-next"></button>
</div>
</div>`;
            const $ = (name) => body.querySelector('[data-role="' + name + '"]');
            $("ohg-description").textContent = en
                ? "Read-only directory of 294 images indexed from the public website (not battle animation frames or editable sprites). Nothing here is imported into your game. External thumbnails require an Internet connection."
                : "Directorio de solo lectura de 294 imágenes de la web pública (NO son fotogramas de ataques ni sprites editables). No se importa nada al juego. Las miniaturas externas necesitan Internet.";
            const links = $("ohg-links");
            links.append(
                ohgLink(en ? "Official public website" : "Web pública original", OHG_ORIGIN),
                ohgLink(en ? "Moves (920 reference entries)" : "Movimientos (920 fichas)", OHG_ORIGIN + "moves/"),
                ohgLink(en ? "Source repository" : "Repositorio fuente", "https://github.com/originheartgold/originheartgold.github.io")
            );
            const search = $("ohg-search");
            const category = $("ohg-category");
            const grid = $("ohg-grid");
            const pager = $("ohg-pagination");
            const previous = $("ohg-prev");
            const next = $("ohg-next");
            const count = $("ohg-summary");
            search.placeholder = en ? "Find a visual reference…" : "Buscar una referencia visual…";
            previous.textContent = en ? "Previous" : "Anterior";
            next.textContent = en ? "Next" : "Siguiente";
            OHG_CATEGORIES.forEach(([value, esLabel, enLabel]) => {
                const option = document.createElement("option");
                option.value = value;
                option.textContent = en ? enLabel : esLabel;
                category.appendChild(option);
            });
            const pageSize = 24;
            let page = 0;
            const renderPage = () => {
                const q = ohgSearchText(search.value);
                const cat = category.value;
                const filtered = OHG_VISUAL_REFERENCES.filter(entry =>
                    (cat === "all" || cat === entry.c) &&
                    (!q || ohgSearchText(entry.n + " " + entry.p).includes(q))
                );
                const pages = Math.max(1, Math.ceil(filtered.length / pageSize));
                page = Math.max(0, Math.min(page, pages - 1));
                grid.replaceChildren();
                for (const item of filtered.slice(page * pageSize, (page + 1) * pageSize)) {
                    const card = ohgTextElement("div", "", "bas-ohg-card");
                    const thumb = ohgTextElement("div", "", "bas-ohg-thumb");
                    const link = ohgLink("", OHG_ORIGIN + item.p);
                    const img = document.createElement("img");
                    img.loading = "lazy";
                    img.decoding = "async";
                    img.alt = item.n;
                    img.src = OHG_ORIGIN + item.p;
                    img.onerror = () => { img.style.display = "none"; thumb.textContent = en ? "Preview unavailable" : "Vista no disponible"; };
                    link.appendChild(img);
                    thumb.appendChild(link);
                    card.append(thumb, ohgTextElement("strong", item.n), ohgTextElement("small", item.p), ohgLink(en ? "Open original" : "Abrir original", OHG_ORIGIN + item.p));
                    grid.appendChild(card);
                }
                count.textContent = en
                    ? filtered.length + " / " + OHG_VISUAL_REFERENCES.length + " public images · Reference only"
                    : filtered.length + " / " + OHG_VISUAL_REFERENCES.length + " imágenes públicas · Solo referencia";
                pager.textContent = en ? "Page " + (page + 1) + " of " + pages : "Página " + (page + 1) + " de " + pages;
                previous.disabled = page <= 0;
                next.disabled = page >= pages - 1;
            };
            search.addEventListener("input", () => { page = 0; renderPage(); });
            category.addEventListener("change", () => { page = 0; renderPage(); });
            previous.addEventListener("click", () => { if (page > 0) { page--; renderPage(); } });
            next.addEventListener("click", () => { page++; renderPage(); });
            renderPage();
        }
    });
}
