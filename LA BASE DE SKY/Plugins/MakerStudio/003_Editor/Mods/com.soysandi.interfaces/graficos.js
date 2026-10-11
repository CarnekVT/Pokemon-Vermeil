//=============================================================================
// Cargar imagenes y la fuente del juego dentro del editor.
//
// POR QUE VA POR TAURI Y NO POR ctx.fs
//   ctx.fs.readProjectFile devuelve TEXTO, y un PNG es binario. El editor corre
//   en el mismo contexto web que MakerStudio, asi que window.__TAURI__.core.invoke
//   esta disponible y permite leer bytes. Es lo mismo que hace el mod pbs-editor
//   para sus miniaturas, o sea que es camino trillado y no un truco.
//
// LA FUENTE ES IMPORTANTE, Y SON DOS
//   Essentials no tiene UNA fuente escalable: tiene DOS DIBUJADAS A MANO, cada
//   una para su tamaño (Power Green para 27 px y Power Green Small para 21). El
//   juego elige una u otra segun el cuerpo que se le pida, asi que el editor
//   tiene que elegir CON LA MISMA REGLA. Ver fuenteSegunTamano aqui abajo, que
//   es el espejo de Interfaces.fuente en [003] Elementos.rb.
//
//   Un editor visual que miente sobre la letra no sirve de nada, y no es una
//   suposicion: en este proyecto ya se pago dos veces (el visor de la pantalla
//   de carga enseñaba una fuente y el juego pintaba otra).
//=============================================================================

const EXTENSIONES = ["png", "gif"];      // las mismas que resuelve pbResolveBitmap

let _raiz = "";
let _invoke = null;
const _cache = new Map();                // ruta sin extension -> {url, ancho, alto} o null
let _fuenteLista = false;
let _pequenaLista = false;

export const FUENTE = "PowerGreenEditor";           // la normal, para 27 px
export const FUENTE_PEQUENA = "PowerGreenSmallEditor";  // la dibujada para 21

// El mismo corte que Interfaces::UMBRAL_FUENTE_PEQUENA en [000] Settings.rb.
export const UMBRAL_FUENTE_PEQUENA = 21;

// Que fuente toca para este cuerpo. ESPEJO EXACTO de Interfaces.fuente: si las
// dos reglas se separan, el editor vuelve a enseñar una letra y el juego otra.
export function fuenteSegunTamano(tam) {
  const t = (tam && tam > 0) ? tam : 14;
  const familia = (t <= UMBRAL_FUENTE_PEQUENA && _pequenaLista) ? FUENTE_PEQUENA : FUENTE;
  return `${t}px "${familia}", sans-serif`;
}

export function configurar(ctx) {
  _invoke = window.__TAURI__?.core?.invoke || null;
  try { _raiz = (ctx.editor?.gameRoot?.() || "").replace(/\\/g, "/"); } catch { _raiz = ""; }
  return { raiz: _raiz, tauri: !!_invoke };
}

export function raizProyecto() { return _raiz; }
export function hayTauri() { return !!_invoke; }

async function leerBytes(rutaAbsoluta) {
  if (!_invoke) return null;
  try {
    const bytes = await _invoke("read_binary_file", { path: rutaAbsoluta });
    if (!bytes || !bytes.length) return null;
    return new Uint8Array(bytes);
  } catch { return null; }
}

//-----------------------------------------------------------------------------
// Carga una imagen del proyecto. La ruta viene del diseño SIN extension, igual
// que en Essentials ("Graphics/UI/menu/fondo"), asi que se prueban las dos que
// el motor acepta.
//
// Devuelve {url, ancho, alto} o null. El resultado se guarda en cache, incluido
// el null: si una imagen no esta, no tiene sentido pedirla en cada repintado (y
// el lienzo se repinta muchas veces por segundo al arrastrar).
//-----------------------------------------------------------------------------
export async function cargarImagen(rutaRelativa) {
  const clave = String(rutaRelativa || "").replace(/\\/g, "/").replace(/\.(png|gif)$/i, "");
  if (!clave) return null;
  if (_cache.has(clave)) return _cache.get(clave);

  let resultado = null;
  if (_raiz) {
    for (const ext of EXTENSIONES) {
      const bytes = await leerBytes(`${_raiz}/${clave}.${ext}`);
      if (!bytes) continue;
      const mime = ext === "gif" ? "image/gif" : "image/png";
      const url = URL.createObjectURL(new Blob([bytes], { type: mime }));
      const medida = await medir(url);
      if (medida) {
        // Se marca si es un GIF, para que el lienzo sepa que hay que repintar
        // seguido y se le vea moverse igual que en el juego.
        resultado = { url, ancho: medida.ancho, alto: medida.alto, animada: ext === "gif" };
        break;
      }
      URL.revokeObjectURL(url);
    }
  }
  _cache.set(clave, resultado);
  return resultado;
}

