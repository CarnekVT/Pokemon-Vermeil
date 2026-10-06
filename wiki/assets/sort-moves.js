(function () {
  var selects = document.querySelectorAll('[data-move-sort]');
  Array.prototype.forEach.call(selects, function (select) {
    var list = document.getElementById(select.dataset.target);
    if (!list) return;

    var rows = Array.prototype.slice.call(list.querySelectorAll('tr'));
    function sortRows() {
      var mode = select.value;
      rows.sort(function (a, b) {
        var pbsOrder = Number(a.dataset.sortPbs) - Number(b.dataset.sortPbs);
        if (mode === 'pbs') return pbsOrder;
        if (mode === 'level') {
          var levelOrder = Number(a.dataset.sortLevel) - Number(b.dataset.sortLevel);
          if (levelOrder) return levelOrder;
        }
        if (mode === 'type') {
          var typeOrder = a.dataset.sortType.localeCompare(b.dataset.sortType, 'es', { sensitivity: 'base' });
          if (typeOrder) return typeOrder;
        }
        var nameOrder = a.dataset.sortName.localeCompare(b.dataset.sortName, 'es', { sensitivity: 'base' });
        return nameOrder || pbsOrder;
      });
      rows.forEach(function (row) { list.appendChild(row); });
    }

    select.addEventListener('change', sortRows);
    sortRows();
  });
})();
