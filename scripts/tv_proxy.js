const http = require('http');
const https = require('https');
const url = require('url');

const PORT = 8999;

const INJECTED_HEAD = `
<style id="nungu-injected-style">
  /* Nungu TV Top Menu Bar */
  #nungu-tv-bar {
    position: fixed;
    top: 0;
    left: 0;
    width: 100vw;
    height: 56px;
    background: rgba(8, 13, 26, 0.94);
    backdrop-filter: blur(16px);
    border-bottom: 1px solid rgba(229, 9, 20, 0.4);
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 0 24px;
    z-index: 2147483647;
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
    color: #ffffff;
    box-shadow: 0 8px 32px rgba(0, 0, 0, 0.7);
    transition: transform 0.3s cubic-bezier(0.16, 1, 0.3, 1), opacity 0.3s ease;
    user-select: none;
  }
  #nungu-tv-bar.hidden {
    transform: translateY(-100%);
    opacity: 0;
    pointer-events: none;
  }
  .ntv-left, .ntv-center, .ntv-right {
    display: flex;
    align-items: center;
    gap: 10px;
  }
  .ntv-brand {
    font-weight: 900;
    font-size: 20px;
    letter-spacing: 2px;
    color: #ffffff;
    margin-right: 14px;
    display: flex;
    align-items: center;
    gap: 8px;
  }
  .ntv-brand::before {
    content: "";
    display: inline-block;
    width: 10px;
    height: 10px;
    border-radius: 50%;
    background: #E50914;
    box-shadow: 0 0 10px #E50914;
  }
  .ntv-btn {
    background: rgba(255, 255, 255, 0.08);
    color: #e2e8f0;
    border: 1px solid rgba(255, 255, 255, 0.12);
    padding: 7px 14px;
    font-size: 14px;
    font-weight: 600;
    border-radius: 8px;
    cursor: pointer;
    outline: none;
    transition: all 0.15s ease;
    text-decoration: none;
    display: inline-flex;
    align-items: center;
    gap: 6px;
  }
  .ntv-btn:hover, .ntv-btn:focus {
    background: #E50914;
    color: #ffffff;
    border-color: #ffffff;
    transform: scale(1.05);
    box-shadow: 0 0 16px rgba(229, 9, 20, 0.6);
  }
  .ntv-lang.active {
    background: rgba(229, 9, 20, 0.3);
    border-color: #E50914;
    color: #ffffff;
  }
  .ntv-action {
    background: rgba(16, 185, 129, 0.2);
    border-color: rgba(16, 185, 129, 0.4);
    color: #34d399;
  }
  .ntv-action:hover, .ntv-action:focus {
    background: #10b981;
    color: #ffffff;
    border-color: #ffffff;
  }
  body {
    padding-top: 56px !important;
  }
</style>
`;

