// The live phone preview beside the editor: one large phone that follows the
// field being edited, a strip of every screen, and an "All screens" grid.
// The app's own timings are kept: the slideshow moves every 2s and the
// social-proof strip every 3s, as phone_screen.dart and paywall_screen.dart do.

import { resolveConfig } from "./resolve.js";
import { accentColors, colorScheme, cssVars } from "./theme.js";
import { renderScreen, SCREEN_H, SCREEN_W, SCREENS } from "./screens.js";

const FRAME_W = SCREEN_W + 16;
const FRAME_H = SCREEN_H + 16;
const SLIDE_MS = 2000;
const SOCIAL_MS = 3000;
const FADE_MS = 125;
const WEB_DEBOUNCE_MS = 700;
const GRID_GAP = 16;
const CAPTION_H = 26;
// Parts that are hidden while blank; focusing their field shows a ghost.
const GHOSTABLE = new Set(["subtitle", "rating", "media", "social", "carousel"]);

const phoneHtml = (attrs = "") =>
  `<div class="phone" ${attrs}><div class="phone-screen"><div class="screen-host"></div></div></div>`;

const TEMPLATE = `
  <div class="pv-bar">
    <div class="pv-heading"><span class="ms">smartphone</span> Live preview</div>
    <div class="pv-actions">
      <button type="button" class="pv-chip" data-act="sound" hidden></button>
      <button type="button" class="pv-chip" data-act="dark"></button>
      <button type="button" class="pv-chip" data-act="mode"></button>
    </div>
  </div>
  <div class="pv-focus">
   <div class="pv-main">
    <div class="pv-thumbs" role="tablist" aria-label="Screens" aria-orientation="vertical">
      ${SCREENS.map((s) => `
        <button type="button" class="pv-thumb" role="tab" data-screen="${s.id}" title="${s.label}">
          <span class="pv-thumb-frame">${phoneHtml()}</span>
          <span class="pv-thumb-label">${s.label}</span>
        </button>`).join("")}
    </div>
    <div class="pv-stage">
      <div class="pv-scaler">
        <div class="phone" data-live>
          <div class="phone-screen">
            <div class="screen-host"></div>
            <div class="web-layer" hidden>
              <!-- No allow-same-origin: a page can never reach this panel's
                   storage (the admin password), whatever link is typed. -->
              <iframe title="Web page preview" referrerpolicy="no-referrer"
                sandbox="allow-scripts allow-forms allow-popups"></iframe>
            </div>
          </div>
        </div>
      </div>
    </div>
   </div>
    <div class="pv-hint" aria-live="polite"></div>
  </div>
  <div class="pv-grid" hidden>
    ${SCREENS.map((s) => `
      <figure class="pv-cell" data-screen="${s.id}">
        <div class="pv-cell-scaler">${phoneHtml()}</div>
        <figcaption>${s.label}</figcaption>
      </figure>`).join("")}
  </div>`;

