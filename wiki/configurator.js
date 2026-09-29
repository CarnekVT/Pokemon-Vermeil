(function () {
  var token = new URL(window.location.href).searchParams.get('token');
  var state = null;
  var modeNames = [];
  var modeFallbacks = {};
  var bulkModesByVersion = {};
  var bulkMappingDirty = false;
  var trainerVersionCounts = [];
  var playerStarterTypeIds = [];
  var starterTypeNamesById = new Map();
  var familyList = document.getElementById('family-list');
  var modeList = document.getElementById('mode-list');
  var defaultMode = document.getElementById('default-mode');
  var starterIdsByName = new Map();
  var starterNamesById = new Map();
  var status = document.getElementById('save-status');

  function setupTabs() {
    var tabs = Array.from(document.querySelectorAll('[role="tab"]'));
    var panels = tabs.map(function (tab) { return document.getElementById(tab.getAttribute('aria-controls')); });

    function activate(index, focus) {
      tabs.forEach(function (tab, tabIndex) {
        var selected = tabIndex === index;
        tab.setAttribute('aria-selected', String(selected));
        tab.tabIndex = selected ? 0 : -1;
        panels[tabIndex].hidden = !selected;
      });
      if (focus) tabs[index].focus();
    }

    tabs.forEach(function (tab, index) {
      tab.addEventListener('click', function () { activate(index, false); });
      tab.addEventListener('keydown', function (event) {
        var next = index;
        if (event.key === 'ArrowRight') next = (index + 1) % tabs.length;
        else if (event.key === 'ArrowLeft') next = (index + tabs.length - 1) % tabs.length;
        else if (event.key === 'Home') next = 0;
        else if (event.key === 'End') next = tabs.length - 1;
        else return;
        event.preventDefault();
        activate(next, true);
      });
    });
  }

  function element(tag, className, text) {
    var node = document.createElement(tag);
    if (className) node.className = className;
    if (text != null) node.textContent = text;
    return node;
  }

  function option(select, value, label) {
    var item = element('option', '', label);
    item.value = value;
    select.appendChild(item);
  }

  function modesFromForm() {
    return Array.from(modeList.querySelectorAll('.mode-chip strong'))
      .map(function (node) { return node.textContent.trim(); })
      .filter(Boolean);
  }

  function renderModes() {
    modeList.replaceChildren();
    modeNames.forEach(function (name, index) {
      var chip = element('span', 'mode-chip');
      chip.appendChild(element('strong', '', name));
      var remove = element('button', '', '×');
      remove.type = 'button';
      remove.setAttribute('aria-label', 'Quitar modo ' + name);
      remove.addEventListener('click', function () {
        modeNames.splice(index, 1);
        renderModes();
        updateModeSelects();
      });
      chip.appendChild(remove);
      modeList.appendChild(chip);
    });
    updateDefaultModes();
    renderModeFallbacks();
  }

  function renderModeFallbacks() {
    var container = document.getElementById('mode-fallback-list');
    container.replaceChildren();
    if (!modeNames.length) {
      container.appendChild(element('span', 'muted', 'Añade primero los modos de juego.'));
      return;
    }
    modeNames.forEach(function (targetMode) {
      var row = element('div', 'mode-fallback-row');
      row.appendChild(element('strong', '', 'Si falta un equipo para ' + targetMode));
      var control = element('label', 'mode-fallback-control', 'Usar el equipo de');
      var select = element('select');
      select.setAttribute('aria-label', 'Modo alternativo para ' + targetMode);
      option(select, '', 'No usar otro modo');
      modeNames.filter(function (sourceMode) { return sourceMode !== targetMode; }).forEach(function (sourceMode) {
        option(select, sourceMode, sourceMode);
      });
      select.value = modeFallbacks[targetMode] || '';
      select.addEventListener('change', function () {
        if (select.value) modeFallbacks[targetMode] = select.value;
        else delete modeFallbacks[targetMode];
        refreshInheritedModeHints();
      });
      control.appendChild(select);
      row.appendChild(control);
      container.appendChild(row);
    });
  }

  function updateDefaultModes() {
    var selected = defaultMode.value || state.config.default_mode || modeNames[0] || '';
    defaultMode.replaceChildren();
    if (!modeNames.length) option(defaultMode, '', 'Añade un modo primero');
    modeNames.forEach(function (name) { option(defaultMode, name, name); });
    defaultMode.value = modeNames.indexOf(selected) >= 0 ? selected : (modeNames[0] || '');
  }

  function renderVersionModes(container, selected, version) {
    container.replaceChildren();
    container.appendChild(element('span', 'version-mode-label', 'Mostrar este equipo en estos modos'));
    var choices = element('div', 'version-mode-options');
    modeNames.forEach(function (name) {
      var label = element('label', 'version-mode-option');
      var input = element('input', 'version-mode');
      input.type = 'checkbox';
      input.value = name;
      input.checked = selected.indexOf(name) >= 0;
      input.setAttribute('aria-label', 'Mostrar versión del entrenador ' + version + ' en modo ' + name);
      label.appendChild(input);
      label.appendChild(element('span', '', name));
      choices.appendChild(label);
    });
    if (!modeNames.length) choices.appendChild(element('span', 'muted', 'Añade un modo primero'));
    container.appendChild(choices);
    container.appendChild(element('span', 'version-mode-inheritance'));
  }

  function refreshInheritedModeHints() {
    familyList.querySelectorAll('.family-card').forEach(function (card) {
      var rows = Array.from(card.querySelectorAll('.version-row'));
      var customized = card.querySelector('.family-check').checked;
      var directModes = new Map(rows.map(function (row) {
        var modes = customized
          ? Array.from(row.querySelectorAll('.version-mode:checked')).map(function (input) { return input.value; })
          : (bulkModesByVersion[row.dataset.version] || []);
        return [row, modes];
      }));
      var inheritedModes = new Map(rows.map(function (row) { return [row, []]; }));

      function resolveSource(mode, visited) {
        var matches = rows.filter(function (row) { return directModes.get(row).includes(mode); });
        if (matches.length) return matches;
        if (visited.includes(mode) || !modeFallbacks[mode]) return [];
        return resolveSource(modeFallbacks[mode], visited.concat(mode));
      }

      Object.keys(modeFallbacks).forEach(function (targetMode) {
        if (rows.some(function (row) { return directModes.get(row).includes(targetMode); })) return;
        resolveSource(modeFallbacks[targetMode], [targetMode]).forEach(function (row) {
          inheritedModes.get(row).push(targetMode);
        });
      });

      rows.forEach(function (row) {
        var inherited = inheritedModes.get(row);
        var note = row.querySelector('.version-mode-inheritance');
        note.textContent = inherited.length
          ? 'También se usará en ' + inherited.join(' y ') + ' por la regla general.'
          : '';
        note.hidden = !inherited.length;
      });
    });
  }

  function renderPlayerStarterTypes() {
    var container = document.getElementById('player-starter-type-list');
    container.replaceChildren();
    playerStarterTypeIds.forEach(function (id) {
      var chip = element('span', 'mode-chip');
      chip.appendChild(element('strong', '', starterTypeNamesById.get(id) || id));
      var remove = element('button', '', '×');
      remove.type = 'button';
      remove.setAttribute('aria-label', 'Quitar tipo ' + (starterTypeNamesById.get(id) || id));
      remove.addEventListener('click', function () {
        playerStarterTypeIds = playerStarterTypeIds.filter(function (typeId) { return typeId !== id; });
        renderPlayerStarterTypes();
        updateFamilyStarterTypeSelects();
      });
      chip.appendChild(remove);
      container.appendChild(chip);
    });
    if (!playerStarterTypeIds.length) container.appendChild(element('span', 'muted', 'No hay tipos configurados; el filtro no aparecerá en la wiki.'));
  }

  function updateFamilyStarterTypeSelects() {
    familyList.querySelectorAll('.version-starter-type').forEach(function (select) {
      var selected = select.value;
      select.replaceChildren();
      option(select, '', 'Todos los tipos iniciales');
      playerStarterTypeIds.forEach(function (id) { option(select, id, starterTypeNamesById.get(id) || id); });
      select.value = playerStarterTypeIds.indexOf(selected) >= 0 ? selected : '';
    });
  }

  function updateModeSelects() {
    familyList.querySelectorAll('.version-mode-list').forEach(function (container) {
      var selected = Array.from(container.querySelectorAll('.version-mode:checked')).map(function (input) { return input.value; });
      renderVersionModes(container, selected.filter(function (name) { return modeNames.indexOf(name) >= 0; }), container.dataset.version);
    });
    Object.keys(modeFallbacks).forEach(function (targetMode) {
      if (!modeNames.includes(targetMode) || !modeNames.includes(modeFallbacks[targetMode])) delete modeFallbacks[targetMode];
    });
    Object.keys(bulkModesByVersion).forEach(function (version) {
      var current = bulkModesByVersion[version] || [];
      bulkModesByVersion[version] = current.filter(function (name) { return modeNames.indexOf(name) >= 0; });
      if (bulkModesByVersion[version].length !== current.length) bulkMappingDirty = true;
    });
    renderBulkVersionMap();
    renderModeFallbacks();
    updateDefaultModes();
    refreshInheritedModeHints();
  }

  function renderBulkVersionMap() {
    var container = document.getElementById('bulk-version-map');
    container.replaceChildren();
    trainerVersionCounts.forEach(function (entry) {
      var row = element('div', 'bulk-version-row');
      row.dataset.version = entry.version;
      var heading = element('div', 'bulk-version-heading');
      heading.appendChild(element('strong', '', 'Versión del entrenador ' + entry.version));
      heading.appendChild(element('small', '', 'Afecta a ' + entry.combats + (entry.combats === 1 ? ' entrenador' : ' entrenadores')));
      row.appendChild(heading);
      var choices = element('div', 'bulk-version-options');
      var selected = bulkModesByVersion[String(entry.version)] || [];
      modeNames.forEach(function (name) {
        var label = element('label', 'bulk-version-option');
        var input = element('input');
        input.type = 'checkbox';
        input.value = name;
        input.checked = selected.indexOf(name) >= 0;
        input.addEventListener('change', function () {
          bulkModesByVersion[String(entry.version)] = Array.from(choices.querySelectorAll('input:checked')).map(function (choice) { return choice.value; });
          bulkMappingDirty = true;
          document.getElementById('bulk-status').textContent = 'Hay cambios pendientes. Pulsa «Aplicar a todos los entrenadores» antes de guardar.';
        });
        label.appendChild(input);
        label.appendChild(element('span', '', name));
        choices.appendChild(label);
      });
      if (!modeNames.length) choices.appendChild(element('span', 'muted', 'Añade modos en la pestaña «Modos de juego».'));
      row.appendChild(choices);
      container.appendChild(row);
    });
    if (!trainerVersionCounts.length) container.appendChild(element('span', 'muted', 'No se encontraron versiones PBS en los entrenadores.'));
  }

  function applyBulkModes() {
    var status = document.getElementById('bulk-status');
    if (!trainerVersionCounts.length) {
      status.textContent = 'No hay versiones PBS para asignar.';
      return;
    }
    var cards = Array.from(familyList.querySelectorAll('.family-card'));
    cards.forEach(function (card) {
      card.querySelectorAll('.version-row').forEach(function (row) {
        var assigned = bulkModesByVersion[row.dataset.version] || [];
        row.querySelectorAll('.version-mode').forEach(function (input) {
          input.checked = assigned.indexOf(input.value) >= 0;
        });
      });
      var family = state.families.find(function (entry) { return entry.key === card.dataset.familyKey; });
      var hasNonModeCustomization = card.querySelector('.family-label').value.trim() !== family.label ||
        Array.from(card.querySelectorAll('.version-row')).some(function (row) {
          return row.querySelector('.version-starter-type').value || row.querySelector('.version-label-input').value.trim();
        });
      var enabled = card.querySelector('.family-check');
      enabled.checked = hasNonModeCustomization;
      enabled.dispatchEvent(new Event('change'));
    });
    bulkMappingDirty = false;
    refreshInheritedModeHints();
    var summary = trainerVersionCounts.map(function (entry) {
      var modes = bulkModesByVersion[String(entry.version)] || [];
      return modes.length ? 'versión ' + entry.version + ' → ' + modes.join(' / ') : null;
    }).filter(Boolean).join('; ');
    status.textContent = summary ? 'Asignación general aplicada a todos los entrenadores: ' + summary + '. Se conservaron los tipos iniciales y los nombres de combate.' : 'Se quitaron las asignaciones generales. Puedes personalizar cada entrenador abajo.';
  }

  function familyHasCustomization(group, saved) {
    if (saved.label && saved.label !== group.label) return true;
    var baseline = state.config.version_modes || {};
    return group.versions.some(function (version) {
      var assignment = (saved.versions || {})[String(version.version)] || {};
      if (assignment.starter_type || assignment.label) return true;
      var hasModeOverride = Array.isArray(assignment.modes) || !!assignment.mode;
      if (!hasModeOverride) return false;
      var assigned = Array.isArray(assignment.modes) ? assignment.modes : [assignment.mode];
      var inherited = baseline[String(version.version)] || [];
      return JSON.stringify(assigned.slice().sort()) !== JSON.stringify(inherited.slice().sort());
    });
  }

  function buildFamilyCard(group) {
    var saved = (state.config.families || {})[group.key] || {};
    var hasCustomization = familyHasCustomization(group, saved);
    var details = element('details', 'family-card');
    details.dataset.familyKey = group.key;
    details.open = hasCustomization;

    var summary = element('summary');
    var toggle = element('input', 'family-check');
    toggle.type = 'checkbox';
    toggle.checked = hasCustomization;
    toggle.setAttribute('aria-label', 'Personalizar asignación para ' + group.label);
    var summaryText = element('span', 'family-summary');
    summaryText.appendChild(element('strong', '', group.label));
    summaryText.appendChild(element('span', '', group.versions.length + (group.versions.length === 1 ? ' equipo' : ' equipos')));
    var assignmentState = element('span', 'family-assignment-state', hasCustomization ? 'Ajustes propios' : 'Usa la regla general');
    summary.appendChild(summaryText);
    summary.appendChild(assignmentState);
    details.appendChild(summary);

    var customize = element('label', 'family-customize-row');
    customize.appendChild(toggle);
    var customizeText = element('span', 'family-customize-copy');
    customizeText.appendChild(element('strong', '', 'Personalizar este entrenador'));
    customizeText.appendChild(element('small', '', 'Sus ajustes reemplazarán la asignación general.'));
    customize.appendChild(customizeText);
    details.appendChild(customize);

    var content = element('fieldset', 'family-content');
    content.disabled = !toggle.checked;
    toggle.addEventListener('change', function () {
      content.disabled = !toggle.checked;
      assignmentState.textContent = toggle.checked ? 'Ajustes propios' : 'Usa la regla general';
    });

    var labelRow = element('label', 'family-label-row', 'Nombre de esta ficha en la wiki');
    var label = element('input', 'family-label');
    label.type = 'text';
    label.maxLength = 100;
    label.value = saved.label || group.label;
    labelRow.appendChild(label);
    content.appendChild(labelRow);

    var versions = element('div', 'version-list');
    group.versions.forEach(function (version) {
      var assignment = (saved.versions || {})[String(version.version)] || {};
      var row = element('div', 'version-row');
      row.dataset.version = String(version.version);
      var versionTitle = element('div', 'version-row-title');
      versionTitle.appendChild(element('strong', '', 'Versión del entrenador ' + version.version));
      row.appendChild(versionTitle);

      var modeList = element('div', 'version-mode-list');
      modeList.dataset.version = String(version.version);
      var selectedModes = Array.isArray(assignment.modes) ? assignment.modes : (assignment.mode ? [assignment.mode] : ((state.config.version_modes || {})[String(version.version)] || []));
      renderVersionModes(modeList, selectedModes, version.version);
      row.appendChild(modeList);

      var starterType = element('select', 'version-starter-type');
      option(starterType, '', 'Todos los tipos iniciales');
      playerStarterTypeIds.forEach(function (typeId) {
        option(starterType, typeId, starterTypeNamesById.get(typeId) || typeId);
      });
      starterType.setAttribute('aria-label', 'Tipo inicial asociado a la versión ' + version.version);
      var starterTypeControl = element('label', 'version-type-control', 'Asociar a este tipo inicial');
      starterTypeControl.appendChild(starterType);
      var selectedType = assignment.starter_type || version.starter_type;
      starterType.value = playerStarterTypeIds.indexOf(selectedType) >= 0 ? selectedType : '';
      row.appendChild(starterTypeControl);

      var visibleLabel = element('label', 'version-label', 'Nombre de este combate (opcional)');
      var labelInput = element('input', 'version-label-input');
      labelInput.type = 'text';
      labelInput.maxLength = 80;
      labelInput.placeholder = 'Ej. Primer combate o Revancha';
      labelInput.setAttribute('aria-label', 'Nombre visible para la versión ' + version.version);
      labelInput.value = assignment.label || version.label || '';
      visibleLabel.appendChild(labelInput);
      row.appendChild(visibleLabel);

      var team = element('div', 'version-team-preview');
      team.appendChild(element('span', 'version-team-title', 'Equipo de la versión ' + version.version));
      var members = element('div', 'version-team-members');
      if (version.party && version.party.length) {
        version.party.forEach(function (pokemon) {
          var member = element('span', 'version-team-member');
          var name = pokemon.name + (pokemon.shiny ? ' ✦' : '');
          member.appendChild(element('strong', '', name));
          member.appendChild(element('span', '', 'Nv. ' + pokemon.level));
          if (pokemon.types && pokemon.types.length) {
            member.appendChild(element('span', 'version-team-types', pokemon.types.join(' / ')));
          }
          members.appendChild(member);
        });
      } else {
        members.appendChild(element('span', 'muted', 'Sin Pokémon en el equipo'));
      }
      team.appendChild(members);
      row.appendChild(team);
      versions.appendChild(row);
    });
    content.appendChild(versions);
    details.appendChild(content);
    return details;
  }

  function renderFamilies() {
    familyList.replaceChildren();
    state.families.forEach(function (group) { familyList.appendChild(buildFamilyCard(group)); });
    refreshInheritedModeHints();
    filterFamilies();
  }

  function filterFamilies() {
    var query = document.getElementById('family-search').value.trim().toLocaleLowerCase();
    var visible = 0;
    familyList.querySelectorAll('.family-card').forEach(function (card) {
      var searchText = [card.textContent, card.dataset.familyKey].join(' ').toLocaleLowerCase();
      card.hidden = query && !searchText.includes(query);
      if (!card.hidden) visible += 1;
    });
    document.getElementById('family-count').textContent = visible + ' entrenadores con varios equipos';
  }

  function populate() {
    var settings = state.config.settings || {};
    document.getElementById('setting-out').value = settings.out || 'wiki/site';
    var baseline = settings.baseline === 'none' ? '' : (settings.baseline || 'wiki/baseline.json');
    document.getElementById('setting-baseline').value = baseline;
    document.getElementById('setting-compare').checked = settings.baseline !== 'none';
    document.getElementById('setting-sprites').checked = settings.sprites !== false;
    document.getElementById('setting-recompile').checked = settings.recompile !== false;
    document.getElementById('setting-accent-light').value = settings.accent_light || '#1a3d5c';
    document.getElementById('setting-accent-dark').value = settings.accent_dark || '#5ba0d6';
    var features = state.config.features || {};
    document.querySelectorAll('[data-feature]').forEach(function (input) {
      input.checked = features[input.dataset.feature] !== false;
    });

    var candidateSelect = document.getElementById('starter-type-candidate');
    option(candidateSelect, '', 'Selecciona un tipo');
    (state.starter_types || []).forEach(function (type) {
      starterTypeNamesById.set(type.id, type.name);
      option(candidateSelect, type.id, type.name);
    });
    playerStarterTypeIds = (state.config.player_starter_types || []).filter(function (id) { return starterTypeNamesById.has(id); });
    renderPlayerStarterTypes();
    modeNames = (state.config.modes || []).slice();
    modeFallbacks = Object.assign({}, state.config.mode_fallbacks || {});
    bulkModesByVersion = Object.assign({}, state.config.version_modes || {});
    trainerVersionCounts = state.pbs_versions || [];
    renderModes();
    renderBulkVersionMap();
    renderFamilies();
    document.getElementById('family-search').addEventListener('input', filterFamilies);
  }

  function configFromForm() {
    var settings = {
      out: document.getElementById('setting-out').value.trim() || 'wiki/site',
      baseline: document.getElementById('setting-compare').checked ? (document.getElementById('setting-baseline').value.trim() || 'wiki/baseline.json') : 'none',
      sprites: document.getElementById('setting-sprites').checked,
      recompile: document.getElementById('setting-recompile').checked,
      accent_light: document.getElementById('setting-accent-light').value,
      accent_dark: document.getElementById('setting-accent-dark').value
    };
    var features = {};
    document.querySelectorAll('[data-feature]').forEach(function (input) {
      features[input.dataset.feature] = input.checked;
    });
    var families = {};
    familyList.querySelectorAll('.family-card').forEach(function (card) {
      var enabled = card.querySelector('.family-check').checked;
      if (!enabled) return;
      var versions = {};
      card.querySelectorAll('.version-row').forEach(function (row) {
        var modes = Array.from(row.querySelectorAll('.version-mode:checked')).map(function (input) { return input.value; });
        var starterType = row.querySelector('.version-starter-type').value;
        var label = row.querySelector('.version-label-input').value.trim();
        versions[row.dataset.version] = { modes: modes, starter_type: starterType || null, label: label || null };
      });
      families[card.dataset.familyKey] = {
        label: card.querySelector('.family-label').value.trim(),
        versions: versions
      };
    });
    if (bulkMappingDirty) throw new Error('Aplica los cambios generales a todos los entrenadores antes de guardar.');
    var versionModes = {};
    trainerVersionCounts.forEach(function (entry) {
      versionModes[String(entry.version)] = (bulkModesByVersion[String(entry.version)] || []).slice();
    });
    return {
      settings: settings,
      features: features,
      version_modes: versionModes,
      mode_fallbacks: Object.assign({}, modeFallbacks),
      player_starter_types: playerStarterTypeIds.slice(),
      modes: modesFromForm(),
      default_mode: defaultMode.value,
      families: families
    };
  }

  async function request(path, options) {
    options = options || {};
    options.headers = Object.assign({}, options.headers || {}, { 'X-Wiki-Token': token });
    var response = await fetch(path, options);
    var result = await response.json();
    if (!response.ok) throw new Error(result.error || 'No se pudo guardar la configuración.');
    return result;
  }

  async function save(finish) {
    var buttons = [document.getElementById('save-button'), document.getElementById('finish-button')];
    buttons.forEach(function (button) { button.disabled = true; });
    status.textContent = 'Guardando configuración…';
    try {
      var config = configFromForm();
      if (!config.modes.length && Object.keys(config.families).length) throw new Error('Añade al menos un modo antes de configurar equipos.');
      await request('/api/save', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(config) });
      status.textContent = 'Configuración guardada en wiki/config.json.';
      if (finish) {
        await request('/api/finish', { method: 'POST' });
        status.textContent = 'Configuración guardada. La wiki se está generando; puedes cerrar esta pestaña.';
      }
    } catch (error) {
      status.textContent = error.message;
    } finally {
      buttons.forEach(function (button) { button.disabled = false; });
    }
  }

  familyList.addEventListener('change', function (event) {
    if (event.target.matches('.version-mode, .family-check')) refreshInheritedModeHints();
  });

  document.getElementById('add-mode').addEventListener('click', function () {
    var input = document.getElementById('new-mode');
    var name = input.value.trim();
    if (name && modeNames.indexOf(name) < 0) {
      modeNames.push(name);
      input.value = '';
      renderModes();
      updateModeSelects();
    }
  });
  document.getElementById('new-mode').addEventListener('keydown', function (event) {
    if (event.key === 'Enter') {
      event.preventDefault();
      document.getElementById('add-mode').click();
    }
  });
  document.getElementById('bulk-apply').addEventListener('click', applyBulkModes);
  document.getElementById('add-starter-type').addEventListener('click', function () {
    var select = document.getElementById('starter-type-candidate');
    var id = select.value;
    if (!id) {
      document.getElementById('starter-type-status').textContent = 'Selecciona un tipo de la lista.';
      return;
    }
    if (playerStarterTypeIds.indexOf(id) >= 0) {
      document.getElementById('starter-type-status').textContent = 'Ese tipo ya está en la lista.';
      return;
    }
    playerStarterTypeIds.push(id);
    select.value = '';
    document.getElementById('starter-type-status').textContent = '';
    renderPlayerStarterTypes();
    updateFamilyStarterTypeSelects();
  });
  document.getElementById('bulk-clear-modes').addEventListener('click', function () {
    bulkModesByVersion = {};
    trainerVersionCounts.forEach(function (entry) { bulkModesByVersion[String(entry.version)] = []; });
    bulkMappingDirty = true;
    renderBulkVersionMap();
    document.getElementById('bulk-status').textContent = 'Hay cambios pendientes. Pulsa «Aplicar a todos los entrenadores» antes de guardar.';
  });
  document.getElementById('save-button').addEventListener('click', function () { save(false); });
  document.getElementById('finish-button').addEventListener('click', function () { save(true); });

  setupTabs();

  fetch('/api/data?token=' + encodeURIComponent(token), { headers: { 'X-Wiki-Token': token } })
    .then(function (response) { return response.json(); })
    .then(function (data) { state = data; populate(); })
    .catch(function (error) { status.textContent = 'No se pudieron cargar los datos: ' + error.message; });
})();
