(function (root) {
  'use strict';
  function validBuild(value) {
    return typeof value === 'string' && /^[a-f0-9]{64}$/.test(value);
  }
  function createChecker(options) {
    var checking = false;
    var dismissed = null;
    return {
      dismiss: function (id) { dismissed = id; },
      check: async function () {
        if (checking || !validBuild(options.current)) return;
        checking = true;
        try {
          var release = await options.read();
          if (release && validBuild(release.buildId) &&
              release.buildId !== options.current && release.buildId !== dismissed) {
            options.available(release.buildId);
          }
        } catch (_) {
          // Offline, timeout and invalid JSON are retried on the next interval.
        } finally { checking = false; }
      }
    };
  }
  if (typeof module !== 'undefined' && module.exports) {
    module.exports = { createChecker: createChecker, validBuild: validBuild };
    return;
  }

  var meta = document.querySelector('meta[name="fjellfisk-build"]');
  var current = meta && meta.content;
  if (!validBuild(current)) return;
  var banner;
  var latest;
  var lastCheck = 0;
  var checker = createChecker({
    current: current,
    read: async function () {
      var controller = new AbortController();
      var timer = setTimeout(function () { controller.abort(); }, 8000);
      try {
        var url = new URL('release.json', document.baseURI);
        url.searchParams.set('check', Date.now().toString());
        var response = await fetch(url, { cache: 'no-store', signal: controller.signal });
        if (!response.ok) return null;
        return await response.json();
      } finally { clearTimeout(timer); }
    },
    available: function (id) {
      latest = id;
      if (banner) return;
      banner = document.createElement('aside');
      banner.setAttribute('role', 'status');
      banner.setAttribute('aria-live', 'polite');
      banner.id = 'fjellfisk-update';
      banner.style.cssText = 'position:fixed;bottom:16px;left:16px;right:16px;max-width:540px;margin:auto;padding:16px;background:white;color:#173c67;border:1px solid #bdd3e9;border-radius:8px;box-shadow:0 4px 20px #0002;z-index:2147483647;font:15px/1.5 Arial,sans-serif;box-sizing:border-box';
      var message = document.createElement('p');
      message.textContent = 'Ny versjon av Fjellfisk er tilgjengelig.';
      message.style.margin = '0 0 10px';
      banner.appendChild(message);
      function button(label, action) {
        var element = document.createElement('button');
        element.type = 'button';
        element.textContent = label;
        element.style.cssText = 'padding:9px 14px;margin:0 8px 0 0;border:1px solid #0b63e5;border-radius:5px;background:#fff;color:#0b63e5;cursor:pointer;font:inherit';
        element.onclick = action;
        banner.appendChild(element);
        return element;
      }
      var update = button('Oppdater nå', function () {
        if (window.fjellfiskSaving) {
          message.textContent = 'Vent til registreringen er ferdig lagret før du oppdaterer.';
          return;
        }
        if (!window.confirm('Appen lastes på nytt. Har du lagret endringene dine?')) return;
        var url = new URL(window.location.href);
        url.searchParams.set('fjellfisk_build', latest);
        window.location.replace(url.href);
      });
      update.style.background = '#0b63e5';
      update.style.color = 'white';
      button('Senere', function () {
        checker.dismiss(latest);
        banner.remove();
        banner = null;
      });
      document.body.appendChild(banner);
    }
  });
  function check() {
    if (document.hidden || Date.now() - lastCheck < 60000) return;
    lastCheck = Date.now();
    checker.check();
  }
  setTimeout(check, 15000);
  setInterval(check, 5 * 60 * 1000);
  window.addEventListener('focus', check);
  window.addEventListener('online', check);
  document.addEventListener('visibilitychange', check);
})(typeof window !== 'undefined' ? window : globalThis);
