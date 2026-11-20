/* Theme preference only. It does not access or modify Supabase data. */
(() => {
  const control = document.getElementById('themeMode');
  if (!control) return;

  const storageKey = 'finance-control-theme';
  let savedTheme = null;
  try {
    savedTheme = localStorage.getItem(storageKey);
  } catch (_) {
    // Storage may be unavailable in private browsing; system preference still works.
  }

  const prefersDark = window.matchMedia?.('(prefers-color-scheme: dark)').matches ?? false;
  const initialTheme = savedTheme === 'dark' || savedTheme === 'light'
    ? savedTheme
    : (prefersDark ? 'dark' : 'light');

  const applyTheme = theme => {
    document.documentElement.dataset.theme = theme;
    control.checked = theme === 'dark';
    control.setAttribute('aria-label', theme === 'dark' ? 'Desativar tema escuro' : 'Ativar tema escuro');
    try {
      localStorage.setItem(storageKey, theme);
    } catch (_) {
      // Theme remains active for the current page even without persistent storage.
    }
  };

  applyTheme(initialTheme);
  control.addEventListener('change', () => applyTheme(control.checked ? 'dark' : 'light'));
})();
