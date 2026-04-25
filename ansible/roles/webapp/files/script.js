// Status probe — simple sanity check
(function () {
    const el = document.getElementById('statusLine');
    fetch('/healthz')
        .then((r) => (r.ok ? 'OK' : 'KO'))
        .then((s) => {
            el.textContent = 'Service webapp : ' + s + ' — ' + new Date().toLocaleString('fr-FR');
        })
        .catch(() => {
            el.textContent = 'Service webapp : KO (probe échoué)';
        });
})();