function medir(url) {
  return new Promise((resolve) => {
    const img = new Image();
    img.onload = () => resolve({ ancho: img.naturalWidth, alto: img.naturalHeight, img });
    img.onerror = () => resolve(null);
    img.src = url;
  });
}

// Igual que cargarImagen pero devuelve tambien el <img> ya listo para dibujar en
// el canvas. Se guarda en el mismo objeto de cache.
export async function imagenDibujable(rutaRelativa) {
  const dato = await cargarImagen(rutaRelativa);
  if (!dato) return null;
  if (dato.img) return dato;
  const m = await medir(dato.url);
  if (!m) return null;
  dato.img = m.img;
  return dato;
}

// Saber si una imagen esta cargada sin lanzar una carga. Lo usa el lienzo para
// dibujar sincrono y pedir la imagen solo cuando falta.
export function imagenEnCache(rutaRelativa) {
  const clave = String(rutaRelativa || "").replace(/\\/g, "/").replace(/\.(png|gif)$/i, "");
  return _cache.has(clave) ? _cache.get(clave) : undefined;
}

// Suelta TODAS las imagenes cargadas. Se llama al cerrar el editor: los blob URLs
// viven mientras viva la pagina, y probar veinte imagenes distintas en una sesion
// dejaba veinte sin soltar. No se llama al cambiar de diseño a proposito: dos
// diseños suelen compartir arte y volver a leerlo de disco seria peor.
export function soltarImagenes() {
  for (const dato of _cache.values()) {
    if (dato && dato.url) URL.revokeObjectURL(dato.url);
  }
  _cache.clear();
}

export function olvidarImagen(rutaRelativa) {
  const clave = String(rutaRelativa || "").replace(/\\/g, "/").replace(/\.(png|gif)$/i, "");
  const dato = _cache.get(clave);
  if (dato && dato.url) URL.revokeObjectURL(dato.url);
  _cache.delete(clave);
}

//-----------------------------------------------------------------------------
// QUE FORMATO ES DE VERDAD ESTE FICHERO.
//
// Las webs de recursos dan WebP con nombre .png, y el juego no los abre: SDL
// corta con "Unsupported image format". Se mira la cabecera de bytes, que no
// miente, en vez de fiarse de la extension.
//-----------------------------------------------------------------------------
export function formatoReal(bytes) {
  if (!bytes || bytes.length < 12) return "desconocido";
  const b = bytes;
  if (b[0] === 0x89 && b[1] === 0x50 && b[2] === 0x4e && b[3] === 0x47) return "png";
  if (b[0] === 0x47 && b[1] === 0x49 && b[2] === 0x46) return "gif";
  if (b[0] === 0xff && b[1] === 0xd8) return "jpeg";
  const rift = String.fromCharCode(b[0], b[1], b[2], b[3]);
  const webp = String.fromCharCode(b[8], b[9], b[10], b[11]);
  if (rift === "RIFF" && webp === "WEBP") return "webp";
  if (b[0] === 0x42 && b[1] === 0x4d) return "bmp";
  const ftyp = String.fromCharCode(b[4], b[5], b[6], b[7]);
  if (ftyp === "ftyp") return "avif";
  return "desconocido";
}

// Los que el juego SI sabe abrir (pbResolveBitmap solo prueba .png y .gif, y SDL
// solo decodifica esos dos en este build).
export const FORMATOS_BUENOS = ["png", "gif"];

//-----------------------------------------------------------------------------
// Convierte una imagen a PNG de verdad, aprovechando que el editor corre dentro
// de un navegador y este SI sabe leer WebP, JPEG y demas.
//
// Esto arregla de raiz el problema mas molesto de meter arte: bajas una imagen,
// se llama .png, y el juego se cae al abrirla porque por dentro es otra cosa. En
// vez de decirle a alguien "convierte el fichero con otro programa", se convierte
// aqui y ya.
//
// Devuelve la ruta relativa del PNG nuevo, o null si no se pudo.
//-----------------------------------------------------------------------------
export async function convertirAPng(rutaRelativa, bytes) {
  if (!_invoke || !_raiz) return null;
  const mime = { webp: "image/webp", jpeg: "image/jpeg", bmp: "image/bmp", avif: "image/avif" }[formatoReal(bytes)] || "image/png";
  try {
    const url = URL.createObjectURL(new Blob([bytes], { type: mime }));
    const img = await new Promise((res, rej) => {
      const i = new Image();
      i.onload = () => res(i);
      i.onerror = () => rej(new Error("el navegador tampoco puede leerla"));
      i.src = url;
    });
    const lienzo = document.createElement("canvas");
    lienzo.width = img.naturalWidth;
    lienzo.height = img.naturalHeight;
    lienzo.getContext("2d").drawImage(img, 0, 0);
    URL.revokeObjectURL(url);

    const blob = await new Promise(res => lienzo.toBlob(res, "image/png"));
    if (!blob) return null;
    const nuevos = new Uint8Array(await blob.arrayBuffer());

    // Se escribe al lado, con el nombre limpio y terminado en .png de verdad.
    const limpia = rutaRelativa.replace(/\.[^./\\]+$/, "").replace(/[^a-zA-Z0-9_/\-]+/g, "_");
    const destino = limpia + ".png";
    await _invoke("write_binary_file", { path: `${_raiz}/${destino}`, data: Array.from(nuevos) });
    olvidarImagen(destino);
    return destino;
  } catch {
    return null;
  }
}

