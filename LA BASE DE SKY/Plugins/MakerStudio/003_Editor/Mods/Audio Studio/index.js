import { installStyles } from './styles.js';
import { AudioStudioUI } from './ui.js';

const PANEL_ID = 'com.carnek.audio-studio.panel';
let removeStyles = null;

function openAudioStudio(ctx) {
  try {
    ctx.ui.openPanel(PANEL_ID);
    ctx.log.info('Audio Studio panel opened');
  } catch (err) {
    ctx.log.error(err);
    try {
      ctx.ui.showToast({
        message: `Audio Studio could not open: ${err?.message || err}`,
        level: 'error',
        durationMs: 0,
      });
    } catch {}
  }
}

export function activate(ctx) {
  ctx.log.info(`Audio Studio 0.8.0 loading (API ${ctx.apiVersion || 'unknown'})`);

  // Register the panel first. Styles are installed only when a real DOM host exists,
  // so a document/style problem can never prevent the mod from registering its UI.
  ctx.ui.registerPanel({
    id: PANEL_ID,
    title: 'Audio Studio',
    icon: '🎵',
    defaultPosition: 'right',
    defaultSize: { width: 1500, height: 860 },
    showInMenu: true,
    render(host) {
      try {
        if (!removeStyles) removeStyles = installStyles(host.ownerDocument || document);
        const ui = new AudioStudioUI(ctx, host);
        return ui.mount();
      } catch (err) {
        ctx.log.error(err);
        host.innerHTML = `
          <div style="padding:16px;color:var(--text-primary);background:var(--bg-primary);height:100%;box-sizing:border-box">
            <h2 style="margin-top:0">Audio Studio failed to render</h2>
            <p>${String(err?.message || err).replace(/[&<>\"]/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c]))}</p>
            <p style="color:var(--text-secondary)">Open Mods → Mod Manager → Audio Studio to see the full log.</p>
          </div>`;
        return () => {};
      }
    },
  });

  // Extra explicit launcher in Tools. The native Mods entry above is intentionally
  // kept enabled too, so there are two independent ways to reopen the panel.
  ctx.menu.registerMenuItem({
    menu: 'Tools',
    label: 'Audio Studio',
    icon: '🎵',
    shortcut: 'Ctrl+Shift+A',
    handler: () => openAudioStudio(ctx),
  });

  ctx.commands.register('com.carnek.audio-studio.open', () => {
    openAudioStudio(ctx);
    return true;
  });

  // Audio Studio is intentionally not auto-opened. Open it from Mods or Tools.
  ctx.lifecycle.onDeactivate(() => {
    try { ctx.editor.setStatusBarText?.(null); } catch {}
  });

  ctx.log.info('Audio Studio UI registered');
}

export function deactivate() {
  if (removeStyles) removeStyles();
  removeStyles = null;
}