export function createPreview(root) {
  root.innerHTML = TEMPLATE;
  const $ = (sel) => root.querySelector(sel);
  const bigPhone = $(".pv-stage .phone");
  const bigHost = bigPhone.querySelector(".screen-host");
  const webLayer = $(".web-layer");
  const iframe = webLayer.querySelector("iframe");

  const state = {
    cfg: resolveConfig({}),
    screen: "paywall",
    mode: "focus",
    dark: false,
    focus: null, // { screen, part, hint, label }
    slideIndex: 0,
    socialIndex: 0,
    muted: true,
    userPaused: false,
  };
  let video = null;
  let frameRequested = false;
  let webTimer = 0;

  // ---- Rendering -----------------------------------------------------------
  const screenState = (live) => ({
    slideIndex: state.slideIndex,
    socialIndex: state.socialIndex,
    ghost: live && state.focus && GHOSTABLE.has(state.focus.part) ? state.focus.part : null,
    noUpiApp: state.focus?.part === "upi-select",
  });

  function paint(host, id, vars, live) {
    const screenEl = host.parentElement;
    const scrolls = [...host.querySelectorAll(".scroll")].map((s) => s.scrollTop);
    screenEl.style.cssText = vars;
    screenEl.classList.toggle("dark", state.dark);
    host.innerHTML = renderScreen(id, state.cfg, screenState(live));
    host.querySelectorAll(".scroll").forEach((s, i) => { s.scrollTop = scrolls[i] ?? 0; });
    markFocusedPart(host);
  }

  function render() {
    frameRequested = false;
    const scheme = colorScheme(state.cfg.seedColor, state.dark);
    const vars = cssVars(scheme, accentColors(scheme, state.cfg.accentColor));

    if (state.mode === "focus") {
      paint(bigHost, state.screen, vars, true);
      attachVideo();
      syncWebLayer();
      root.querySelectorAll(".pv-thumb").forEach((thumb) => {
        const active = thumb.dataset.screen === state.screen;
        thumb.classList.toggle("active", active);
        thumb.setAttribute("aria-selected", String(active));
        paint(thumb.querySelector(".screen-host"), thumb.dataset.screen, vars, false);
      });
    } else {
      // The big phone is hidden in this mode: nothing may keep playing there.
      stopVideo();
      unloadWebLayer();
      root.querySelectorAll(".pv-cell").forEach((cell) =>
        paint(cell.querySelector(".screen-host"), cell.dataset.screen, vars, false)
      );
    }
    renderChrome();
  }

  const schedule = () => {
    if (!frameRequested) {
      frameRequested = true;
      requestAnimationFrame(render);
    }
  };

  function renderChrome() {
    const sound = $('[data-act="sound"]');
    sound.hidden = !(state.mode === "focus" && state.screen === "paywall" && state.cfg.previewVideoUrl);
    sound.innerHTML = state.muted
      ? '<span class="ms">volume_off</span> Sound off'
      : '<span class="ms">volume_up</span> Sound on';
    $('[data-act="dark"]').innerHTML = state.dark
      ? '<span class="ms">light_mode</span> Light'
      : '<span class="ms">dark_mode</span> Dark';
    $('[data-act="mode"]').innerHTML = state.mode === "focus"
      ? '<span class="ms">grid_view</span> All screens'
      : '<span class="ms">smartphone</span> One screen';
    $(".pv-focus").hidden = state.mode !== "focus";
    $(".pv-grid").hidden = state.mode !== "all";
    root.classList.toggle("is-all", state.mode === "all");

    const hint = $(".pv-hint");
    const label = SCREENS.find((s) => s.id === state.screen)?.label ?? "";
    hint.innerHTML = state.focus
      ? `<b>${escapeText(state.focus.label)}</b>${state.focus.hint ? ` — ${escapeText(state.focus.hint)}` : ""}`
      : `Showing the <b>${label}</b> screen. Click a field to jump to where it appears.`;
    if (state.screen === "web" && state.cfg.webUrl && state.mode === "focus") {
      hint.innerHTML += `<br><span class="pv-note">Some sites refuse to appear inside another page; they still open in the app.
        <a href="${escapeAttr(state.cfg.webUrl)}" target="_blank" rel="noopener noreferrer">Open the site ↗</a></span>`;
    }
    if (state.screen === "paywall" && state.cfg.previewVideoUrl && state.muted && state.mode === "focus") {
      hint.innerHTML += `<br><span class="pv-note">The video is muted here; the app plays it with sound.</span>`;
    }
  }

  // ---- Highlight what the focused field controls ----------------------------
  function markFocusedPart(host) {
    const part = state.focus?.part;
    if (!part) return;
    host.querySelectorAll(`[data-part~="${part}"]`).forEach((el) => el.classList.add("hl"));
  }

  function pulseAndReveal() {
    const part = state.focus?.part;
    if (!part) return;
    const scope = state.mode === "focus" ? bigHost : root.querySelector(".pv-grid");
    const targets = scope.querySelectorAll(`[data-part~="${part}"]`);
    targets.forEach((el) => {
      el.classList.remove("pulse");
      void el.offsetWidth; // restart the animation
      el.classList.add("pulse");
    });
    if (state.mode === "focus" && targets[0]) revealInPhone(targets[0]);
  }

  // Scrolls the phone's own scroll area, never the admin page.
  function revealInPhone(el) {
    const scroller = el.closest(".scroll");
    if (!scroller) return;
    const scale = bigPhone.getBoundingClientRect().width / FRAME_W;
    if (!scale) return; // preview closed on a small screen
    const top = (el.getBoundingClientRect().top - scroller.getBoundingClientRect().top) / scale;
    const target = scroller.scrollTop + top - 24;
    const visible = top >= 0 && top + el.offsetHeight <= scroller.clientHeight;
    if (!visible) scroller.scrollTo({ top: target, behavior: "smooth" });
  }

  // ---- Paywall video: one element kept across re-renders --------------------
  function createVideo(src) {
    const v = document.createElement("video");
    Object.assign(v, { src, loop: true, playsInline: true, autoplay: true, preload: "auto" });
    v.dataset.src = src;
    v.addEventListener("playing", () => { v.dataset.ready = "1"; v.parentElement?.classList.add("ready"); v.parentElement?.classList.remove("buffering"); });
    v.addEventListener("waiting", () => v.parentElement?.classList.add("buffering"));
    v.addEventListener("error", () => { v.dataset.failed = "1"; v.parentElement?.classList.add("failed"); });
    return v;
  }

  function dropVideo() {
    if (!video) return;
    video.pause();
    video.removeAttribute("src");
    video.load(); // stops the download too
    video = null;
  }

  function attachVideo() {
    const card = bigHost.querySelector(".media.vid");
    if (!card) {
      // Off the paywall the element is detached (so paused); with no video
      // set any more it is dropped altogether.
      if (!state.cfg.previewVideoUrl) dropVideo();
      return;
    }
    if (!video || video.dataset.src !== card.dataset.video) {
      dropVideo();
      video = createVideo(card.dataset.video);
      state.userPaused = false;
    }
    card.append(video);
    card.classList.toggle("ready", video.dataset.ready === "1");
    card.classList.toggle("failed", video.dataset.failed === "1");
    card.classList.toggle("is-paused", state.userPaused);
    video.muted = state.muted;
    if (!state.userPaused) video.play().catch(() => { /* autoplay refused; the poster stays */ });
    card.onclick = () => {
      state.userPaused = !video.paused;
      if (state.userPaused) video.pause(); else video.play().catch(() => {});
      card.classList.toggle("is-paused", state.userPaused);
    };
  }

  function stopVideo() {
    video?.pause();
  }

  // ---- Web page: a live frame laid over the screen ---------------------------
  function unloadWebLayer() {
    clearTimeout(webTimer);
    webLayer.hidden = true;
    if (iframe.dataset.src) {
      iframe.src = "about:blank";
      delete iframe.dataset.src;
    }
  }

  function syncWebLayer() {
    clearTimeout(webTimer);
    const show = state.screen === "web" && !!state.cfg.webUrl;
    webLayer.hidden = !show;
    if (!show) return;
    // Waits for typing to stop, so a half-typed link is not loaded.
    webTimer = setTimeout(() => {
      if (iframe.dataset.src !== state.cfg.webUrl) {
        iframe.dataset.src = state.cfg.webUrl;
        iframe.src = state.cfg.webUrl;
      }
    }, iframe.dataset.src ? WEB_DEBOUNCE_MS : 0);
  }

  // ---- Timed motion, updated in place so transitions run -------------------
  function fadeText(el, text) {
    if (!el || el.textContent === text) return;
    el.style.opacity = "0";
    setTimeout(() => { el.textContent = text; el.style.opacity = "1"; }, FADE_MS);
  }

  setInterval(() => {
    const slides = state.cfg.loginSlides;
    if (slides.length < 2) return;
    state.slideIndex = (state.slideIndex + 1) % slides.length;
    root.querySelectorAll(".car").forEach((car) => {
      car.querySelector(".car-track").style.transform = `translateX(-${state.slideIndex * 100}%)`;
      car.querySelectorAll(".dot").forEach((d, i) => d.classList.toggle("on", i === state.slideIndex));
      fadeText(car.querySelector(".car-title"), slides[state.slideIndex].title);
    });
  }, SLIDE_MS);

  setInterval(() => {
    const lines = state.cfg.socialProofs;
    if (lines.length < 2) return;
    state.socialIndex = (state.socialIndex + 1) % lines.length;
    root.querySelectorAll(".social-text").forEach((el) => fadeText(el, lines[state.socialIndex]));
  }, SOCIAL_MS);

  // ---- Scaling --------------------------------------------------------------
  const stage = $(".pv-stage");
  new ResizeObserver(() => {
    const s = Math.min(1, stage.clientWidth / FRAME_W, stage.clientHeight / FRAME_H);
    stage.style.setProperty("--s", String(Math.max(0.3, s)));
  }).observe(stage);

  const grid = $(".pv-grid");
  // Picks the column count that shows all six phones at once, as large as fits.
  new ResizeObserver(() => {
    let best = { cols: 3, s: 0 };
    for (let cols = 1; cols <= SCREENS.length; cols++) {
      const rows = Math.ceil(SCREENS.length / cols);
      const byWidth = (grid.clientWidth - (cols - 1) * GRID_GAP) / cols / FRAME_W;
      const byHeight = (grid.clientHeight - (rows - 1) * GRID_GAP - rows * CAPTION_H) / rows / FRAME_H;
      const s = Math.min(1, byWidth, byHeight);
      if (s > best.s) best = { cols, s };
    }
    grid.style.setProperty("--cols", String(best.cols));
    grid.style.setProperty("--s", String(Math.max(0.2, best.s)));
  }).observe(grid);

  // ---- Controls ---------------------------------------------------------------
  root.addEventListener("click", (event) => {
    const thumb = event.target.closest(".pv-thumb, .pv-cell");
    if (thumb) {
      state.screen = thumb.dataset.screen;
      state.mode = "focus";
      schedule();
      return;
    }
    const act = event.target.closest("[data-act]")?.dataset.act;
    if (act === "dark") state.dark = !state.dark;
    if (act === "mode") state.mode = state.mode === "focus" ? "all" : "focus";
    if (act === "sound") {
      state.muted = !state.muted;
      if (video) video.muted = state.muted;
    }
    if (act) schedule();
  });

  // Images that fail to load, as the app's errorBuilders handle them. Done
  // here, not with inline onerror, because the page's CSP forbids inline JS.
  root.addEventListener("error", (event) => {
    const img = event.target;
    if (img.tagName !== "IMG") return;
    if (img.dataset.err === "remove") img.remove();
    if (img.dataset.err === "broken") img.parentElement?.classList.add("broken");
    if (img.dataset.err === "bad") img.classList.add("bad");
  }, true); // error does not bubble; capture it

  render();

  return {
    /** Leaving the editor: silence the video and unload the web page. */
    stop() {
      state.focus = null;
      dropVideo();
      unloadWebLayer();
    },
    /** New settings rows (global merged with this source's overrides). */
    update(rows) {
      const cfg = resolveConfig(rows);
      if (cfg.loginSlides.length !== state.cfg.loginSlides.length) state.slideIndex = 0;
      if (cfg.socialProofs.length !== state.cfg.socialProofs.length) state.socialIndex = 0;
      state.cfg = cfg;
      schedule();
    },
    /** A field gained focus: show its screen and point at its part. */
    focusField(meta) {
      const changed = state.focus?.part !== meta?.part || state.focus?.label !== meta?.label;
      state.focus = meta;
      if (meta?.screen) state.screen = meta.screen;
      render();
      if (changed) pulseAndReveal();
    },
    blurField() {
      state.focus = null;
      schedule();
    },
  };
}

function escapeText(s) {
  return String(s).replace(/[&<>]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;" }[c]));
}
function escapeAttr(s) {
  return escapeText(s).replace(/"/g, "&quot;");
}
