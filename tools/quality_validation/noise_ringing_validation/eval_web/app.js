/* ACCESS VisionCheck — offline Noise/Ringing human evaluation (research only). */
(function () {
  "use strict";

  const IMAGE_IDS = Array.from({ length: 15 }, (_, i) => `NR${String(i + 1).padStart(3, "0")}`);
  const STORAGE_PREFIX = "access_nr_eval_v1_";
  const CSV_HEADER = [
    "media_id",
    "rater_id",
    "media_type",
    "noise",
    "ringing_artifacts",
    "sharpness",
    "blur",
    "brightness",
    "contrast",
    "blocking_artifacts",
    "flickering",
    "motion_stability",
    "overall_visual_quality",
    "notes",
  ];

  const SCORE_LABELS = {
    1: "Poor",
    2: "Needs improvement",
    3: "Fair",
    4: "Good",
    5: "Excellent",
  };

  const NOISE_DEFS = {
    5: "Clean tones. No distracting grain or color splotches at 100%.",
    4: "Mild luminance grain mainly in deep shadows; chroma mostly clean.",
    3: "Grain visible in midtones or mild chroma blotches; subject still clear.",
    2: "Heavy luminance and/or chroma noise; texture partly invented by grain.",
    1: "Noise dominates; subject hard to separate from speckle.",
  };

  const RINGING_DEFS = {
    5: "Clean edges; no light/dark halo at 100%.",
    4: "Faint halo only at 200% on a few edges.",
    3: "Visible fringe around high-contrast edges at 100%.",
    2: "Strong double edges or glowing outlines on many edges.",
    1: "Halos dominate; subject looks cut-out or cartoon-outlined.",
  };

  const state = {
    raterId: null,
    index: 0,
    ratings: {},
    zoomMode: "fit", // fit | x1 | x2
    panX: 0,
    panY: 0,
    dragging: false,
    dragStartX: 0,
    dragStartY: 0,
    panStartX: 0,
    panStartY: 0,
    naturalW: 0,
    naturalH: 0,
  };

  const $ = (id) => document.getElementById(id);

  function storageKey(raterId) {
    return STORAGE_PREFIX + raterId;
  }

  function emptyRatings() {
    const out = {};
    IMAGE_IDS.forEach((id) => {
      out[id] = { noise: null, ringing_artifacts: null, notes: "" };
    });
    return out;
  }

  function loadSession(raterId) {
    try {
      const raw = localStorage.getItem(storageKey(raterId));
      if (!raw) return null;
      const parsed = JSON.parse(raw);
      if (!parsed || typeof parsed !== "object") return null;
      const ratings = emptyRatings();
      IMAGE_IDS.forEach((id) => {
        const row = (parsed.ratings && parsed.ratings[id]) || {};
        const noise = normalizeScore(row.noise);
        const ringing = normalizeScore(row.ringing_artifacts);
        ratings[id] = {
          noise,
          ringing_artifacts: ringing,
          notes: typeof row.notes === "string" ? row.notes : "",
        };
      });
      const index = Math.min(
        Math.max(parseInt(parsed.index, 10) || 0, 0),
        IMAGE_IDS.length - 1
      );
      return { ratings, index };
    } catch (_) {
      return null;
    }
  }

  function normalizeScore(v) {
    const n = Number(v);
    if (Number.isInteger(n) && n >= 1 && n <= 5) return n;
    return null;
  }

  function saveSession() {
    if (!state.raterId) return;
    const payload = {
      raterId: state.raterId,
      index: state.index,
      updatedAt: new Date().toISOString(),
      ratings: state.ratings,
    };
    localStorage.setItem(storageKey(state.raterId), JSON.stringify(payload));
  }

  function completedCount() {
    return IMAGE_IDS.filter((id) => isComplete(state.ratings[id])).length;
  }

  function isComplete(row) {
    return !!(row && normalizeScore(row.noise) && normalizeScore(row.ringing_artifacts));
  }

  function isPartial(row) {
    if (!row) return false;
    const hasScore = normalizeScore(row.noise) || normalizeScore(row.ringing_artifacts);
    const hasNotes = !!(row.notes && row.notes.trim());
    return !isComplete(row) && (!!hasScore || hasNotes);
  }

  function toast(msg) {
    const el = $("toast");
    el.textContent = msg;
    el.classList.add("show");
    clearTimeout(toast._t);
    toast._t = setTimeout(() => el.classList.remove("show"), 2200);
  }

  function showScreen(name) {
    $("screen-start").classList.toggle("hidden", name !== "start");
    $("screen-eval").classList.toggle("hidden", name !== "eval");
    $("screen-complete").classList.toggle("hidden", name !== "complete");
  }

  function imagePath(id) {
    return `../images/${id}.jpg`;
  }

  function renderStart() {
    showScreen("start");
    const resume = $("resume-info");
    const selected = document.querySelector('input[name="rater"]:checked');
    const raterId = selected ? selected.value : null;
    document.querySelectorAll(".rater-option").forEach((lab) => {
      const input = lab.querySelector("input");
      lab.classList.toggle("selected", !!(input && input.checked));
    });
    if (!raterId) {
      resume.textContent = "Select an evaluator to see saved progress.";
      $("btn-start").disabled = true;
      $("btn-resume").disabled = true;
      return;
    }
    $("btn-start").disabled = false;
    const existing = loadSession(raterId);
    const done = existing
      ? IMAGE_IDS.filter((id) => isComplete(existing.ratings[id])).length
      : 0;
    if (existing && done > 0) {
      resume.innerHTML = `<strong>${raterId}</strong> has saved progress: <strong>${done}/15</strong> complete. Prefer Resume. Starting over will ask for confirmation.`;
      $("btn-resume").disabled = false;
    } else if (existing) {
      resume.innerHTML = `<strong>${raterId}</strong> has a saved session with no completed images yet.`;
      $("btn-resume").disabled = false;
    } else {
      resume.textContent = `No saved session for ${raterId}. You can start fresh.`;
      $("btn-resume").disabled = true;
    }
  }

  function beginSession(raterId, { resume }) {
    const existing = loadSession(raterId);
    if (!resume && existing && completedCountFrom(existing.ratings) > 0) {
      const ok = window.confirm(
        `Replace saved progress for ${raterId}? This cannot be undone unless you exported a CSV.`
      );
      if (!ok) return;
      localStorage.removeItem(storageKey(raterId));
    }
    state.raterId = raterId;
    if (resume && existing) {
      state.ratings = existing.ratings;
      state.index = existing.index;
    } else if (!resume) {
      state.ratings = emptyRatings();
      state.index = 0;
    } else {
      state.ratings = emptyRatings();
      state.index = 0;
    }
    state.zoomMode = "fit";
    state.panX = 0;
    state.panY = 0;
    saveSession();
    showScreen("eval");
    $("active-rater").textContent = raterId;
    buildThumbStrip();
    renderEval();
  }

  function completedCountFrom(ratings) {
    return IMAGE_IDS.filter((id) => isComplete(ratings[id])).length;
  }

  function buildThumbStrip() {
    const strip = $("thumb-strip");
    strip.innerHTML = "";
    IMAGE_IDS.forEach((id, i) => {
      const btn = document.createElement("button");
      btn.type = "button";
      btn.className = "thumb-dot";
      btn.title = id;
      btn.setAttribute("aria-label", `Go to ${id}`);
      btn.addEventListener("click", () => {
        state.index = i;
        state.zoomMode = "fit";
        state.panX = 0;
        state.panY = 0;
        saveSession();
        renderEval();
      });
      strip.appendChild(btn);
    });
  }

  function updateThumbStrip() {
    const dots = $("thumb-strip").querySelectorAll(".thumb-dot");
    dots.forEach((dot, i) => {
      const id = IMAGE_IDS[i];
      const row = state.ratings[id];
      dot.classList.toggle("current", i === state.index);
      dot.classList.toggle("done", isComplete(row));
      dot.classList.toggle("partial", isPartial(row));
    });
  }

  function renderScoreButtons(containerId, criterion, defs) {
    const host = $(containerId);
    host.innerHTML = "";
    for (let score = 1; score <= 5; score += 1) {
      const btn = document.createElement("button");
      btn.type = "button";
      btn.className = "score-btn";
      btn.dataset.score = String(score);
      btn.setAttribute("aria-pressed", "false");
      btn.innerHTML = `<span class="n">${score}</span><span class="l">${SCORE_LABELS[score]}</span>`;
      btn.title = defs[score];
      btn.addEventListener("click", () => setScore(criterion, score));
      host.appendChild(btn);
    }
  }

  function setScore(criterion, score) {
    const id = IMAGE_IDS[state.index];
    state.ratings[id][criterion] = score;
    saveSession();
    syncScoreUI();
    updateProgress();
    updateThumbStrip();
    maybeOfferComplete();
  }

  function syncScoreUI() {
    const id = IMAGE_IDS[state.index];
    const row = state.ratings[id];
    syncGroup("noise-scores", row.noise);
    syncGroup("ringing-scores", row.ringing_artifacts);
    $("notes").value = row.notes || "";
    const status = $("item-status");
    if (isComplete(row)) {
      status.className = "status-line ok";
      status.textContent = "Both ratings saved for this image.";
    } else if (isPartial(row)) {
      status.className = "status-line warn";
      status.textContent = "Partial: set both Noise and Ringing (1–5) to complete this image.";
    } else {
      status.className = "status-line";
      status.textContent = "Select Noise and Ringing ratings (1–5). Progress autosaves.";
    }
  }

  function syncGroup(groupId, selected) {
    $(groupId).querySelectorAll(".score-btn").forEach((btn) => {
      const score = Number(btn.dataset.score);
      btn.setAttribute("aria-pressed", selected === score ? "true" : "false");
    });
  }

  function updateProgress() {
    const done = completedCount();
    $("progress-label").textContent = `${done} of 15 complete`;
    $("progress-fill").style.width = `${(done / 15) * 100}%`;
    $("image-pos").textContent = `Image ${state.index + 1} of 15`;
    $("btn-export-inline").disabled = done < 15;
    if (done === 15) {
      $("btn-finish").disabled = false;
    } else {
      $("btn-finish").disabled = true;
    }
  }

  function maybeOfferComplete() {
    if (completedCount() === 15) {
      toast("All 15 images rated. You can export CSV.");
    }
  }

  function renderEval() {
    const id = IMAGE_IDS[state.index];
    $("image-id").textContent = id;
    $("btn-prev").disabled = state.index <= 0;
    $("btn-next").disabled = state.index >= IMAGE_IDS.length - 1;
    updateProgress();
    updateThumbStrip();
    syncScoreUI();
    loadImage(id);
  }

  function loadImage(id) {
    const img = $("photo");
    const err = $("load-error");
    err.classList.add("hidden");
    img.style.opacity = "0.35";
    img.onload = () => {
      state.naturalW = img.naturalWidth;
      state.naturalH = img.naturalHeight;
      img.style.opacity = "1";
      applyTransform();
    };
    img.onerror = () => {
      err.classList.remove("hidden");
      err.textContent = `Could not load ${imagePath(id)}. Start the local server from eval_web/ and confirm images exist.`;
      img.style.opacity = "0";
    };
    img.src = imagePath(id) + `?t=${Date.now()}`;
  }

  function applyTransform() {
    const img = $("photo");
    const vp = $("viewport");
    if (!state.naturalW || !state.naturalH) return;
    const vw = vp.clientWidth;
    const vh = vp.clientHeight;
    let scale;
    if (state.zoomMode === "fit") {
      scale = Math.min(vw / state.naturalW, vh / state.naturalH);
      state.panX = 0;
      state.panY = 0;
    } else if (state.zoomMode === "x1") {
      scale = 1;
    } else {
      scale = 2;
    }
    img.style.width = `${state.naturalW * scale}px`;
    img.style.height = `${state.naturalH * scale}px`;
    img.style.transform = `translate(calc(-50% + ${state.panX}px), calc(-50% + ${state.panY}px))`;
    $("zoom-label").textContent =
      state.zoomMode === "fit" ? "Fit" : state.zoomMode === "x1" ? "100%" : "200%";
    document.querySelectorAll("[data-zoom]").forEach((btn) => {
      btn.setAttribute("aria-pressed", btn.dataset.zoom === state.zoomMode ? "true" : "false");
    });
  }

  function setZoom(mode) {
    state.zoomMode = mode;
    if (mode === "fit") {
      state.panX = 0;
      state.panY = 0;
    }
    applyTransform();
  }

  function go(delta) {
    const next = state.index + delta;
    if (next < 0 || next >= IMAGE_IDS.length) return;
    const row = state.ratings[IMAGE_IDS[state.index]];
    if (!isComplete(row) && (normalizeScore(row.noise) || normalizeScore(row.ringing_artifacts))) {
      // allow navigation with partial, but warn
      toast("Current image is incomplete (both scores required).");
    }
    state.index = next;
    state.zoomMode = "fit";
    state.panX = 0;
    state.panY = 0;
    saveSession();
    renderEval();
  }

  function csvEscape(value) {
    const s = String(value ?? "");
    if (/[",\n\r]/.test(s)) return `"${s.replace(/"/g, '""')}"`;
    return s;
  }

  function buildCsv(raterId) {
    const lines = [CSV_HEADER.join(",")];
    IMAGE_IDS.forEach((id) => {
      const row = state.ratings[id];
      if (!isComplete(row)) {
        throw new Error(`Incomplete ratings for ${id}. Export requires all 15 images.`);
      }
      const values = [
        id,
        raterId,
        "photo",
        String(row.noise),
        String(row.ringing_artifacts),
        "N/A",
        "N/A",
        "N/A",
        "N/A",
        "N/A",
        "N/A",
        "N/A",
        "N/A",
        row.notes || "",
      ];
      lines.push(values.map(csvEscape).join(","));
    });
    return lines.join("\r\n") + "\r\n";
  }

  function exportCsv() {
    try {
      if (completedCount() < 15) {
        toast("Export locked until all 15 images have Noise and Ringing scores.");
        return;
      }
      const csv = buildCsv(state.raterId);
      const blob = new Blob([csv], { type: "text/csv;charset=utf-8" });
      const a = document.createElement("a");
      const filename = `${state.raterId}_noise_ringing_ratings.csv`;
      a.href = URL.createObjectURL(blob);
      a.download = filename;
      document.body.appendChild(a);
      a.click();
      a.remove();
      URL.revokeObjectURL(a.href);
      toast(`Downloaded ${filename}`);
    } catch (err) {
      toast(err.message || "Export failed");
    }
  }

  function showComplete() {
    if (completedCount() < 15) {
      toast("Finish all 15 images before opening the completion screen.");
      return;
    }
    showScreen("complete");
    $("complete-summary").textContent = `${state.raterId}: 15/15 images rated and saved in this browser.`;
  }

  function resetProgress() {
    if (!state.raterId) return;
    const ok = window.confirm(
      `Clear all saved ratings for ${state.raterId} on this browser? Export first if needed.`
    );
    if (!ok) return;
    localStorage.removeItem(storageKey(state.raterId));
    state.ratings = emptyRatings();
    state.index = 0;
    saveSession();
    toast("Progress cleared.");
    showScreen("start");
    renderStart();
  }

  function bindViewerPan() {
    const vp = $("viewport");
    const img = $("photo");
    vp.addEventListener("pointerdown", (e) => {
      if (state.zoomMode === "fit") return;
      state.dragging = true;
      img.classList.add("dragging");
      state.dragStartX = e.clientX;
      state.dragStartY = e.clientY;
      state.panStartX = state.panX;
      state.panStartY = state.panY;
      vp.setPointerCapture(e.pointerId);
    });
    vp.addEventListener("pointermove", (e) => {
      if (!state.dragging) return;
      state.panX = state.panStartX + (e.clientX - state.dragStartX);
      state.panY = state.panStartY + (e.clientY - state.dragStartY);
      applyTransform();
    });
    const end = () => {
      state.dragging = false;
      img.classList.remove("dragging");
    };
    vp.addEventListener("pointerup", end);
    vp.addEventListener("pointercancel", end);
  }

  function bindKeys() {
    document.addEventListener("keydown", (e) => {
      if ($("screen-eval").classList.contains("hidden")) return;
      if (e.target && (e.target.tagName === "TEXTAREA" || e.target.tagName === "INPUT")) return;
      if (e.key === "ArrowLeft") {
        e.preventDefault();
        go(-1);
      } else if (e.key === "ArrowRight") {
        e.preventDefault();
        go(1);
      } else if (e.key === "f" || e.key === "F") {
        setZoom("fit");
      } else if (e.key === "1" && e.altKey) {
        setZoom("x1");
      } else if (e.key === "2" && e.altKey) {
        setZoom("x2");
      } else if (["1", "2", "3", "4", "5"].includes(e.key) && !e.altKey) {
        // Number keys set Noise by default; Shift sets Ringing.
        const score = Number(e.key);
        if (e.shiftKey) setScore("ringing_artifacts", score);
        else setScore("noise", score);
      }
    });
  }

  function init() {
    renderScoreButtons("noise-scores", "noise", NOISE_DEFS);
    renderScoreButtons("ringing-scores", "ringing_artifacts", RINGING_DEFS);

    const noiseDefs = $("noise-defs");
    const ringDefs = $("ringing-defs");
    noiseDefs.innerHTML = Object.keys(NOISE_DEFS)
      .sort((a, b) => Number(b) - Number(a))
      .map((k) => `<li><strong>${k}:</strong> ${NOISE_DEFS[k]}</li>`)
      .join("");
    ringDefs.innerHTML = Object.keys(RINGING_DEFS)
      .sort((a, b) => Number(b) - Number(a))
      .map((k) => `<li><strong>${k}:</strong> ${RINGING_DEFS[k]}</li>`)
      .join("");

    document.querySelectorAll('input[name="rater"]').forEach((input) => {
      input.addEventListener("change", renderStart);
    });
    $("btn-start").addEventListener("click", () => {
      const selected = document.querySelector('input[name="rater"]:checked');
      if (!selected) return;
      beginSession(selected.value, { resume: false });
    });
    $("btn-resume").addEventListener("click", () => {
      const selected = document.querySelector('input[name="rater"]:checked');
      if (!selected) return;
      beginSession(selected.value, { resume: true });
    });
    $("btn-prev").addEventListener("click", () => go(-1));
    $("btn-next").addEventListener("click", () => go(1));
    $("notes").addEventListener("input", (e) => {
      const id = IMAGE_IDS[state.index];
      state.ratings[id].notes = e.target.value;
      saveSession();
      updateThumbStrip();
    });
    document.querySelectorAll("[data-zoom]").forEach((btn) => {
      btn.addEventListener("click", () => setZoom(btn.dataset.zoom));
    });
    $("btn-export-inline").addEventListener("click", exportCsv);
    $("btn-export-complete").addEventListener("click", exportCsv);
    $("btn-finish").addEventListener("click", showComplete);
    $("btn-back-eval").addEventListener("click", () => {
      showScreen("eval");
      renderEval();
    });
    $("btn-reset").addEventListener("click", resetProgress);
    $("btn-switch-rater").addEventListener("click", () => {
      saveSession();
      showScreen("start");
      renderStart();
    });

    bindViewerPan();
    bindKeys();
    window.addEventListener("resize", applyTransform);
    window.addEventListener("beforeunload", saveSession);

    renderStart();
  }

  // Expose a tiny test hook for offline smoke checks (no ratings fabricated).
  window.__NR_EVAL__ = {
    IMAGE_IDS,
    CSV_HEADER,
    buildCsvForTest(raterId, ratings) {
      state.raterId = raterId;
      state.ratings = ratings;
      return buildCsv(raterId);
    },
    isComplete,
  };

  document.addEventListener("DOMContentLoaded", init);
})();
