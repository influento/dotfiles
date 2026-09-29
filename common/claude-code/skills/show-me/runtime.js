// show-me page runtime: renders blocks, themes, versions and live reload, feedback.
// Inlined into every page by `page`; THEMES, PREFS, applyTheme and schemeNow come from the boot script.
(() => {
const $ = (id) => document.getElementById(id);
const el = (tag, cls, text) => { const e = document.createElement(tag); if (cls) e.className = cls; if (text != null) e.textContent = text; return e; };
const raw = (blk) => { const s = blk.querySelector("script[type='text/plain']"); return s ? s.textContent.replace(/<\\\/script/gi, "</script") : ""; };
const css = (name) => getComputedStyle(document.documentElement).getPropertyValue(`--${name}`).trim();
const savePrefs = () => { try { localStorage.setItem("show-me:prefs", JSON.stringify(PREFS)); } catch {} };

// ---- ANSI SGR → HTML (text escaped first) -----------------------------------------------------
function ansi(text) {
  const pal = ["#484f58","#ff7b72","#3fb950","#d29922","#58a6ff","#bc8cff","#39c5cf","#b1bac4",
               "#6e7681","#ffa198","#56d364","#e3b341","#79c0ff","#d2a8ff","#56d4dd","#f0f6fc"];
  const esc = (s) => s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
  let st = {}, out = "";
  const open = () => {
    const cls = [st.b && "b", st.d && "d", st.u && "u"].filter(Boolean).join(" ");
    const sty = [st.fg && `color:${st.fg}`, st.bg && `background:${st.bg}`].filter(Boolean).join(";");
    return cls || sty ? `<span class="${cls}" style="${sty}">` : "<span>";
  };
  const parts = text.split(/\x1b\[([0-9;]*)m/);
  for (let i = 0; i < parts.length; i++) {
    if (i % 2 === 0) { if (parts[i]) out += open() + esc(parts[i]) + "</span>"; continue; }
    const codes = parts[i] === "" ? [0] : parts[i].split(";").map(Number);
    for (let j = 0; j < codes.length; j++) {
      const c = codes[j];
      if (c === 0) st = {};
      else if (c === 1) st.b = 1; else if (c === 2) st.d = 1; else if (c === 4) st.u = 1;
      else if (c === 22) st.b = st.d = 0; else if (c === 24) st.u = 0;
      else if (c >= 30 && c <= 37) st.fg = pal[c - 30]; else if (c >= 90 && c <= 97) st.fg = pal[c - 82];
      else if (c >= 40 && c <= 47) st.bg = pal[c - 40]; else if (c >= 100 && c <= 107) st.bg = pal[c - 92];
      else if (c === 39) st.fg = 0; else if (c === 49) st.bg = 0;
      else if ((c === 38 || c === 48) && codes[j + 1] === 5) { const n = codes[j + 2]; if (n < 16) st[c === 38 ? "fg" : "bg"] = pal[n]; j += 2; }
      else if ((c === 38 || c === 48) && codes[j + 1] === 2) { st[c === 38 ? "fg" : "bg"] = `rgb(${codes[j+2]},${codes[j+3]},${codes[j+4]})`; j += 4; }
    }
  }
  return out;
}

// ---- blocks ----------------------------------------------------------------------------------
// The current palette as CSS declarations, so a frame starts in the right colours before its load event.
function themeVars() {
  const scheme = schemeNow(), t = THEMES[PREFS.theme] || THEMES.github;
  return Object.entries(t[scheme]).map(([k, v]) => `--${k}:${v};`).join("") + `color-scheme:${scheme};`;
}
function mermaidBox(src) { const pre = el("pre", "mermaid"); pre.dataset.src = src; return pre; }

for (const blk of document.querySelectorAll(".blk[data-kind]")) {
  const text = raw(blk), kind = blk.dataset.kind, label = blk.dataset.label;
  if (kind === "md") {
    const md = window.markdownit({ html: true, linkify: true });
    const fence = md.renderer.rules.fence;
    md.renderer.rules.fence = (t, i, o, e, s) => t[i].info.trim() === "mermaid"
      ? `<div class="mermaid-wrap"><pre class="mermaid" data-src="${md.utils.escapeHtml(t[i].content)}"></pre></div>` : fence(t, i, o, e, s);
    const div = el("div", "md"); div.innerHTML = md.render(text); blk.replaceChildren(div);
    if (window.hljs) div.querySelectorAll("pre code[class*='language-']").forEach((c) => hljs.highlightElement(c));
  } else if (kind === "mermaid") {
    blk.replaceChildren(mermaidBox(text));
  } else if (kind === "code") {
    const body = text.replace(/\n$/, ""), start = +blk.dataset.start || 1, n = body.split("\n").length;
    const code = el("code", blk.dataset.lang ? `language-${blk.dataset.lang}` : "", body);
    const gut = el("pre", "gut", Array.from({ length: n }, (_, i) => start + i).join("\n"));
    const src = el("pre", "src"); src.append(code);
    const box = el("div", "code"); box.append(gut, src);
    const kids = [];
    if (label) { const bar = el("div", "fbar"); bar.append(el("span", "", label)); kids.push(bar); }
    blk.replaceChildren(...kids, box);
    if (window.hljs && blk.dataset.lang) hljs.highlightElement(code);
  } else if (kind === "log") {
    const term = el("div", "term"), bar = el("div", "bar");
    bar.append(el("i"), el("i"), el("i"), el("span", "", label || "terminal"));
    const pre = el("pre"); pre.innerHTML = ansi(text.replace(/\n+$/, ""));
    term.append(bar, pre); blk.replaceChildren(term);
  } else if (kind === "html") {
    // Own document, so the fragment's CSS and ids can't touch the page (or other fragments).
    const f = el("iframe", "frag"); f.title = blk.closest(".card")?.dataset.h || "html";
    f.srcdoc = `<!doctype html><html><head><meta charset="utf-8"><base target="_blank"><style>${$("themeCss").textContent}</style>` +
      `<style>:root{${themeVars()}}html,body{background:transparent;margin:0}</style></head><body>${text}</body></html>`;
    f.addEventListener("load", () => {
      const d = f.contentDocument; if (!d) return;
      applyTheme(d.documentElement);
      const fit = () => { f.style.height = `${d.body.scrollHeight}px`; };
      fit(); new ResizeObserver(fit).observe(d.body);
    });
    blk.replaceChildren(f);
  } else if (kind === "diff") {
    blk.textContent = "";
    const cfg = { drawFileList: false, matching: "lines", outputFormat: blk.dataset.layout || "line-by-line",
      highlight: true, fileContentToggle: false, synchronisedScroll: true, colorScheme: "light" };
    if (window.Diff2HtmlUI) { const ui = new Diff2HtmlUI(blk, text, cfg, window.hljs); ui.draw(); ui.highlightCode(); }
    else if (window.Diff2Html) blk.innerHTML = Diff2Html.html(text, cfg);
  }
}

// ---- mermaid, coloured from the palette (re-rendered on theme change) --------------------------
let drawSeq = 0;
async function drawMermaid() {
  if (!window.mermaid) return;
  const seq = ++drawSeq;
  const [text, muted, border, panel, surface, bg, accent, accentBg] =
    ["fg", "fg2", "border2", "bg2", "bg", "bg3", "accent", "accent-bg"].map(css);
  mermaid.initialize({
    startOnLoad: false, securityLevel: "strict", theme: "base",
    themeVariables: {
      darkMode: document.documentElement.dataset.theme === "dark", fontFamily: css("font-sans"), fontSize: "14px",
      background: bg, primaryColor: panel, primaryBorderColor: border, primaryTextColor: text, secondaryColor: surface,
      tertiaryColor: bg, mainBkg: panel, nodeBorder: border, lineColor: muted, arrowheadColor: muted, textColor: text,
      nodeTextColor: text, titleColor: text, classText: text, secondaryTextColor: text, tertiaryTextColor: text,
      clusterBkg: surface, clusterBorder: border, edgeLabelBackground: bg, actorBkg: panel, actorBorder: border,
      actorTextColor: text, actorLineColor: muted, signalColor: muted, signalTextColor: text, labelBoxBkgColor: surface,
      labelBoxBorderColor: border, labelTextColor: text, loopTextColor: text, noteBkgColor: accentBg,
      noteBorderColor: border, noteTextColor: text, sequenceNumberColor: surface,
    },
    themeCSS: `
      .node rect, .node polygon, rect.actor, .labelBox { rx: 8px; ry: 8px; }
      .node rect, rect.actor { stroke-width: 1px; }
      .edgePath .path, .flowchart-link, .actor-line, .messageLine0, .messageLine1 { stroke-width: 1px; }
      .node.accent > rect, .node.accent > polygon, .node.accent > circle, .node.accent > path { fill: ${accentBg}; stroke: ${accent}; }
      .node.accent .nodeLabel, .node.accent span, .node.accent text { fill: ${accent}; color: ${accent}; }
      .flowchart-link.accentLine, .edgePath.accentLine > .path { stroke: ${accent}; }`,
  });
  let i = 0;
  for (const box of document.querySelectorAll("pre.mermaid[data-src]")) {
    try {
      const { svg } = await mermaid.render(`mmd-${seq}-${i++}`, box.dataset.src);
      if (seq !== drawSeq) return;
      box.innerHTML = svg;
    } catch (e) {
      box.textContent = `mermaid: ${e.message || e}\n\n${box.dataset.src}`;
    }
  }
}
drawMermaid();

// ---- theme controls ---------------------------------------------------------------------------
const sel = $("themeSel"), modeBtn = $("modeBtn");
for (const [id, t] of Object.entries(THEMES)) sel.append(new Option(t.label, id));
sel.value = THEMES[PREFS.theme] ? PREFS.theme : "github";
const MODES = { system: "◐ auto", light: "☀ light", dark: "☾ dark" };
const showMode = () => { modeBtn.textContent = MODES[PREFS.mode || "system"]; };
const retheme = () => {
  applyTheme(); showMode(); drawMermaid();
  for (const f of document.querySelectorAll("iframe.frag")) if (f.contentDocument) applyTheme(f.contentDocument.documentElement);
};
sel.onchange = () => { PREFS.theme = sel.value; savePrefs(); retheme(); };
modeBtn.onclick = () => {
  const order = ["system", "light", "dark"];
  PREFS.mode = order[(order.indexOf(PREFS.mode || "system") + 1) % 3]; savePrefs(); retheme();
};
matchMedia("(prefers-color-scheme: dark)").addEventListener("change", () => { if ((PREFS.mode || "system") === "system") retheme(); });
addEventListener("storage", (e) => { if (e.key === "show-me:prefs") { Object.assign(PREFS, JSON.parse(e.newValue || "{}")); sel.value = PREFS.theme || "github"; retheme(); } });
showMode();

// ---- versions + live reload (version.js sits next to the page; file:// allows script tags) -----
const toast = (msg) => { const t = $("toast"); t.textContent = msg; t.classList.add("show"); setTimeout(() => t.classList.remove("show"), 2200); };
let pollTimer = 0, polled = false;
window.__showMe = {
  version(info) {
    polled = true;
    $("live").classList.toggle("on", !!META.live);
    $("live").title = META.live ? "Live: reloads when the agent rebuilds this page" : "Older version (not live)";
    const nav = $("vers"); nav.replaceChildren();
    if (info.latest > 1) for (const v of info.versions) {
      const a = el(v.n === META.version ? "span" : "a", v.n === META.version ? "cur" : "", `v${v.n}`);
      if (v.n !== META.version) a.href = v.n === info.latest ? "index.html" : `v${v.n}.html`;
      a.title = new Date(v.t).toLocaleString();
      nav.append(a);
    }
    if (!META.live && info.latest > META.version) {
      const s = $("stale"); s.hidden = false;
      s.innerHTML = `You're viewing v${META.version}. <a href="index.html">Latest is v${info.latest}</a>.`;
    }
    if (META.live && info.latest > META.version) {
      try { sessionStorage.setItem("show-me:reload", JSON.stringify({ y: scrollY, v: info.latest })); } catch {}
      location.reload();
    }
  },
};
function poll() {
  const s = document.createElement("script");
  s.src = `version.js?t=${Date.now()}`;
  s.onload = () => { s.remove(); if (META.live) pollTimer = setTimeout(poll, 1500); };
  s.onerror = () => { s.remove(); if (!polled) { $("live").hidden = true; } else if (META.live) pollTimer = setTimeout(poll, 3000); };
  document.head.append(s);
}
poll();
try {
  const r = JSON.parse(sessionStorage.getItem("show-me:reload") || "null");
  if (r) { sessionStorage.removeItem("show-me:reload"); scrollTo(0, r.y); toast(`Updated to v${r.v}`); }
} catch {}

// ---- notes: one per card, copied together from the top bar ------------------------------------
const noteKey = `show-me:notes:${META.project}/${META.slug}`;
let notes = {};
try { notes = JSON.parse(localStorage.getItem(noteKey) || "{}"); } catch {}
const copyBtn = $("copyNotes"), clearBtn = $("clearNotes");
const filled = () => Object.entries(notes).filter(([, v]) => v.trim());
function refreshCount() {
  const n = filled().length;
  copyBtn.textContent = n ? `Copy ${n} note${n > 1 ? "s" : ""}` : "Copy notes";
  copyBtn.disabled = !n; clearBtn.hidden = !n;
}
const saveNotes = () => { try { localStorage.setItem(noteKey, JSON.stringify(notes)); } catch {} refreshCount(); };
const grow = (ta) => { ta.style.height = "auto"; ta.style.height = `${ta.scrollHeight + 2}px`; };
const boxes = [];
document.querySelectorAll("main > .card").forEach((card, i) => {
  const label = card.dataset.h || `Section ${i + 1}`;
  const wrap = el("div", "note"), ta = el("textarea");
  ta.rows = 1; ta.placeholder = card.hasAttribute("data-note-only") ? "Anything else for the agent" : `Note on "${label}"`;
  ta.setAttribute("aria-label", `Note on ${label}`);
  ta.value = notes[label] || "";
  ta.addEventListener("input", () => { notes[label] = ta.value; if (!ta.value.trim()) delete notes[label]; grow(ta); saveNotes(); });
  wrap.append(ta); card.append(wrap); boxes.push(ta);
  requestAnimationFrame(() => grow(ta));
});
refreshCount();
copyBtn.onclick = async () => {
  const order = boxes.map((ta) => ta.getAttribute("aria-label").replace(/^Note on /, ""));
  const parts = order.filter((l) => (notes[l] || "").trim()).map((l) => `## ${l}\n${notes[l].trim()}`);
  const text = `[show-me: ${META.title} v${META.version} · ${META.path}]\n\n${parts.join("\n\n")}\n`;
  let ok = false;
  try { await navigator.clipboard.writeText(text); ok = true; } catch {
    const t = el("textarea"); t.value = text; document.body.append(t); t.select();
    try { ok = document.execCommand("copy"); } catch {} t.remove();
  }
  toast(ok ? `Copied ${parts.length} note${parts.length > 1 ? "s" : ""}. Paste into the agent's pane.` : "Copy was blocked by the browser.");
};
clearBtn.onclick = () => { notes = {}; boxes.forEach((ta) => { ta.value = ""; grow(ta); }); saveNotes(); toast("Notes cleared"); };
addEventListener("keydown", (e) => { if ((e.ctrlKey || e.metaKey) && e.key === "Enter" && !copyBtn.disabled) copyBtn.click(); });
})();