const INJECTED_BODY = `
<div id="nungu-tv-bar">
  <div class="ntv-left">
    <div class="ntv-brand">NUNGU TV</div>
    <button class="ntv-btn" onclick="history.back()" title="Back">◀ Back</button>
    <button class="ntv-btn" onclick="history.forward()" title="Forward">▶ Forward</button>
    <button class="ntv-btn" onclick="location.reload()" title="Reload">⟳ Reload</button>
  </div>
  <div class="ntv-center">
    <button class="ntv-btn ntv-lang" onclick="location.href='/movie/browse/?lang=tamil'">Tamil</button>
    <button class="ntv-btn ntv-lang" onclick="location.href='/movie/browse/?lang=telugu'">Telugu</button>
    <button class="ntv-btn ntv-lang" onclick="location.href='/movie/browse/?lang=hindi'">Hindi</button>
    <button class="ntv-btn ntv-lang" onclick="location.href='/movie/browse/?lang=malayalam'">Malayalam</button>
    <button class="ntv-btn ntv-lang" onclick="location.href='/movie/browse/?lang=kannada'">Kannada</button>
  </div>
  <div class="ntv-right">
    <button id="ntv-login-btn" class="ntv-btn ntv-action" onclick="window._doNunguLogin()">🔑 Sign In</button>
    <button class="ntv-btn" onclick="window._toggleZoom()">🔍 Zoom</button>
    <button class="ntv-btn" onclick="window._toggleBar()" title="Hide Menu">▲ Hide</button>
  </div>
</div>

<script id="nungu-injected-logic">
  (function() {
    // 1. SUPPRESS AUTO-VIRTUAL KEYBOARD ON WEBOS TV
    if (window.PalmSystem && window.PalmSystem.setManualKeyboardEnabled) {
      window.PalmSystem.setManualKeyboardEnabled(true);
    }

    // Blur auto-focused inputs on initial load so the virtual keyboard does not hijack the TV screen
    window.addEventListener('DOMContentLoaded', function() {
      if (document.activeElement && (document.activeElement.tagName === 'INPUT' || document.activeElement.tagName === 'TEXTAREA')) {
        document.activeElement.blur();
      }
    });

    // 2. TOP MENU SHOW / HIDE & REMOTE KEY CONTROL
    var bar = document.getElementById('nungu-tv-bar');
    var hideTimeout = null;

    function resetHideTimer() {
      if (bar) bar.classList.remove('hidden');
      clearTimeout(hideTimeout);
      hideTimeout = setTimeout(function() {
        if (!window._isHoveringBar) {
          if (bar) bar.classList.add('hidden');
        }
      }, 5000);
    }

    window._toggleBar = function() {
      if (!bar) return;
      if (bar.classList.contains('hidden')) {
        resetHideTimer();
      } else {
        bar.classList.add('hidden');
      }
    };

    bar.addEventListener('mouseenter', function() { window._isHoveringBar = true; });
    bar.addEventListener('mouseleave', function() { window._isHoveringBar = false; resetHideTimer(); });

    // Show menu when mouse moves to very top of TV
    window.addEventListener('mousemove', function(e) {
      if (e.clientY < 20) {
        resetHideTimer();
      }
    });

    // Remote Control Buttons
    window.addEventListener('keydown', function(e) {
      // Key 461 = LG Remote Back Button
      if (e.keyCode === 461) {
        if (window.history.length > 1) {
          window.history.back();
        } else if (window.close) {
          window.close();
        }
        return;
      }
      // Key 404 (Menu) or 'M' or Up arrow when at top
      if (e.keyCode === 404 || e.key === 'm' || e.key === 'M') {
        window._toggleBar();
      }
    });

    resetHideTimer();

    // 3. ZOOM CONTROL
    var currentZoom = 1.0;
    window._toggleZoom = function() {
      currentZoom = (currentZoom === 1.0) ? 1.15 : 1.0;
      document.body.style.zoom = currentZoom;
    };

    // 4. AUTO-LOGIN & CREDENTIAL INJECTION
    var accountEmail = 'vishnu32510@gmail.com';
    var accountPass = 'WHeSHRA!u8mL3Xc';

    window._doNunguLogin = function() {
      var emailInput = document.getElementById('login-email');
      var passInput = document.getElementById('login-password');
      var submitBtn = document.getElementById('login-submit');

      if (emailInput && passInput && submitBtn) {
        emailInput.value = accountEmail;
        passInput.value = accountPass;
        emailInput.dispatchEvent(new Event('change', { bubbles: true }));
        passInput.dispatchEvent(new Event('input', { bubbles: true }));
        submitBtn.click();
        var btn = document.getElementById('ntv-login-btn');
        if (btn) btn.textContent = '✓ Logged In';
        setTimeout(function() {
          if (window.$ && window.$.magnificPopup) window.$.magnificPopup.close();
        }, 600);
      } else if (window.Page && window.Page.send) {
        window.Page.send('Login', {Email: accountEmail, Password: accountPass});
        var btn = document.getElementById('ntv-login-btn');
        if (btn) btn.textContent = '✓ Logged In';
      } else {
        window.location.href = '/login/?lang=tamil';
      }
    };

    // Check login state on load and perform automatic login
    function checkLoginStatus() {
      var userPopup = document.getElementById('login-popup');
      var isLoggedOut = !userPopup || !userPopup.getAttribute('data-user') || userPopup.getAttribute('data-user') === '';
      var btn = document.getElementById('ntv-login-btn');
      if (isLoggedOut) {
        if (btn) btn.textContent = '🔑 Sign In';
        // Auto-login proactively!
        if (window.Page && window.Page.send) {
          console.log('[Nungu TV] Triggering background auto-login...');
          window.Page.send('Login', {Email: accountEmail, Password: accountPass});
          if (btn) btn.textContent = '✓ Logged In';
        } else if (document.getElementById('login-email')) {
          window._doNunguLogin();
        }
      } else {
        if (btn) btn.textContent = '✓ ' + (userPopup.getAttribute('data-user') || 'Logged In');
      }
    }

    setTimeout(checkLoginStatus, 1000);

    // 5. 10-MINUTE PLAYBACK WATCHDOG
    setInterval(function() {
      // Auto-dismiss promo popups
      var offer = document.getElementById('pn-offer-close') || document.getElementById('pn-close') || document.getElementById('pn-understand');
      if (offer && offer.offsetParent !== null) offer.click();

      // Clear 10-min interruption popup
      var pop = document.getElementById('login-popup');
      if (pop && (pop.classList.contains('mfp-ready') || pop.style.display === 'block' || !pop.classList.contains('mfp-hide'))) {
        window._doNunguLogin();
        if (window.$ && window.$.magnificPopup) window.$.magnificPopup.close();
      }

      // Auto-resume video if paused by modal
      var vid = document.querySelector('video') || document.getElementById('UIVideoPlayer');
      if (vid && vid.paused && !vid.ended && vid.currentTime > 5) {
        var blk = document.querySelector('.mfp-wrap, .mfp-bg');
        if (blk) {
          blk.remove();
          vid.play().catch(function(){});
        }
      }
    }, 1500);
  })();
</script>
`;

