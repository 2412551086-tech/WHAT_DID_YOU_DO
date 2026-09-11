(() => {
  const key = 'douxiaolang-language';
  const current = document.documentElement.lang.startsWith('zh') ? 'zh' : 'en';
  const route = document.body.dataset.route || '/';
  const languages = navigator.languages?.length ? navigator.languages : [navigator.language || 'en'];
  const device = languages[0].toLowerCase().startsWith('zh') ? 'zh' : 'en';
  let preference = 'auto';
  try { preference = localStorage.getItem(key) || 'auto'; } catch {}
  if (!['auto', 'zh', 'en'].includes(preference)) preference = 'auto';
  const target = preference === 'auto' ? device : preference;
  const destination = (locale, explicit = false) => (locale === 'en' ? '/en' : '') + route + (explicit ? `?lang=${locale}` : '') + location.hash;
  const requested = new URLSearchParams(location.search).get('lang');
  // Explicit links remain usable even when browser storage is unavailable.
  if (requested === 'zh' || requested === 'en') {
    preference = requested;
    try { localStorage.setItem(key, requested); } catch {}
    if (requested !== current) { location.replace(destination(requested, true)); return; }
  } else if (target !== current) {
    location.replace(destination(target));
    return;
  }
  const selector = document.querySelector('#language');
  if (!selector) return;
  selector.value = preference;
  selector.addEventListener('change', () => {
    const value = selector.value;
    try { localStorage.setItem(key, value); } catch {}
    const locale = value === 'auto' ? device : value;
    location.assign(destination(locale, value !== 'auto'));
  });
})();
