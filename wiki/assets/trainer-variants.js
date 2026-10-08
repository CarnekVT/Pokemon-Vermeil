(function () {
  var detail = document.querySelector('[data-trainer-detail]');
  if (!detail) return;

  var modeSelect = detail.querySelector('[data-trainer-mode]');
  var starterOptions = Array.prototype.slice.call(detail.querySelectorAll('[data-trainer-starter-option]'));
  var variants = Array.prototype.slice.call(detail.querySelectorAll('[data-trainer-variant]'));
  var empty = detail.querySelector('[data-trainer-no-match]');
  var modeKey = 'wiki-trainer-mode';
  var starterKey = 'wiki-trainer-starter-type';

  function restore(select, key, fallback) {
    if (!select) return;
    var saved = null;
    try { saved = localStorage.getItem(key); } catch (e) {}
    var valid = Array.prototype.some.call(select.options, function (option) { return option.value === saved; });
    if (valid) select.value = saved;
    else if (fallback && Array.prototype.some.call(select.options, function (option) { return option.value === fallback; })) select.value = fallback;
  }

  function update() {
    var mode = modeSelect ? modeSelect.value : 'all';
    var selectedStarter = starterOptions.find(function (option) { return option.checked; });
    var starter = selectedStarter ? selectedStarter.value : 'all';
    var visible = 0;
    variants.forEach(function (variant) {
      var assignedModes = JSON.parse(variant.dataset.modes || '[]');
      var matchesMode = mode === 'all' || assignedModes.indexOf(mode) >= 0 || variant.dataset.mode === mode;
      var matchesStarter = starter === 'all' || !variant.dataset.starter || variant.dataset.starter === starter;
      variant.hidden = !(matchesMode && matchesStarter);
      if (!variant.hidden) visible += 1;
    });
    if (empty) empty.hidden = visible > 0;
    try {
      if (modeSelect) localStorage.setItem(modeKey, mode);
      if (starterOptions.length) localStorage.setItem(starterKey, starter);
    } catch (e) {}
  }

  if (modeSelect) {
    restore(modeSelect, modeKey, detail.dataset.defaultMode);
    modeSelect.addEventListener('change', update);
  }
  if (starterOptions.length) {
    var savedStarter = null;
    try { savedStarter = localStorage.getItem(starterKey); } catch (e) {}
    var matchingStarter = starterOptions.find(function (option) { return option.value === savedStarter; });
    if (matchingStarter) matchingStarter.checked = true;
    starterOptions.forEach(function (option) { option.addEventListener('change', update); });
  }
  update();
})();