const server = http.createServer((req, res) => {
  const parsedUrl = url.parse(req.url);

  const options = {
    hostname: 'einthusan.tv',
    port: 443,
    path: parsedUrl.path,
    method: req.method,
    headers: {
      ...req.headers,
      host: 'einthusan.tv',
      referer: 'https://einthusan.tv/',
      origin: 'https://einthusan.tv'
    }
  };

  delete options.headers['accept-encoding'];

  const proxyReq = https.request(options, (proxyRes) => {
    const headers = { ...proxyRes.headers };
    // STRIP BLOCKING HEADERS
    delete headers['x-frame-options'];
    delete headers['content-security-policy'];
    headers['access-control-allow-origin'] = '*';
    headers['access-control-allow-credentials'] = 'true';

    // REWRITE COOKIES TO WORK ON LOCALHOST / 127.0.0.1
    if (headers['set-cookie']) {
      headers['set-cookie'] = headers['set-cookie'].map(cookieStr => {
        return cookieStr
          .replace(/;\s*domain=[^;]+/gi, '')
          .replace(/;\s*secure/gi, '')
          .replace(/;\s*samesite=[^;]+/gi, '; SameSite=Lax');
      });
    }

    // REWRITE 307 / 302 REDIRECT LOCATIONS
    if (headers['location'] && headers['location'].startsWith('https://einthusan.tv')) {
      headers['location'] = headers['location'].replace('https://einthusan.tv', '');
    }

    const contentType = headers['content-type'] || '';
    const isHtml = contentType.includes('text/html');

    if (isHtml) {
      delete headers['content-length'];
      res.writeHead(proxyRes.statusCode, headers);

      let body = '';
      proxyRes.setEncoding('utf8');
      proxyRes.on('data', chunk => { body += chunk; });
      proxyRes.on('end', () => {
        if (body.includes('</head>')) {
          body = body.replace('</head>', INJECTED_HEAD + '</head>');
        } else {
          body = INJECTED_HEAD + body;
        }
        if (body.includes('</body>')) {
          body = body.replace('</body>', INJECTED_BODY + '</body>');
        } else {
          body = body + INJECTED_BODY;
        }
        res.end(body);
      });
    } else {
      res.writeHead(proxyRes.statusCode, headers);
      proxyRes.pipe(res);
    }
  });

  proxyReq.on('error', (err) => {
    console.error('Proxy request error:', err);
    res.writeHead(502);
    res.end('Proxy Error: ' + err.message);
  });

  req.pipe(proxyReq);
});

server.listen(PORT, '127.0.0.1', () => {
  console.log(`Nungu TV Local Proxy with Cookie Rewriting & Top Bar active on http://127.0.0.1:${PORT}`);
});
