// Buscador cliente. El índice se carga como script (buscar.js -> window.WIKI_SEARCH),
// así funciona también abriendo los HTML directamente (file://), sin servidor.
(function () {
  var input = document.getElementById('q');
  var box = document.getElementById('results');
  var items = window.WIKI_SEARCH;
  if (!input || !box || !items) return;

  var root = window.WIKI_ROOT || '';
  var COMBINING = new RegExp('[\\u0300-\\u036f]', 'g');
  var norm = function (s) { return s.toLowerCase().normalize('NFD').replace(COMBINING, ''); };
  var keys = items.map(function (it) { return norm(it.n); });

  function run() {
    var q = norm(input.value.trim());
    if (q.length < 2) { box.hidden = true; box.innerHTML = ''; return; }
    var hits = [];
    for (var i = 0; i < items.length && hits.length < 40; i++) {
      if (keys[i].indexOf(q) !== -1) hits.push(items[i]);
    }
    hits.sort(function (a, b) { return norm(a.n).indexOf(q) - norm(b.n).indexOf(q); });
    box.innerHTML = hits.map(function (it) {
      var extra = it.x ? ' · ' + it.x : '';
      return '<a href="' + root + it.u + '"><span>' + it.n + '</span>' +
             '<span class="cat">' + it.c + extra + '</span></a>';
    }).join('');
    box.hidden = hits.length === 0;
  }

  input.addEventListener('input', run);
  input.addEventListener('focus', run);
  input.addEventListener('keydown', function (e) { if (e.key === 'Escape') { box.hidden = true; input.blur(); } });
  document.addEventListener('click', function (e) {
    if (e.target !== input && !box.contains(e.target)) box.hidden = true;
  });
})();
