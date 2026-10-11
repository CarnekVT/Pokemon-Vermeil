export function installStyles() {
  if (document.getElementById("pokemon-shiny-studio-styles")) return;
  const style = document.createElement("style");
  style.id = "pokemon-shiny-studio-styles";
  style.textContent = `
    .pss-root {
      display: flex;
      flex-direction: column;
      width: 100%;
      height: 100%;
      background: #12141a;
      color: #e2e8f0;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
      font-size: 13px;
      user-select: none;
      box-sizing: border-box;
      overflow: hidden;
    }
    .pss-root * { box-sizing: border-box; }

    /* Top Bar */
    .pss-topbar {
      display: flex;
      align-items: center;
      justify-content: space-between;
      padding: 8px 16px;
      background: #1a1d26;
      border-bottom: 1px solid #282c38;
      gap: 12px;
      flex-wrap: wrap;
    }
    .pss-title {
      font-weight: 700;
      font-size: 15px;
      display: flex;
      align-items: center;
      gap: 8px;
      color: #fbbf24;
    }
    .pss-tabs {
      display: flex;
      gap: 4px;
      align-items: center;
    }
    .pss-tab {
      background: #242938;
      border: 1px solid #333a4d;
      color: #94a3b8;
      padding: 5px 12px;
      border-radius: 6px;
      cursor: pointer;
      font-size: 12px;
      font-weight: 500;
      transition: all 0.15s ease;
      display: flex;
      align-items: center;
      gap: 6px;
    }
    .pss-tab:hover { background: #2f364a; color: #f8fafc; }
    .pss-tab.active {
      background: #3b82f6;
      border-color: #60a5fa;
      color: #ffffff;
      font-weight: 600;
      box-shadow: 0 0 10px rgba(59, 130, 246, 0.4);
    }
    .pss-tab.tab-shiny.active {
      background: #eab308;
      border-color: #facc15;
      color: #1a1500;
      box-shadow: 0 0 10px rgba(234, 179, 8, 0.4);
    }
    .pss-tab.tab-supershiny.active {
      background: #a855f7;
      border-color: #c084fc;
      color: #ffffff;
      box-shadow: 0 0 12px rgba(168, 85, 247, 0.5);
    }
    .pss-tab.tab-custom.active {
      background: #06b6d4;
      border-color: #22d3ee;
      color: #ffffff;
      box-shadow: 0 0 10px rgba(6, 182, 212, 0.4);
    }
    .pss-btn-add-variant {
      background: #1e293b;
      border: 1px dashed #475569;
      color: #94a3b8;
      padding: 5px 10px;
      border-radius: 6px;
      cursor: pointer;
      font-size: 12px;
      transition: all 0.15s ease;
    }
    .pss-btn-add-variant:hover {
      background: #334155;
      color: #38bdf8;
      border-color: #38bdf8;
    }

    .pss-actions {
      display: flex;
      gap: 8px;
      align-items: center;
    }
    .pss-btn-primary {
      background: #22c55e;
      border: none;
      color: #ffffff;
      padding: 6px 14px;
      border-radius: 6px;
      cursor: pointer;
      font-weight: 600;
      font-size: 12px;
      display: flex;
      align-items: center;
      gap: 6px;
      box-shadow: 0 2px 6px rgba(34, 197, 94, 0.3);
      transition: all 0.15s ease;
    }
    .pss-btn-primary:hover { background: #16a34a; }
    .pss-btn-primary:active { transform: scale(0.97); }

    .pss-btn-secondary {
      background: #202937;
      border: 1px solid #344154;
      color: #edf2f7;
      padding: 7px 12px;
      border-radius: 6px;
      cursor: pointer;
      font-size: 12px;
      display: flex;
      align-items: center;
      justify-content: center;
      gap: 6px;
      transition: background 0.12s ease, border-color 0.12s ease, transform 0.1s ease;
      width: 100%;
      text-align: center;
      box-sizing: border-box;
      white-space: nowrap;
    }
    .pss-btn-secondary:hover {
      background: #273446;
      border-color: #465a73;
    }
    .pss-btn-secondary:active {
      transform: scale(0.98);
    }

    .pss-btn-sm {
      background: #202937;
      border: 1px solid #344154;
      color: #cbd5e1;
      padding: 3px 8px;
      border-radius: 4px;
      cursor: pointer;
      font-size: 11px;
      display: inline-flex;
      align-items: center;
      gap: 4px;
      transition: all 0.12s ease;
    }
    .pss-btn-sm:hover {
      background: #273446;
      color: #ffffff;
      border-color: #465a73;
    }

    /* Main Container */
    .pss-body {
      display: flex;
      flex: 1;
      overflow: hidden;
    }

    /* Left Sidebar: Species */
    .pss-sidebar {
      width: 260px;
      min-width: 220px;
      background: #161820;
      border-right: 1px solid #232733;
      display: flex;
      flex-direction: column;
    }
    .pss-sidebar-search {
      padding: 10px;
      border-bottom: 1px solid #232733;
    }
    .pss-input {
      width: 100%;
      background: #1f2330;
      border: 1px solid #33394a;
      color: #f8fafc;
      padding: 6px 10px;
      border-radius: 5px;
      font-size: 12px;
      outline: none;
    }
    .pss-input:focus { border-color: #3b82f6; }
    .pss-species-list {
      flex: 1;
      overflow-y: auto;
      padding: 4px;
    }
    .pss-species-item {
      display: flex;
      align-items: center;
      gap: 10px;
      padding: 6px 10px;
      border-radius: 6px;
      cursor: pointer;
      transition: background 0.1s ease;
      margin-bottom: 2px;
    }
    .pss-species-item:hover { background: #202433; }
    .pss-species-item.selected {
      background: #2563eb;
      color: #ffffff;
      font-weight: 600;
    }
    .pss-species-icon {
      width: 32px;
      height: 32px;
      image-rendering: pixelated;
      background: #0f1117;
      border-radius: 4px;
      object-fit: contain;
    }
    .pss-species-info {
      flex: 1;
      min-width: 0;
    }
    .pss-species-name {
      font-size: 12px;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
    }
    .pss-species-id {
      font-size: 10px;
      color: #94a3b8;
    }
    .pss-species-item.selected .pss-species-id { color: #cbd5e1; }

    /* Center Area: Preview Canvas */
    .pss-center {
      flex: 1;
      display: flex;
      flex-direction: column;
      background: #0d0f14;
      overflow: auto;
    }
    .pss-center-toolbar {
      padding: 8px 16px;
      background: #141720;
      border-bottom: 1px solid #232733;
      display: flex;
      align-items: center;
      gap: 12px;
    }
    .pss-canvas-grid {
      flex: 1;
      display: flex;
      justify-content: center;
      align-items: center;
      padding: 24px;
      gap: 24px;
      flex-wrap: wrap;
    }
    .pss-preview-card {
      background: #161822;
      border: 1px solid #282c3c;
      border-radius: 8px;
      padding: 12px;
      display: flex;
      flex-direction: column;
      align-items: center;
      gap: 8px;
      box-shadow: 0 4px 16px rgba(0, 0, 0, 0.4);
    }
    .pss-preview-title {
      font-size: 11px;
      font-weight: 600;
      color: #94a3b8;
      text-transform: uppercase;
      letter-spacing: 0.5px;
    }
    .pss-canvas-wrapper {
      position: relative;
      background: #232734;
      background-image: 
        linear-gradient(45deg, #1c202c 25%, transparent 25%), 
        linear-gradient(-45deg, #1c202c 25%, transparent 25%), 
        linear-gradient(45deg, transparent 75%, #1c202c 75%), 
        linear-gradient(-45deg, transparent 75%, #1c202c 75%);
      background-size: 16px 16px;
      background-position: 0 0, 0 8px, 8px -8px, -8px 0;
      border-radius: 6px;
      overflow: hidden;
      border: 1px solid #383e52;
      display: flex;
      justify-content: center;
      align-items: center;
      min-width: 192px;
      min-height: 192px;
    }
    .pss-canvas-wrapper.canvas-icon {
      min-width: 128px;
      min-height: 128px;
    }
    .pss-canvas {
      image-rendering: pixelated;
      display: block;
    }

    /* Right Panel: Editing Tools */
    .pss-tools-panel {
      width: 340px;
      min-width: 300px;
      background: #161820;
      border-left: 1px solid #232733;
      display: flex;
      flex-direction: column;
      overflow-y: auto;
    }
    .pss-panel-section {
      padding: 14px;
      border-bottom: 1px solid #232733;
    }
    .pss-section-title {
      font-size: 12px;
      font-weight: 700;
      color: #f1f5f9;
      margin-bottom: 10px;
      display: flex;
      align-items: center;
      justify-content: space-between;
    }
    .pss-mode-selector {
      display: flex;
      gap: 4px;
      background: #1f2330;
      padding: 3px;
      border-radius: 6px;
      margin-bottom: 12px;
    }
    .pss-mode-btn {
      flex: 1;
      text-align: center;
      padding: 6px;
      border-radius: 4px;
      font-size: 11px;
      cursor: pointer;
      color: #94a3b8;
      border: none;
      background: transparent;
      transition: all 0.15s ease;
    }
    .pss-mode-btn.active {
      background: #3b82f6;
      color: #ffffff;
      font-weight: 600;
    }

    /* Sliders */
    .pss-slider-group {
      margin-bottom: 12px;
    }
    .pss-slider-label {
      display: flex;
      justify-content: space-between;
      font-size: 11px;
      color: #cbd5e1;
      margin-bottom: 4px;
    }
    .pss-slider {
      width: 100%;
      height: 6px;
      border-radius: 3px;
      background: #2d3345;
      outline: none;
      -webkit-appearance: none;
      cursor: pointer;
    }
    .pss-slider::-webkit-slider-thumb {
      -webkit-appearance: none;
      width: 14px;
      height: 14px;
      border-radius: 50%;
      background: #38bdf8;
      cursor: pointer;
      box-shadow: 0 0 6px rgba(56, 189, 248, 0.6);
    }

    /* Palette Grid */
    .pss-palette-grid {
      display: grid;
      grid-template-columns: repeat(4, 1fr);
      gap: 8px;
      max-height: 240px;
      overflow-y: auto;
      padding-right: 4px;
    }
    .pss-palette-item {
      display: flex;
      flex-direction: column;
      align-items: center;
      background: #1c202d;
      border: 1px solid #2c3245;
      border-radius: 6px;
      padding: 6px;
      gap: 4px;
    }
    .pss-color-box {
      width: 32px;
      height: 32px;
      border-radius: 4px;
      border: 1px solid rgba(255, 255, 255, 0.2);
      cursor: pointer;
      position: relative;
    }
    .pss-color-input {
      position: absolute;
      top: 0;
      left: 0;
      width: 100%;
      height: 100%;
      opacity: 0;
      cursor: pointer;
    }
    .pss-color-hex {
      font-size: 9px;
      color: #94a3b8;
      font-family: monospace;
    }

    /* Modal */
    .pss-modal-backdrop {
      position: fixed;
      top: 0;
      left: 0;
      right: 0;
      bottom: 0;
      background: rgba(0, 0, 0, 0.7);
      backdrop-filter: blur(2px);
      display: flex;
      justify-content: center;
      align-items: center;
      z-index: 99999;
    }
    .pss-modal {
      background: #181b24;
      border: 1px solid #333a4d;
      border-radius: 8px;
      width: 420px;
      padding: 20px;
      box-shadow: 0 10px 30px rgba(0, 0, 0, 0.6);
      display: flex;
      flex-direction: column;
      gap: 14px;
    }
    .pss-modal-title {
      font-size: 14px;
      font-weight: 700;
      color: #38bdf8;
    }
    .pss-modal-field {
      display: flex;
      flex-direction: column;
      gap: 4px;
    }
    .pss-modal-field label {
      font-size: 11px;
      color: #94a3b8;
    }
    .pss-modal-footer {
      display: flex;
      justify-content: flex-end;
      gap: 8px;
      margin-top: 10px;
    }
  `;
  document.head.appendChild(style);
}
