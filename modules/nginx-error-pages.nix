rec {
  errorPage = code: text: detail: ''
    location @house_error_${code} {
      internal;
      default_type text/html;
      return ${code} '<!doctype html>
    <html lang="en">
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <title>${code} ${text}</title>
      <style>
        :root {
          color-scheme: dark;
          --background: #251014;
          --surface: #34161c;
          --surface-soft: #451e26;
          --text: #ffe8e8;
          --muted: #e7a2a8;
          --selected: #ff4d5d;
          --selected-text: #fff5f5;
          --accent: #ff7580;
          --border: #ff4d5d66;
        }
        * { box-sizing: border-box; }
        body {
          min-height: 100vh;
          margin: 0;
          background: var(--background);
          color: var(--text);
          font-family: "Iosevka Term", ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;
          font-size: 15px;
          line-height: 1.5;
        }
        main {
          width: min(100% - 2rem, 760px);
          margin: 0 auto;
          padding: 4rem 0;
        }
        header {
          margin-bottom: 1.5rem;
          border-bottom: 1px solid var(--border);
          padding-bottom: 1rem;
        }
        .panel {
          border: 1px solid var(--border);
          border-radius: 8px;
          background: var(--surface);
          padding: 1rem;
        }
        .code {
          color: var(--accent);
          font-size: clamp(4rem, 18vw, 8rem);
          line-height: 0.9;
          font-weight: 700;
        }
        h1 {
          margin: 0;
          color: var(--selected-text);
          font-size: 1.35rem;
          font-weight: 600;
          letter-spacing: 0;
        }
        p {
          margin: 0.75rem 0 0;
          color: var(--muted);
        }
        a {
          display: inline-block;
          margin-top: 1rem;
          border: 1px solid var(--border);
          border-radius: 8px;
          background: var(--surface);
          padding: 0.35rem 0.55rem;
          color: var(--muted);
          font-size: 0.85rem;
          text-decoration: none;
        }
        a:hover,
        a:focus-visible {
          outline: none;
          background: var(--surface-soft);
          color: var(--selected-text);
        }
      </style>
    </head>
    <body>
      <main>
        <header>
          <div class="code">${code}</div>
          <h1>${text}</h1>
        </header>
        <section class="panel">
          <p>${detail}</p>
          <a href="https://links.house.leo.surf/">Back to links</a>
        </section>
      </main>
    </body>
    </html>';
    }
  '';

  serverSnippet = ''
    error_page 404 = @house_error_404;
    error_page 502 = @house_error_502;
    ${errorPage "404" "Not Found" "$host did not find that page."}
    ${errorPage "502" "Bad Gateway" "$host could not reach the upstream service."}
  '';
}
