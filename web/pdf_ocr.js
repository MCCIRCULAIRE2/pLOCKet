window._pdfOcr = {
  _ready: false,
  _failed: false,
  _worker: null,

  async _loadLib(src, fallbackSrc) {
    return new Promise((resolve, reject) => {
      const s = document.createElement('script');
      s.src = src;
      s.onload = resolve;
      s.onerror = () => {
        if (fallbackSrc) {
          console.warn('[pdf_ocr] Échec ' + src + ', fallback ' + fallbackSrc);
          const s2 = document.createElement('script');
          s2.src = fallbackSrc;
          s2.onload = resolve;
          s2.onerror = () => reject(new Error('Introuvable: ' + src));
          document.head.appendChild(s2);
        } else {
          reject(new Error('Introuvable: ' + src));
        }
      };
      document.head.appendChild(s);
    });
  },

  async _init() {
    if (this._ready) return;
    if (this._failed) throw new Error('Initialisation déjà échouée');
    try {
      await this._loadLib(
        'https://cdnjs.cloudflare.com/ajax/libs/pdf.js/3.11.174/pdf.min.js',
        'https://cdn.jsdelivr.net/npm/pdfjs-dist@3.11.174/build/pdf.min.js'
      );
      pdfjsLib.GlobalWorkerOptions.workerSrc = 'https://cdnjs.cloudflare.com/ajax/libs/pdf.js/3.11.174/pdf.worker.min.js';
      await this._loadLib(
        'https://cdn.jsdelivr.net/npm/tesseract.js@5/dist/tesseract.min.js',
        'https://unpkg.com/tesseract.js@5/dist/tesseract.min.js'
      );
      this._ready = true;
    } catch (e) {
      this._failed = true;
      throw e;
    }
  },

  async processPdf(bytes) {
    try {
      await this._init();

      if (!(bytes instanceof Uint8Array)) {
        bytes = new Uint8Array(bytes);
      }

      const pdf = await pdfjsLib.getDocument({ data: bytes }).promise;
      const pages = pdf.numPages;

      let nativeText = '';
      for (let i = 1; i <= pages; i++) {
        const page = await pdf.getPage(i);
        const tc = await page.getTextContent();
        nativeText += tc.items.map(x => x.str).join(' ') + '\n';
      }
      nativeText = nativeText.trim();
      const nativeChars = nativeText.length;

      if (nativeChars > 50) {
        return JSON.stringify({ method: 'text', text: nativeText, pages, nativeChars, error: null });
      }

      if (!this._worker) {
        this._worker = await Tesseract.createWorker('fra');
      }

      let ocrText = '';
      for (let i = 1; i <= pages; i++) {
        const page = await pdf.getPage(i);
        const vp = page.getViewport({ scale: 2 });
        const canvas = document.createElement('canvas');
        canvas.width = vp.width;
        canvas.height = vp.height;
        const ctx = canvas.getContext('2d');
        await page.render({ canvasContext: ctx, viewport: vp }).promise;
        const { data } = await this._worker.recognize(canvas);
        ocrText += data.text + '\n';
      }

      return JSON.stringify({ method: 'ocr', text: ocrText.trim(), pages, nativeChars, error: null });
    } catch (e) {
      return JSON.stringify({ method: 'failed', text: '', pages: 0, nativeChars: 0, error: String(e) });
    }
  }
};
