(function () {
  var select = document.getElementById('item-sort');
  var list = document.getElementById('item-list');
  if (!select || !list) return;

  var rows = Array.prototype.slice.call(list.querySelectorAll('tr'));
  function sortRows() {
    var mode = select.value;
    rows.sort(function (a, b) {
      var pbsOrder = Number(a.dataset.sortPbs) - Number(b.dataset.sortPbs);
      if (mode === 'pbs') return pbsOrder;
      if (mode === 'pocket') {
        var pocketOrder = Number(a.dataset.sortPocket) - Number(b.dataset.sortPocket);
        if (pocketOrder) return pocketOrder;
      }
      var nameOrder = a.dataset.sortName.localeCompare(b.dataset.sortName, 'es', { sensitivity: 'base' });
      return nameOrder || pbsOrder;
    });
    rows.forEach(function (row) { list.appendChild(row); });
  }

  select.addEventListener('change', sortRows);
  sortRows();
})();
