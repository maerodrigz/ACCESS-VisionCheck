(() => {
  const state = {
    sessionToken: localStorage.getItem("phase6b_session") || "",
    evaluatorId: localStorage.getItem("phase6b_evaluator") || "",
    meta: null,
    progress: null,
    index: Number(localStorage.getItem("phase6b_index") || "0"),
    current: null,
    zoom: 1,
    panX: 0,
    panY: 0,
    saving: false,
    locked: false,
  };

  const $ = (id) => document.getElementById(id);
  const gate = $("gate");
  const appEl = $("app");
  const summary = $("summary");
  const dock = $("dock");
  const photo = $("photo");
  const viewer = $("viewer");

  // Local FastAPI: "". Cloudflare Pages: set window.PHASE6B_API_BASE or meta api-base.
  const API_BASE = String(
    window.PHASE6B_API_BASE ||
      document.querySelector('meta[name="api-base"]')?.content ||
      ""
  ).replace(/\/$/, "");

  function headers(json = true) {
    const h = {};
    if (json) h["Content-Type"] = "application/json";
    if (state.sessionToken) h["X-Session-Token"] = state.sessionToken;
    return h;
  }

  async function api(path, opts = {}) {
    const res = await fetch(`${API_BASE}${path}`, {
      ...opts,
      headers: { ...headers(!(opts.body instanceof FormData)), ...(opts.headers || {}) },
    });
    const text = await res.text();
    let data = null;
    try { data = text ? JSON.parse(text) : null; } catch { data = { raw: text }; }
    if (!res.ok) {
      const detail = (data && data.detail) || res.statusText;
      throw new Error(typeof detail === "string" ? detail : JSON.stringify(detail));
    }
    return data;
  }

  function setSaveStatus(msg, cls = "") {
    const el = $("saveStatus");
    el.textContent = msg;
    el.className = "save-status " + cls;
  }

  function applyZoom() {
    photo.style.transform = `translate(${state.panX}px, ${state.panY}px) scale(${state.zoom})`;
  }

  async function loadImageBlob(mediaId) {
    const res = await fetch(`${API_BASE}/api/images/${mediaId}.jpg`, {
      headers: headers(false),
    });
    if (!res.ok) throw new Error("image_load_failed");
    const ct = (res.headers.get("content-type") || "").toLowerCase();
    if (ct.includes("application/json")) {
      const data = await res.json();
      if (!data.url) throw new Error("image_url_missing");
      if (photo.dataset.objectUrl) {
        URL.revokeObjectURL(photo.dataset.objectUrl);
        delete photo.dataset.objectUrl;
      }
      photo.src = data.url; // short-lived signed URL
      return;
    }
    const blob = await res.blob();
    const url = URL.createObjectURL(blob);
    if (photo.dataset.objectUrl) URL.revokeObjectURL(photo.dataset.objectUrl);
    photo.dataset.objectUrl = url;
    photo.src = url;
  }

  function renderCriteria() {
    const box = $("criteriaCard");
    box.innerHTML = "";
    const ratings = (state.current && state.current.ratings) || {};
    const naMeta = state.meta.na_label || {
      code: "N/A",
      bisaya: "Dili applicable",
      en: "Cannot judge. Do not guess. Never use 3 as unknown.",
    };
    for (const c of state.meta.criteria) {
      const wrap = document.createElement("div");
      wrap.className = "criterion";
      const selected = ratings[c.id];
      const selectedLab =
        selected === "N/A"
          ? naMeta.bisaya
          : selected
            ? (state.meta.scale_labels[selected] || {}).bisaya || ""
            : "";
      wrap.innerHTML = `
        <h3><span class="bisaya">${c.bisaya_name}</span> <span class="en-name">${c.en_name}</span></h3>
        <p class="crit-prompt">${c.bisaya_prompt}</p>
        <p class="crit-en"><em>${c.en_prompt}</em></p>
        <div class="crit-range">
          <span class="crit-low">${c.bisaya_low || ""}</span>
          <span class="crit-high">${c.bisaya_high || ""}</span>
        </div>
        <div class="scale" data-criterion="${c.id}"></div>
        <p class="selected-label" data-selected-for="${c.id}"></p>
      `;
      const scale = wrap.querySelector(".scale");
      const selectedEl = wrap.querySelector(".selected-label");
      selectedEl.textContent = selected
        ? `Gipili: ${selected} · ${selectedLab}`
        : "Wala pa napilian";
      for (let i = 1; i <= 5; i++) {
        const btn = document.createElement("button");
        btn.type = "button";
        btn.className = "score-btn" + (ratings[c.id] === i ? " active" : "");
        const lab = state.meta.scale_labels[i];
        btn.innerHTML = `<span class="score-num">${i}</span><span class="score-lab">${lab.bisaya}</span>`;
        btn.title = `${i}: ${lab.bisaya} / ${lab.en}. ${lab.en_anchor}`;
        btn.setAttribute(
          "aria-label",
          `${i} ${lab.bisaya}. ${lab.bisaya_anchor}. English: ${lab.en}. ${lab.en_anchor}`
        );
        btn.disabled = state.locked;
        btn.addEventListener("click", () => setRating(c.id, i));
        scale.appendChild(btn);
      }
      const na = document.createElement("button");
      na.type = "button";
      na.className = "score-btn na" + (ratings[c.id] === "N/A" ? " active" : "");
      na.innerHTML = `<span class="score-num">N/A</span><span class="score-lab">${naMeta.bisaya}</span>`;
      na.title = naMeta.en;
      na.setAttribute("aria-label", `N/A ${naMeta.bisaya}. ${naMeta.en}`);
      na.disabled = state.locked;
      na.addEventListener("click", () => setRating(c.id, "N/A"));
      scale.appendChild(na);
      box.appendChild(wrap);
    }
  }

  async function setRating(criterion, value) {
    if (state.locked) return;
    state.current.ratings = state.current.ratings || {};
    state.current.ratings[criterion] = value;
    renderCriteria();
    await autosave(false);
  }

  async function autosave(markComplete) {
    if (!state.current || state.locked) return;
    state.saving = true;
    setSaveStatus("Saving…");
    try {
      const body = {
        media_id: state.current.media_id,
        ratings: state.current.ratings || {},
        notes: $("notes").value || "",
        mark_complete: !!markComplete,
      };
      const data = await api(`/api/ratings/${state.current.media_id}`, {
        method: "PUT",
        body: JSON.stringify(body),
      });
      state.current = data.saved;
      state.progress = data.progress;
      renderThumbs();
      updateProgressChrome();
      setSaveStatus("Saved", "ok");
    } catch (err) {
      setSaveStatus(String(err.message || err), "err");
    } finally {
      state.saving = false;
    }
  }

  function updateProgressChrome() {
    const n = state.meta.image_ids.length;
    const idx = state.index + 1;
    $("progressPill").textContent = `Image ${idx} of ${n}`;
    $("imageTitle").textContent = state.meta.image_ids[state.index];
    const complete = state.progress ? state.progress.n_complete : 0;
    $("progressFill").style.width = `${(100 * complete) / n}%`;
    $("whoPill").textContent = state.evaluatorId;
  }

  function renderThumbs() {
    const grid = $("thumbGrid");
    grid.innerHTML = "";
    const items = (state.progress && state.progress.images) || [];
    items.forEach((item, i) => {
      const b = document.createElement("button");
      b.type = "button";
      b.className = "thumb";
      if (item.status === "complete" || item.status === "locked") b.classList.add("done");
      else if (item.status === "partial") b.classList.add("partial");
      if (i === state.index) b.classList.add("current");
      b.textContent = String(i + 1);
      b.addEventListener("click", () => openIndex(i));
      grid.appendChild(b);
    });
  }

  async function openIndex(i) {
    if (i < 0 || i >= state.meta.image_ids.length) return;
    await autosave(false);
    state.index = i;
    localStorage.setItem("phase6b_index", String(i));
    const mediaId = state.meta.image_ids[i];
    state.current = await api(`/api/ratings/${mediaId}`);
    $("notes").value = state.current.notes || "";
    state.zoom = 1;
    state.panX = 0;
    state.panY = 0;
    applyZoom();
    await loadImageBlob(mediaId);
    renderCriteria();
    updateProgressChrome();
    renderThumbs();
    window.scrollTo({ top: 0, behavior: "smooth" });
  }

  function showSummary() {
    appEl.classList.add("hidden");
    dock.classList.add("hidden");
    summary.classList.remove("hidden");
    const p = state.progress;
    $("summaryText").textContent =
      `${p.n_complete} of ${p.n_images} images fully rated` +
      (p.final_submitted ? " (already submitted)." : ".");
    const ul = $("summaryList");
    ul.innerHTML = "";
    const missing = (p.images || []).filter((x) => x.filled_criteria < x.total_criteria);
    if (missing.length === 0) {
      ul.innerHTML = "<li>All images complete. You may submit.</li>";
      $("btnFinalSubmit").disabled = !!p.final_submitted || state.locked;
    } else {
      missing.slice(0, 20).forEach((m) => {
        const li = document.createElement("li");
        li.textContent = `${m.media_id}: ${m.filled_criteria}/${m.total_criteria} criteria`;
        ul.appendChild(li);
      });
      if (missing.length > 20) {
        const li = document.createElement("li");
        li.textContent = `…and ${missing.length - 20} more incomplete`;
        ul.appendChild(li);
      }
      $("btnFinalSubmit").disabled = true;
    }
  }

  async function startSession(inviteToken) {
    $("gateError").textContent = "";
    try {
      const data = await api("/api/auth/exchange", {
        method: "POST",
        body: JSON.stringify({ invite_token: inviteToken }),
      });
      state.sessionToken = data.session_token;
      state.evaluatorId = data.evaluator_id;
      state.locked = !!data.final_submitted;
      localStorage.setItem("phase6b_session", state.sessionToken);
      localStorage.setItem("phase6b_evaluator", state.evaluatorId);
      await bootApp();
    } catch (err) {
      $("gateError").textContent = String(err.message || err);
    }
  }

  async function bootApp() {
    state.meta = await api("/api/meta");
    const me = await api("/api/me");
    state.progress = me.progress;
    state.locked = !!me.progress.final_submitted;
    gate.classList.add("hidden");
    appEl.classList.remove("hidden");
    dock.classList.remove("hidden");
    // Resume at first incomplete, else saved index
    let start = state.index;
    const firstIncomplete = (state.progress.images || []).findIndex(
      (x) => x.filled_criteria < x.total_criteria
    );
    if (firstIncomplete >= 0 && !(state.progress.images[state.index]?.filled_criteria === state.meta.criteria.length)) {
      start = firstIncomplete;
    }
    await openIndex(Math.min(Math.max(start, 0), state.meta.image_ids.length - 1));
  }

  // Zoom / pan
  $("zoomIn").onclick = () => { state.zoom = Math.min(4, state.zoom + 0.25); applyZoom(); };
  $("zoomOut").onclick = () => { state.zoom = Math.max(1, state.zoom - 0.25); applyZoom(); };
  $("zoomReset").onclick = () => { state.zoom = 1; state.panX = 0; state.panY = 0; applyZoom(); };
  $("zoom200").onclick = () => { state.zoom = 2; applyZoom(); };

  let dragging = false;
  let lastX = 0;
  let lastY = 0;
  viewer.addEventListener("pointerdown", (e) => {
    if (state.zoom <= 1) return;
    dragging = true;
    lastX = e.clientX;
    lastY = e.clientY;
    viewer.setPointerCapture(e.pointerId);
  });
  viewer.addEventListener("pointermove", (e) => {
    if (!dragging) return;
    state.panX += e.clientX - lastX;
    state.panY += e.clientY - lastY;
    lastX = e.clientX;
    lastY = e.clientY;
    applyZoom();
  });
  viewer.addEventListener("pointerup", () => { dragging = false; });
  viewer.addEventListener("pointercancel", () => { dragging = false; });

  $("btnPrev").onclick = async () => {
    if (state.index > 0) await openIndex(state.index - 1);
  };
  $("btnNext").onclick = async () => {
    await autosave(true);
    if (state.index < state.meta.image_ids.length - 1) await openIndex(state.index + 1);
    else showSummary();
  };
  $("btnReview").onclick = async () => {
    await autosave(false);
    const me = await api("/api/me");
    state.progress = me.progress;
    showSummary();
  };
  $("btnBackEdit").onclick = () => {
    summary.classList.add("hidden");
    appEl.classList.remove("hidden");
    dock.classList.remove("hidden");
  };
  $("btnFinalSubmit").onclick = async () => {
    $("summaryError").textContent = "";
    try {
      await api("/api/submit", { method: "POST", body: "{}" });
      state.locked = true;
      $("summaryText").textContent = "Submitted. Salamat! Your ratings are locked.";
      $("btnFinalSubmit").disabled = true;
    } catch (err) {
      $("summaryError").textContent = String(err.message || err);
    }
  };
  $("notes").addEventListener("change", () => autosave(false));

  $("btnStart").onclick = () => {
    const tok = $("inviteInput").value.trim();
    if (!tok) {
      $("gateError").textContent = "Paste your invite token or open your personal link.";
      return;
    }
    startSession(tok);
  };

  async function init() {
    const params = new URLSearchParams(location.search);
    const qInvite = params.get("invite");
    if (qInvite) {
      history.replaceState({}, "", location.pathname);
      await startSession(qInvite.trim());
      return;
    }
    const metaInvite = document.querySelector('meta[name="invite-token"]');
    if (metaInvite && metaInvite.content) {
      await startSession(metaInvite.content.trim());
      return;
    }
    if (state.sessionToken) {
      try {
        await bootApp();
        return;
      } catch {
        localStorage.removeItem("phase6b_session");
        state.sessionToken = "";
      }
    }
    gate.classList.remove("hidden");
  }

  init();
})();
