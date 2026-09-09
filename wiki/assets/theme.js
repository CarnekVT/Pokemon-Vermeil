// Alterna tema claro/oscuro y lo recuerda. El tema inicial ya lo fija un script
// en el <head> para evitar el parpadeo.
(function () {
  var btn = document.getElementById('theme-toggle');
  if (!btn) return;
  btn.addEventListener('click', function () {
    var now = document.documentElement.getAttribute('data-theme') === 'dark' ? 'light' : 'dark';
    document.documentElement.setAttribute('data-theme', now);
    try { localStorage.setItem('wiki-theme', now); } catch (e) {}
  });
})();
