import test from "node:test";
import assert from "node:assert/strict";
import {readFileSync} from "node:fs";
import {fileURLToPath} from "node:url";
import {dirname,resolve} from "node:path";
import * as model from "../modelo.js";

const root=resolve(dirname(fileURLToPath(import.meta.url)),"..");
const file=name=>readFileSync(resolve(root,name),"utf8");

test("No se pierden los ocho elementos originales",()=>{
  assert.deepEqual(model.TIPOS,["ventana","imagen","texto","boton","panel","animado","barra","pokemon"]);
  for(const tipo of model.TIPOS){
    const item=model.elementoNuevo(tipo,"prueba",12,24);
    assert.equal(item.tipo,tipo);
    assert.equal(item.x,12);
    assert.equal(item.y,24);
  }
});

test("Compatibilidad de las interfaces JSON existentes",()=>{
  const design=model.disenoNuevo("prueba");
  assert.equal(design.lienzo.ancho,512);
  assert.equal(design.lienzo.alto,384);
  assert.equal(design.version,2);
  const parsed=JSON.parse(model.escribirJSON(design));
  assert.equal(parsed.nombre,"prueba");
  assert.ok(Array.isArray(parsed.elementos));
});

test("Los anchors de 2.x se conservan",()=>{
  const design=model.disenoNuevo("anchor");
  const item=model.elementoNuevo("panel","panel_1",100,100);
  item.ancla="abajo_der";
  design.elementos.push(item);
  assert.equal(model.cambiarResolucion(design,640,480,"anchors"),true);
  assert.equal(item.x,228);
  assert.equal(item.y,196);
  assert.equal(design.lienzo.ancho,640);
});

test("El workspace nuevo reutiliza en vez de sustituir los editores",()=>{
  const editor=file("editor.js"),workspace=file("workspace.js");
  for(const original of ["Lienzo","Capas","Inspector","Tiempo","Resolucion"]){
    assert.match(editor,new RegExp("new "+original+"\\s*\\("));
  }
  assert.match(editor,/const CARPETA = "UI";/);
  assert.match(editor,/montarEspacio\(this, M\)/);
  assert.match(workspace,/originalAdd\.forEach/);
  assert.match(workspace,/originalAdd\.filter|originalAdd\.find/);
  assert.match(workspace,/pbInterfaz/);
  assert.match(workspace,/editor\.anadirFondo/);
  assert.match(workspace,/editor\.lienzo\.encajar/);
});

test("La capa de compatibilidad sigue exponiendo herramientas avanzadas",()=>{
  const inspector=file("components/inspector.js");
  const canvas=file("components/lienzo.js");
  const timeline=file("components/tiempo.js");
  for(const name of ["pintarCondiciones","pintarRepeticion","pintarHuecos","pintarAccion","pintarEntrada"]){
    assert.ok(inspector.includes(name),name+" debe seguir disponible");
  }
  assert.ok(canvas.includes("alinear("));
  assert.ok(canvas.includes("repartir("));
  assert.ok(timeline.includes("anadirClave("));
});
