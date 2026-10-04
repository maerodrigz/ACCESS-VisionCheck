/**
 * ACCESS VisionCheck — Admin Profile Dropdown
 * Modular vanilla JS controller. Initialize with initProfileDropdown(rootElement).
 */

(function (global) {
  'use strict';

  const SELECTORS = {
    root: '[data-profile-dropdown]',
    trigger: '[data-profile-trigger]',
    panel: '[data-profile-panel]',
    menuLink: '[data-profile-menu-item]',
    logoutBtn: '[data-profile-logout]',
    modal: '[data-logout-modal]',
    modalCancel: '[data-logout-cancel]',
    modalConfirm: '[data-logout-confirm]',
  };

  const ACTIVE_CLASS = 'is-active';
  const OPEN_CLASS = 'is-open';
  const MODAL_VISIBLE_CLASS = 'is-visible';

  /** @type {HTMLElement | null} */
  let activeRoot = null;

  /** @type {string | null} */
  let activeMenuId = null;

  /**
   * @param {HTMLElement} root
   */
  function toggleDropdown(root) {
    const el = root || activeRoot;
    if (!el) return;

    const isOpen = el.classList.contains(OPEN_CLASS);
    if (isOpen) {
      closeDropdown(el);
    } else {
      openDropdown(el);
    }
  }

  /**
   * @param {HTMLElement} root
   */
  function openDropdown(root) {
    if (!root) return;
    if (activeRoot && activeRoot !== root) {
      closeDropdown(activeRoot);
    }
    activeRoot = root;
    root.classList.add(OPEN_CLASS);
    const trigger = root.querySelector(SELECTORS.trigger);
    trigger?.setAttribute('aria-expanded', 'true');
    const panel = root.querySelector(SELECTORS.panel);
    panel?.setAttribute('aria-hidden', 'false');
  }

  /**
   * @param {HTMLElement | null} [root]
   */
  function closeDropdown(root) {
    const el = root || activeRoot;
    if (!el) return;

    el.classList.remove(OPEN_CLASS);
    const trigger = el.querySelector(SELECTORS.trigger);
    trigger?.setAttribute('aria-expanded', 'false');
    const panel = el.querySelector(SELECTORS.panel);
    panel?.setAttribute('aria-hidden', 'true');

    if (activeRoot === el) {
      activeRoot = null;
    }
  }

  /**
   * @param {MouseEvent} event
   */
  function closeOnOutsideClick(event) {
    if (!activeRoot) return;
    const target = /** @type {Node} */ (event.target);
    if (!activeRoot.contains(target)) {
      closeDropdown(activeRoot);
    }
  }

  /**
   * @param {KeyboardEvent} event
   */
  function closeOnEscape(event) {
    if (event.key !== 'Escape') return;

    const modal = document.querySelector(`${SELECTORS.modal}.${MODAL_VISIBLE_CLASS}`);
    if (modal) {
      closeLogoutModal();
      return;
    }

    if (activeRoot) {
      closeDropdown(activeRoot);
      const trigger = activeRoot.querySelector(SELECTORS.trigger);
      trigger?.focus();
    }
  }

  /**
   * @param {HTMLElement} link
   * @param {HTMLElement} root
   */
  function setActiveMenuItem(link, root) {
    const menuId = link.getAttribute('data-profile-menu-item');
    if (!menuId) return;

    root.querySelectorAll(SELECTORS.menuLink).forEach((item) => {
      item.classList.remove(ACTIVE_CLASS);
      item.removeAttribute('aria-current');
    });

    link.classList.add(ACTIVE_CLASS);
    link.setAttribute('aria-current', 'page');
    activeMenuId = menuId;
  }

  function openLogoutModal() {
    const modal = document.querySelector(SELECTORS.modal);
    if (!modal) return;
    modal.classList.add(MODAL_VISIBLE_CLASS);
    modal.setAttribute('aria-hidden', 'false');
    const confirmBtn = modal.querySelector(SELECTORS.modalConfirm);
    confirmBtn?.focus();
  }

  function closeLogoutModal() {
    const modal = document.querySelector(SELECTORS.modal);
    if (!modal) return;
    modal.classList.remove(MODAL_VISIBLE_CLASS);
    modal.setAttribute('aria-hidden', 'true');
  }

  /**
   * @param {HTMLElement} root
   * @param {{ onLogout?: () => void, onNavigate?: (id: string) => void, activeItem?: string }} [options]
   */
  function initProfileDropdown(root, options = {}) {
    if (!root) return;

    const trigger = root.querySelector(SELECTORS.trigger);
    const panel = root.querySelector(SELECTORS.panel);
    const logoutBtn = root.querySelector(SELECTORS.logoutBtn);
    const modal = document.querySelector(SELECTORS.modal);
    const modalCancel = document.querySelector(SELECTORS.modalCancel);
    const modalConfirm = document.querySelector(SELECTORS.modalConfirm);

    if (!trigger || !panel) {
      console.warn('[ProfileDropdown] Missing trigger or panel.');
      return;
    }

    trigger.setAttribute('aria-haspopup', 'true');
    trigger.setAttribute('aria-expanded', 'false');
    panel.setAttribute('aria-hidden', 'true');

    if (options.activeItem) {
      const activeLink = root.querySelector(
        `[data-profile-menu-item="${options.activeItem}"]`,
      );
      if (activeLink instanceof HTMLElement) {
        setActiveMenuItem(activeLink, root);
      }
    }

    trigger.addEventListener('click', (e) => {
      e.stopPropagation();
      toggleDropdown(root);
    });

    root.querySelectorAll(SELECTORS.menuLink).forEach((link) => {
      link.addEventListener('click', (e) => {
        e.preventDefault();
        if (!(link instanceof HTMLElement)) return;

        const id = link.getAttribute('data-profile-menu-item');
        setActiveMenuItem(link, root);

        if (typeof options.onNavigate === 'function' && id) {
          options.onNavigate(id);
        }

        closeDropdown(root);
      });
    });

    logoutBtn?.addEventListener('click', (e) => {
      e.preventDefault();
      closeDropdown(root);
      openLogoutModal();
    });

    modalCancel?.addEventListener('click', closeLogoutModal);

    modalConfirm?.addEventListener('click', () => {
      closeLogoutModal();
      if (typeof options.onLogout === 'function') {
        options.onLogout();
      } else {
        console.info('[ProfileDropdown] Logout confirmed.');
      }
    });

    modal?.addEventListener('click', (e) => {
      if (e.target === modal) closeLogoutModal();
    });

    if (typeof lucide !== 'undefined') {
      lucide.createIcons({ attrs: { 'stroke-width': 2 } });
    }
  }

  function initAllProfileDropdowns() {
    document.querySelectorAll(SELECTORS.root).forEach((root) => {
      if (root instanceof HTMLElement) {
        initProfileDropdown(root, {
          onLogout: () => {
            window.location.href = '/login';
          },
          onNavigate: (id) => {
            console.info('[ProfileDropdown] Navigate:', id);
          },
        });
      }
    });

    document.addEventListener('click', closeOnOutsideClick);
    document.addEventListener('keydown', closeOnEscape);
  }

  global.ProfileDropdown = {
    init: initProfileDropdown,
    initAll: initAllProfileDropdowns,
    toggleDropdown,
    closeDropdown,
    openDropdown,
    closeOnOutsideClick,
    closeOnEscape,
    setActiveMenuItem,
    openLogoutModal,
    closeLogoutModal,
  };

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initAllProfileDropdowns);
  } else {
    initAllProfileDropdowns();
  }
})(typeof window !== 'undefined' ? window : globalThis);
