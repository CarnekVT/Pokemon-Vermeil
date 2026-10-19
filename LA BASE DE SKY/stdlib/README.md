# Ruby 3.1 - librerías para mkxp-z-ext Luka

Aquí se incluyen JSON oficial 2.6.3 (Ruby 3.1) y fuentes de Ruby 3.1.0 de FileUtils y OpenStruct; NO son el plugin JSON Compatibility.

La ruta activa se configura en mkxp.json como `rubyLoadpath` apuntando a `stdlib`. JSON intenta primero su extensión nativa y, si no está disponible, usa el parser puro oficial que necesita la extensión `strscan` de Ruby. Para el mayor rendimiento y plena compatibilidad, completar la biblioteca Ruby 3.1 con `stdlib` de la misma compilación Windows de mkxp-z-ext Luka 68e8823; no copiar extensiones binarias Ruby 3.3.

Comprobar con `require 'json'; require 'fileutils'; p JSON.parse('{"ok":true}')`. No hace falta reinstalar el plugin JSON Compatibility.

JSON 2.6.3: https://github.com/ruby/json/tree/v2.6.3 (LICENSE-json.txt)
Ruby 3.1: https://github.com/ruby/ruby/tree/v3_1_0 (COPYING-Ruby.txt)
