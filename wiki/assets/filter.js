// Filtros locales de la Pokédex, listados de datos y ubicaciones.
(function () {
  var search = document.getElementById('page-search');
  var dexFilter = document.getElementById('dex-change-filter');
  var trainerMode = document.getElementById('trainer-mode-filter');
  var trainerStarterOptions = Array.prototype.slice.call(document.querySelectorAll('[data-trainer-starter-picker] [data-trainer-starter-option]'));
  var toggle = document.getElementById('changes-only');
  var entries = Array.prototype.slice.call(document.querySelectorAll('[data-page-search-entry]'));
  var count = document.getElementById('list-count');
  var empty = document.getElementById('filter-empty');
  if (!entries.length) return;

  var trainerModeKey = 'wiki-trainer-mode';
  var trainerStarterKey = 'wiki-trainer-starter-type';
  if (trainerMode) {
    try {
      var savedMode = localStorage.getItem(trainerModeKey);
      if (Array.prototype.some.call(trainerMode.options, function (option) { return option.value === savedMode; })) trainerMode.value = savedMode;
    } catch (e) {}
  }
  if (trainerStarterOptions.length) {
    try {
      var savedStarter = localStorage.getItem(trainerStarterKey);
      var matchingStarter = trainerStarterOptions.find(function (option) { return option.value === savedStarter; });
      if (matchingStarter) matchingStarter.checked = true;
    } catch (e) {}
  }

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
      var modes = [];
      try { modes = JSON.parse(entry.getAttribute('data-trainer-modes') || '[]'); } catch (e) {}
      var modeValue = trainerMode ? trainerMode.value : 'all';
      var matchesTrainerMode = !trainerMode || modeValue === 'all' || entry.getAttribute('data-trainer-common') === 'true' || modes.indexOf(modeValue) >= 0;
      var show = matchesText && matchesChange && matchesTrainerMode;
      entry.hidden = !show;
      if (show) visible += 1;
    });
    if (count) count.textContent = visible + ' resultados';
    if (empty) empty.hidden = visible > 0;
  }

  if (search) search.addEventListener('input', update);
  trainerStarterOptions.forEach(function (option) {
    option.addEventListener('change', function () {
      if (option.checked) {
        try { localStorage.setItem(trainerStarterKey, option.value); } catch (e) {}
      }
    });
  });
  if (dexFilter) dexFilter.addEventListener('change', update);
  if (trainerMode) trainerMode.addEventListener('change', function () {
    try { localStorage.setItem(trainerModeKey, trainerMode.value); } catch (e) {}
    update();
  });
  if (toggle) toggle.addEventListener('change', update);
  update();
})();
