// Alterna tema claro/oscuro y lo recuerda. El tema inicial ya lo fija un script
// en el <head> para evitar el parpadeo.
(function () {
  var btn = document.getElementById('theme-toggle');
  if (!btn) return;
  function setTheme(theme) {
    if (theme === 'dark') {
      document.documentElement.setAttribute('data-theme', 'dark');
    } else {
      document.documentElement.removeAttribute('data-theme');
    }
    btn.setAttribute('aria-pressed', String(theme === 'dark'));
  }

  setTheme(document.documentElement.getAttribute('data-theme') === 'dark' ? 'dark' : 'light');
  btn.addEventListener('click', function () {
    var now = document.documentElement.getAttribute('data-theme') === 'dark' ? 'light' : 'dark';
    setTheme(now);
    try { localStorage.setItem('wiki-theme', now); } catch (e) {}
  });
})();