// Lee los bytes de una imagen del proyecto, probando con y sin extension.
export async function bytesDeImagen(rutaRelativa) {
  if (!_raiz) return null;
  const limpia = String(rutaRelativa || "").replace(/\\/g, "/");
  const candidatas = /\.[^./]+$/.test(limpia)
    ? [limpia]
    : [limpia + ".png", limpia + ".gif"];
  for (const c of candidatas) {
    const bytes = await leerBytes(`${_raiz}/${c}`);
    if (bytes) return { ruta: c, bytes };
  }
  return null;
}

//-----------------------------------------------------------------------------
// Las medidas de una imagen SIN decodificarla entera.
//
// Hace falta para clasificar los 108 marcos de la carpeta Windowskins al abrir el
// editor. Cargarlos todos de verdad seria absurdo; get_image_dimensions lee solo
// la cabecera.
//-----------------------------------------------------------------------------
export async function medirGrafico(rutaRelativa) {
  if (!_invoke || !_raiz) return null;
  for (const ext of EXTENSIONES) {
    try {
      const wh = await _invoke("get_image_dimensions", { path: `${_raiz}/${rutaRelativa}.${ext}` });
      if (Array.isArray(wh) && wh.length >= 2) return { ancho: wh[0], alto: wh[1] };
    } catch { /* se prueba la otra extension */ }
  }
  // Si el editor no expone esa orden, se cae a cargar la imagen y mirarla.
  const dato = await cargarImagen(rutaRelativa);
  return dato ? { ancho: dato.ancho, alto: dato.alto } : null;
}

//-----------------------------------------------------------------------------
// La fuente del juego.
//-----------------------------------------------------------------------------
export async function cargarFuente() {
  if (_fuenteLista || !_raiz) return _fuenteLista;

  const cargar = async (fichero, nombre) => {
    const bytes = await leerBytes(`${_raiz}/Fonts/${fichero}`);
    if (!bytes) return false;
    try {
      const cara = new FontFace(nombre, bytes.buffer);
      await cara.load();
      document.fonts.add(cara);
      return true;
    } catch { return false; }
  };

  _fuenteLista = await cargar("power green.ttf", FUENTE);
  // La pequeña es OPCIONAL: si el proyecto no la tiene, fuenteSegunTamano cae a
  // la normal y el editor sigue funcionando (peor, pero igual que el juego, que
  // hace lo mismo por medio de pbGetSmallFontName).
  _pequenaLista = await cargar("power green small.ttf", FUENTE_PEQUENA);
  return _fuenteLista;
}

export function fuenteLista() { return _fuenteLista; }

//-----------------------------------------------------------------------------
// Listar los graficos de una carpeta, para el selector propio.
//
// Se usa list_graphic_files si esta, y si no ctx.fs.listProjectDir, que devuelve
// nombres y con eso basta.
//-----------------------------------------------------------------------------
export async function listarGraficos(ctx, subcarpeta) {
  const limpia = String(subcarpeta || "").replace(/^\/+|\/+$/g, "");
  if (_invoke) {
    try {
      const lista = await _invoke("list_graphic_files", { gameRoot: _raiz, folder: limpia });
      if (Array.isArray(lista) && lista.length) return lista.map(n => String(n));
    } catch { /* se prueba el otro camino */ }
  }
  try {
    const lista = await ctx.fs.listProjectDir("Graphics/" + limpia);
    return (lista || []).map(n => String(n));
  } catch { return []; }
}

// Las carpetas de Graphics/ que tienen sentido para una interfaz.
export async function carpetasGraficos(ctx) {
  const candidatas = ["UI", "Plugins", "Pictures", "Titles", "Battlebacks", "Icons"];
  const salida = [];
  for (const c of candidatas) {
    try {
      const lista = await ctx.fs.listProjectDir("Graphics/" + c);
      if (lista && lista.length) salida.push(c);
    } catch { /* esa carpeta no existe en este proyecto */ }
  }
  return salida;
}
