(function () {
  const animationEl = document.getElementById('animation');
  const appShell = document.getElementById('dropZone');
  const emptyState = document.getElementById('emptyState');
  const stage = document.getElementById('stage');
  const dragRegion = document.getElementById('dragRegion');
  const minimizeButton = document.getElementById('minimizeButton');
  const fullscreenButton = document.getElementById('maximizeButton');
  const closeButton = document.getElementById('closeButton');

  const isThumbnail = new URLSearchParams(location.search).has('thumbnail');
  if (isThumbnail) {
    document.body.classList.add('thumbnail');
  }

  let animation = null;
  let zoom = 1;
  let viewX = 0;
  let viewY = 0;
  let paused = false;

  function post(type, payload) {
    if (window.chrome && window.chrome.webview) {
      window.chrome.webview.postMessage(JSON.stringify({ type, payload: payload || {} }));
      return;
    }

    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.tgsPlayer) {
      window.webkit.messageHandlers.tgsPlayer.postMessage({ type, payload: payload || {} });
    }
  }

  function resetView() {
    const rect = stage.getBoundingClientRect();
    zoom = 1;
    viewX = rect.width / 2;
    viewY = rect.height / 2;
    applyView();
  }

  function applyView() {
    animationEl.style.transform = `translate(${viewX}px, ${viewY}px) translate(-50%, -50%) scale(${zoom})`;
  }

  function decodeBase64Utf8(value) {
    const bytes = Uint8Array.from(atob(value), (char) => char.charCodeAt(0));
    return new TextDecoder('utf-8').decode(bytes);
  }

  function base64ToBytes(value) {
    return Uint8Array.from(atob(value), (char) => char.charCodeAt(0));
  }

  async function decodeGzipBytes(bytes) {
    if (!window.DecompressionStream) {
      throw new Error('gzip decompression is not available');
    }

    const stream = new Blob([bytes])
      .stream()
      .pipeThrough(new DecompressionStream('gzip'));
    return new Response(stream).text();
  }

  function loadTgsJsonData(data) {
    appShell.classList.remove('no-file');
    emptyState.classList.add('hidden');

    if (animation) {
      animation.destroy();
      animationEl.replaceChildren();
    }

    animation = window.lottie.loadAnimation({
      container: animationEl,
      renderer: 'svg',
      loop: true,
      autoplay: !isThumbnail,
      animationData: data
    });

    animation.addEventListener('DOMLoaded', () => {
      animation.goToAndStop(0, true);
      if (!isThumbnail) {
        animation.play();
      }
    });

    paused = false;
    resetView();
  }

  window.loadTgsBase64 = function loadTgsBase64(value) {
    const data = JSON.parse(decodeBase64Utf8(value));
    loadTgsJsonData(data);
  };

  window.loadTgsGzipBase64 = async function loadTgsGzipBase64(value) {
    try {
      const json = await decodeGzipBytes(base64ToBytes(value));
      loadTgsJsonData(JSON.parse(json));
    } catch (error) {
      window.showLogoFallback();
    }
  };

  window.showLogoFallback = function showLogoFallback() {
    appShell.classList.add('no-file');
    emptyState.classList.remove('hidden');
    emptyState.innerHTML = '<img class="fallback-logo" src="../logo.png" alt="TGS Player" />';
  };

  window.togglePause = function togglePause() {
    if (!animation) {
      return;
    }

    paused = !paused;
    if (paused) {
      animation.pause();
    } else {
      animation.play();
    }
  };

  function zoomAt(event) {
    if (!animation || isThumbnail) {
      return;
    }

    event.preventDefault();
    const rect = stage.getBoundingClientRect();
    const pointerX = event.clientX - rect.left;
    const pointerY = event.clientY - rect.top;
    const beforeX = (pointerX - viewX) / zoom;
    const beforeY = (pointerY - viewY) / zoom;
    const factor = event.deltaY < 0 ? 1.14 : 1 / 1.14;

    zoom = Math.min(8, Math.max(0.18, zoom * factor));
    viewX = pointerX - beforeX * zoom;
    viewY = pointerY - beforeY * zoom;
    applyView();
  }

  function animateThenPost(action) {
    if (action === 'minimize') {
      appShell.classList.add('window-minimizing');
      window.setTimeout(() => {
        appShell.classList.remove('window-minimizing');
        post('window', { action });
      }, 170);
      return;
    }

    if (action === 'close') {
      post('window', { action });
      return;
    }

    post('window', { action });
  }

  dragRegion.addEventListener('mousedown', () => post('drag'));
  minimizeButton.addEventListener('click', () => animateThenPost('minimize'));
  fullscreenButton.addEventListener('click', () => animateThenPost('fullscreen'));
  closeButton.addEventListener('click', () => animateThenPost('close'));
  document.addEventListener('pointerdown', () => post('focus'));
  stage.addEventListener('dblclick', () => post('pick-file'));
  stage.addEventListener('wheel', zoomAt, { passive: false });

  document.addEventListener('dragover', (event) => {
    event.preventDefault();
    appShell.classList.add('dragging');
  });

  document.addEventListener('dragleave', (event) => {
    if (event.clientX === 0 && event.clientY === 0) {
      appShell.classList.remove('dragging');
    }
  });

  async function loadDroppedFile(file) {
    if (!file || !file.name.toLowerCase().endsWith('.tgs')) {
      return;
    }

    try {
      const json = await decodeGzipBytes(new Uint8Array(await file.arrayBuffer()));
      loadTgsJsonData(JSON.parse(json));
    } catch (error) {
      window.showLogoFallback();
    }
  }

  document.addEventListener('drop', (event) => {
    event.preventDefault();
    appShell.classList.remove('dragging');
    const file = event.dataTransfer && event.dataTransfer.files && event.dataTransfer.files[0];
    loadDroppedFile(file);
  });

  document.addEventListener('keydown', (event) => {
    if (event.code === 'Space') {
      event.preventDefault();
      window.togglePause();
    }
    if (event.key.toLowerCase() === 'f') {
      post('window', { action: 'fullscreen' });
    }
    if (event.key === 'ArrowRight' || event.key === 'ArrowDown') {
      post('folder-next');
    }
    if (event.key === 'ArrowLeft' || event.key === 'ArrowUp') {
      post('folder-prev');
    }
  });

  resetView();
  post('ready');
})();
