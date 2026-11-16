/* ACCESS VisionCheck — offline five-criteria human evaluation (research only). */
(function () {
  "use strict";

  const IMAGE_IDS = Array.from({ length: 40 }, (_, i) => `FC${String(i + 1).padStart(3, "0")}`);
  const STORAGE_PREFIX = "access_fc_eval_v1_";
  const CRITERIA = [
    {
      key: "sharpness",
      title: "Sharpness",
      hint: "Fine subject detail / micro-contrast",
      defs: {
        5: "Crisp micro-detail at 100% on the intended subject.",
        4: "Slight softness; still clearly detailed for documentation.",
        3: "Soft detail; edges rounded; identity still clear.",
        2: "Soft enough that fine details are hard to read.",
        1: "Mushy / plastic; subject detail largely lost.",
      },
    },
    {
      key: "blur",
      title: "Blur",
      hint: "Freedom from motion / defocus smear",
      defs: {
        5: "Subject free of smear or unintended soft focus.",
        4: "Mild softness or tiny streak; still acceptable.",
        3: "Noticeable smear or defocus; subject still identifiable.",
        2: "Strong smear / miss-focus; retake preferred.",
        1: "Subject unreadable due to blur.",
      },
    },
    {
      key: "brightness",
      title: "Brightness / Exposure",
      hint: "Under- and over-exposure both lower the score",
      defs: {
        5: "Subject well exposed; important tones readable.",
        4: "Slightly dark or bright; subject still clear.",
        3: "Clearly under- or over-exposed; subject still findable.",
        2: "Severe under/over; large loss of subject detail.",
        1: "Subject lost in black or white; unusable exposure.",
      },
    },
    {
      key: "contrast",
      title: "Contrast",
      hint: "Usable tonal separation (not harsh clip)",
      defs: {
        5: "Clear, usable tonal separation; subject reads easily.",
        4: "Mildly flat or mildly punchy; still fine for docs.",
        3: "Flat or harsh; subject still separable.",
        2: "Very flat or heavily crushed; hard to read subject.",
        1: "Nearly no usable range; subject merges into wash or ink.",
      },
    },
    {
      key: "blocking_artifacts",
      title: "Blocking Artifacts",
      hint: "Freedom from compression mosaic / tiles",
      defs: {
        5: "No visible blocks at 100% in flats.",
        4: "Faint tiling only at 200% in a few flats.",
        3: "Visible blocks in flats at 100%.",
        2: "Obvious mosaic across large flat areas.",
        1: "Blocking dominates; heavily crushed by compression.",
      },
    },
  ];

  const CSV_HEADER = [
    "media_id",
    "rater_id",
    "media_type",
    "sharpness",
    "blur",
    "brightness",
    "contrast",
    "blocking_artifacts",
    "noise",
    "ringing_artifacts",
    "flickering",
    "motion_stability",
    "overall_visual_quality",
    "notes",
  ];

  const state = {
    raterId: null,
    index: 0,
    ratings: {},
    zoomMode: "fit",
    panX: 0,
    panY: 0,
    dragging: false,
    dragStartX: 0,
    dragStartY: 0,
    panStartX: 0,
    panStartY: 0,
  };

  const $ = (id) => document.getElementById(id);

  function storageKey(raterId) {
    return STORAGE_PREFIX + raterId;
  }

  function emptyRow() {
    const row = { notes: "" };
    CRITERIA.forEach((c) => {
      row[c.key] = null;
    });
    return row;
  }

  function emptyRatings() {
    const out = {};
    IMAGE_IDS.forEach((id) => {
      out[id] = emptyRow();
    });
    return out;
  }

  function normalizeScore(v) {
    const n = parseInt(v, 10);
    return n >= 1 && n <= 5 ? n : null;
  }

  function loadSession(raterId) {
    try {
      const raw = localStorage.getItem(storageKey(raterId));
      if (!raw) return null;
      const parsed = JSON.parse(raw);
      const ratings = emptyRatings();
      IMAGE_IDS.forEach((id) => {
        const row = (parsed.ratings && parsed.ratings[id]) || {};
        const next = emptyRow();
        CRITERIA.forEach((c) => {
          next[c.key] = normalizeScore(row[c.key]);
        });
        next.notes = typeof row.notes === "string" ? row.notes : "";
        ratings[id] = next;
      });
      const index = Math.min(Math.max(parseInt(parsed.index, 10) || 0, 0), IMAGE_IDS.length - 1);
      return { ratings, index };
    } catch (_) {
      return null;
    }
  }

  function saveSession() {
    if (!state.raterId) return;
    localStorage.setItem(
      storageKey(state.raterId),
      JSON.stringify({ ratings: state.ratings, index: state.index, savedAt: new Date().toISOString() })
    );
  }

  function rowComplete(row) {
    return CRITERIA.every((c) => row[c.key] >= 1 && row[c.key] <= 5);
  }

  function completeCount() {
    return IMAGE_IDS.filter((id) => rowComplete(state.ratings[id])).length;
  }

  function buildCriteriaUI() {
    const root = $("criteria-root");
    root.innerHTML = "";
    CRITERIA.forEach((c) => {
      const wrap = document.createElement("div");
      wrap.className = "criterion";
      wrap.style.marginBottom = "1rem";
      wrap.innerHTML = `<header><strong>${c.title}</strong><span style="font-size:.75rem;color:var(--muted);margin-left:.5rem">${c.hint}</span></header>`;
      const grid = document.createElement("div");
      grid.className = "score-grid";
      grid.dataset.key = c.key;
      for (let s = 5; s >= 1; s--) {
        const btn = document.createElement("button");
        btn.type = "button";
        btn.className = "score-btn";
        btn.textContent = String(s);
        btn.dataset.score = String(s);
        btn.title = c.defs[s];
        btn.addEventListener("click", () => {
          const id = IMAGE_IDS[state.index];
          state.ratings[id][c.key] = s;
          saveSession();
          renderRatings();
          renderProgress();
        });
        grid.appendChild(btn);
      }
      const defs = document.createElement("ol");
      defs.className = "score-defs";
      defs.style.fontSize = ".75rem";
      defs.style.color = "var(--muted)";
      for (let s = 5; s >= 1; s--) {
        const li = document.createElement("li");
        li.textContent = `${s}: ${c.defs[s]}`;
        defs.appendChild(li);
      }
      wrap.appendChild(grid);
      wrap.appendChild(defs);
      root.appendChild(wrap);
    });
  }

  function renderRatings() {
    const id = IMAGE_IDS[state.index];
    const row = state.ratings[id];
    document.querySelectorAll(".score-grid").forEach((grid) => {
      const key = grid.dataset.key;
      grid.querySelectorAll(".score-btn").forEach((btn) => {
        const active = String(row[key]) === btn.dataset.score;
        btn.setAttribute("aria-pressed", active ? "true" : "false");
        btn.classList.toggle("active", active);
      });
    });
    $("notes").value = row.notes || "";
    $("btn-export").disabled = completeCount() !== IMAGE_IDS.length;
    $("export-status").textContent =
      completeCount() === IMAGE_IDS.length
        ? "All images rated. You can export CSV."
        : `${completeCount()} / ${IMAGE_IDS.length} images fully rated.`;
  }

  function renderProgress() {
    const done = completeCount();
    $("progress-label").textContent = `${done} of ${IMAGE_IDS.length} complete`;
    $("progress-fill").style.width = `${(100 * done) / IMAGE_IDS.length}%`;
    const strip = $("thumb-strip");
    strip.innerHTML = "";
    IMAGE_IDS.forEach((id, i) => {
      const b = document.createElement("button");
      b.type = "button";
      b.textContent = String(i + 1);
      b.className = "thumb" + (i === state.index ? " current" : "") + (rowComplete(state.ratings[id]) ? " done" : "");
      b.addEventListener("click", () => {
        state.index = i;
        saveSession();
        showImage();
      });
      strip.appendChild(b);
    });
  }

  function applyZoom() {
    const img = $("photo");
    const vp = $("viewport");
    img.style.transform = "";
    if (state.zoomMode === "fit") {
      img.style.maxWidth = "100%";
      img.style.maxHeight = "100%";
      img.style.width = "auto";
      img.style.height = "auto";
      state.panX = state.panY = 0;
      $("zoom-label").textContent = "Fit";
    } else {
      const scale = state.zoomMode === "x2" ? 2 : 1;
      img.style.maxWidth = "none";
      img.style.maxHeight = "none";
      const w = img.naturalWidth * scale;
      img.style.width = `${w}px`;
      img.style.height = "auto";
      img.style.transform = `translate(${state.panX}px, ${state.panY}px)`;
      $("zoom-label").textContent = state.zoomMode === "x2" ? "200%" : "100%";
    }
    document.querySelectorAll("[data-zoom]").forEach((btn) => {
      btn.setAttribute("aria-pressed", btn.dataset.zoom === state.zoomMode ? "true" : "false");
    });
    void vp;
  }

  function showImage() {
    const id = IMAGE_IDS[state.index];
    $("image-id").textContent = id;
    $("image-pos").textContent = `Image ${state.index + 1} of ${IMAGE_IDS.length}`;
    const img = $("photo");
    const err = $("load-error");
    err.classList.add("hidden");
    img.onload = () => {
      state.zoomMode = "fit";
      applyZoom();
    };
    img.onerror = () => {
      err.textContent = `Missing image ../images/${id}.jpg (collection not started or file absent).`;
      err.classList.remove("hidden");
    };
    img.src = `../images/${id}.jpg`;
    renderRatings();
    renderProgress();
  }

  function exportCsv() {
    if (completeCount() !== IMAGE_IDS.length) return;
    const lines = [CSV_HEADER.join(",")];
    IMAGE_IDS.forEach((id) => {
      const r = state.ratings[id];
      const cells = [
        id,
        state.raterId,
        "photo",
        r.sharpness,
        r.blur,
        r.brightness,
        r.contrast,
        r.blocking_artifacts,
        "N/A",
        "N/A",
        "N/A",
        "N/A",
        "N/A",
        `"${String(r.notes || "").replace(/"/g, '""')}"`,
      ];
      lines.push(cells.join(","));
    });
    const blob = new Blob([lines.join("\n") + "\n"], { type: "text/csv;charset=utf-8" });
    const a = document.createElement("a");
    a.href = URL.createObjectURL(blob);
    a.download = `${state.raterId}_five_criteria_ratings.csv`;
    a.click();
    URL.revokeObjectURL(a.href);
  }

  function enterSession(resume) {
    const selected = document.querySelector('input[name="rater"]:checked');
    if (!selected) return;
    state.raterId = selected.value;
    const saved = loadSession(state.raterId);
    if (resume && saved) {
      state.ratings = saved.ratings;
      state.index = saved.index;
    } else {
      state.ratings = emptyRatings();
      state.index = 0;
      saveSession();
    }
    $("active-rater").textContent = state.raterId;
    $("screen-start").classList.add("hidden");
    $("screen-eval").classList.remove("hidden");
    buildCriteriaUI();
    showImage();
  }

  function bind() {
    document.querySelectorAll('input[name="rater"]').forEach((el) => {
      el.addEventListener("change", () => {
        const id = el.value;
        const saved = loadSession(id);
        $("btn-start").disabled = false;
        $("btn-resume").disabled = !saved;
        $("resume-info").textContent = saved
          ? `Saved progress found for ${id}.`
          : `No saved progress for ${id}.`;
      });
    });
    $("btn-start").addEventListener("click", () => enterSession(false));
    $("btn-resume").addEventListener("click", () => enterSession(true));
    $("btn-prev").addEventListener("click", () => {
      state.index = Math.max(0, state.index - 1);
      saveSession();
      showImage();
    });
    $("btn-next").addEventListener("click", () => {
      state.index = Math.min(IMAGE_IDS.length - 1, state.index + 1);
      saveSession();
      showImage();
    });
    $("btn-export").addEventListener("click", exportCsv);
    $("btn-home").addEventListener("click", () => {
      saveSession();
      $("screen-eval").classList.add("hidden");
      $("screen-start").classList.remove("hidden");
    });
    $("notes").addEventListener("input", () => {
      state.ratings[IMAGE_IDS[state.index]].notes = $("notes").value;
      saveSession();
    });
    document.querySelectorAll("[data-zoom]").forEach((btn) => {
      btn.addEventListener("click", () => {
        state.zoomMode = btn.dataset.zoom;
        state.panX = state.panY = 0;
        applyZoom();
      });
    });
    const vp = $("viewport");
    vp.addEventListener("pointerdown", (e) => {
      if (state.zoomMode === "fit") return;
      state.dragging = true;
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
      applyZoom();
    });
    vp.addEventListener("pointerup", () => {
      state.dragging = false;
    });
  }

  bind();
})();
