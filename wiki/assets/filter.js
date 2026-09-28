// Filtros locales de la Pokédex, listados de datos y ubicaciones.
(function () {
  var search = document.getElementById('page-search');
  var dexFilter = document.getElementById('dex-change-filter');
  var toggle = document.getElementById('changes-only');
  var entries = Array.prototype.slice.call(document.querySelectorAll('[data-page-search-entry]'));
  var count = document.getElementById('list-count');
  var empty = document.getElementById('filter-empty');
  if (!entries.length) return;

  function normalize(value) {
    return value.toLocaleLowerCase().normalize('NFD').replace(/[\u0300-\u036f]/g, '');
  }

  function update() {
    var query = normalize(search ? search.value.trim() : '');
    var mode = dexFilter ? dexFilter.value : 'all';
    var visible = 0;
    entries.forEach(function (entry) {
      var text = entry.getAttribute('data-search-text') || entry.textContent;
      var matchesText = !query || normalize(text).includes(query);
      var hasChange = entry.getAttribute('data-has-change') === 'true';
      var relevant = entry.getAttribute('data-change-relevant') === 'true';
      var matchesChange = mode === 'all' || (mode === 'relevant' && relevant) || (mode === 'changed' && hasChange);
      if (toggle && toggle.checked) matchesChange = entry.getAttribute('data-change-status') !== 'sin-cambios';
      var show = matchesText && matchesChange;
      entry.hidden = !show;
      if (show) visible += 1;
    });
    if (count) count.textContent = visible + ' resultados';
    if (empty) empty.hidden = visible > 0;
  }

  if (search) search.addEventListener('input', update);
  if (dexFilter) dexFilter.addEventListener('change', update);
  if (toggle) toggle.addEventListener('change', update);
  update();
})();
