#!/usr/bin/env python3
"""
Regenerate the single-page HTML doc site for the omadots repo.

Run this any time README.md, README-dev-stack.md, or CHEZMOI-GUIDE.md
change. It re-renders all three into one self-contained, Tailwind-styled
HTML file (docs/index.html) - CSS is compiled locally and inlined, so the
output has zero external dependencies at render time.

One-time setup (already done if node_modules/ exists in the repo root):
    npm install

Usage:
    python3 docs/build_docs.py [--out PATH]

Defaults assume this script lives at <repo-root>/docs/build_docs.py and
the three source markdown files live at <repo-root>/*.md.
"""
import argparse
import html
import re
import shutil
import subprocess
import sys
from pathlib import Path

try:
    import markdown
except ImportError:
    sys.exit("Missing dependency: pip install markdown --break-system-packages")

SCRIPT_DIR = Path(__file__).resolve().parent
REPO_ROOT = SCRIPT_DIR.parent

# (nav label, slug, source markdown path relative to repo root, short description)
DOCS = [
    ("Overview", "overview", "README.md", "Repo layout & brand-new-laptop setup"),
    ("Dev Stack Guide", "dev-stack", "README-dev-stack.md", "install-dev-stack.sh, tool by tool"),
    ("Chezmoi Guide", "chezmoi", "CHEZMOI-GUIDE.md", "Day-to-day dotfiles workflow"),
]

MD_EXTENSIONS = [
    "fenced_code",
    "tables",
    "toc",
    "sane_lists",
    "attr_list",
    "def_list",
    "footnotes",
]


def slugify(text, separator="-"):
    s = re.sub(r"[^\w\s-]", "", text).strip().lower()
    return re.sub(r"[\s_]+", separator, s)


def render_doc(md_path):
    text = md_path.read_text(encoding="utf-8")
    md = markdown.Markdown(extensions=MD_EXTENSIONS, extension_configs={
        "toc": {"slugify": slugify, "permalink": False},
    })
    body_html = md.convert(text)
    # toc_tokens available on the Markdown instance after convert()
    outline = [
        {"level": t["level"], "id": t["id"], "name": t["name"]}
        for t in md.toc_tokens
        if t["level"] in (1, 2)
    ]
    return body_html, outline


def build_nav_outline(doc_slug, outline):
    if not outline:
        return ""
    items = []
    for entry in outline:
        indent = "pl-6" if entry["level"] == 2 else "pl-3"
        items.append(
            f'<a href="#{doc_slug}/{entry["id"]}" '
            f'class="doc-outline-link {indent} block truncate rounded px-2 py-1 text-[13px] '
            f'text-slate-500 hover:text-teal-600 hover:bg-teal-50 '
            f'dark:text-slate-400 dark:hover:text-teal-400 dark:hover:bg-slate-800" '
            f'data-doc="{doc_slug}">{html.escape(entry["name"])}</a>'
        )
    return "\n".join(items)


def build():
    sections = []
    sidebar_docs = []
    sidebar_outlines = []

    for i, (label, slug, filename, desc) in enumerate(DOCS):
        md_path = REPO_ROOT / filename
        if not md_path.exists():
            sys.exit(f"Missing source file: {md_path}")
        body_html, outline = render_doc(md_path)
        active = "block" if i == 0 else "hidden"

        sections.append(f"""
        <section id="doc-{slug}" data-doc="{slug}" class="doc-section {active}">
          <article class="prose prose-slate dark:prose-invert max-w-none
                           prose-headings:scroll-mt-20 prose-a:text-teal-600 dark:prose-a:text-teal-400">
            {body_html}
          </article>
        </section>""")

        nav_active = "bg-teal-50 text-teal-700 dark:bg-slate-800 dark:text-teal-400" if i == 0 else "text-slate-600 dark:text-slate-300"
        sidebar_docs.append(f"""
          <button data-doc-target="{slug}"
                  class="doc-nav-btn w-full text-left rounded-lg px-3 py-2 mb-0.5 {nav_active}
                         hover:bg-teal-50 hover:text-teal-700 dark:hover:bg-slate-800 dark:hover:text-teal-400
                         transition-colors">
            <div class="text-sm font-semibold">{html.escape(label)}</div>
            <div class="text-xs text-slate-400 dark:text-slate-500">{html.escape(desc)}</div>
          </button>""")

        sidebar_outlines.append(f"""
          <div data-outline-for="{slug}" class="doc-outline {'block' if i == 0 else 'hidden'} mb-4">
            {build_nav_outline(slug, outline)}
          </div>""")

    return TEMPLATE.format(
        sections="\n".join(sections),
        sidebar_docs="\n".join(sidebar_docs),
        sidebar_outlines="\n".join(sidebar_outlines),
    )


TEMPLATE = """<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width, initial-scale=1" />
<title>omadots docs</title>
<style>
/*__TAILWIND_CSS__*/
html {{ scroll-behavior: smooth; }}
::selection {{ background: #99f6e4; }}
.dark ::selection {{ background: #115e59; }}

/* Code block / inline code contrast, kept as plain CSS (not Tailwind's
   prose-code:/prose-pre: modifiers) on purpose: those modifiers apply to
   every <code>, including the ones nested inside <pre>, and silently won
   the cascade over Typography's own pre-code reset - background went
   light while the text color stayed the light shade meant for a dark
   background, making fenced code blocks unreadable in light mode. Same
   fixed dark background/light text for code blocks in both page modes;
   inline code flips for contrast against its surrounding text. */
.prose pre {{
  background-color: #0f172a;
  color: #e2e8f0;
  border: 1px solid #1e293b;
}}
.prose pre code {{
  background-color: transparent;
  color: inherit;
  padding: 0;
  border: 0;
  border-radius: 0;
  font-weight: 400;
}}
.prose :not(pre) > code {{
  background-color: #f1f5f9;
  color: #0f172a;
  padding: 0.125rem 0.375rem;
  border-radius: 0.25rem;
  font-weight: 400;
}}
.dark .prose :not(pre) > code {{
  background-color: #1e293b;
  color: #e2e8f0;
}}
.prose code::before,
.prose code::after {{
  content: none;
}}
</style>
</head>
<body class="bg-white dark:bg-slate-950 text-slate-800 dark:text-slate-200">

<div class="flex min-h-screen">

  <!-- Sidebar -->
  <aside class="hidden md:flex md:w-72 md:flex-col border-r border-slate-200 dark:border-slate-800
                 sticky top-0 h-screen overflow-y-auto shrink-0 px-4 py-6">
    <div class="flex items-center gap-2 px-2 mb-6">
      <div class="h-7 w-7 rounded-md bg-teal-500 flex items-center justify-center text-white font-bold text-sm">o</div>
      <div>
        <div class="font-semibold text-sm leading-tight">omadots</div>
        <div class="text-[11px] text-slate-400">docs</div>
      </div>
      <button id="theme-toggle" class="ml-auto text-slate-400 hover:text-slate-700 dark:hover:text-slate-100" title="Toggle theme">
        <svg id="icon-sun" class="h-4 w-4 hidden" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M12 3v1.5m0 15V21m9-9h-1.5M4.5 12H3m15.36 6.36-1.06-1.06M6.7 6.7 5.64 5.64m12.72 0-1.06 1.06M6.7 17.3l-1.06 1.06M12 7.5a4.5 4.5 0 100 9 4.5 4.5 0 000-9z"/></svg>
        <svg id="icon-moon" class="h-4 w-4" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M21 12.79A9 9 0 1111.21 3 7 7 0 0021 12.79z"/></svg>
      </button>
    </div>

    <nav class="mb-4">
      {sidebar_docs}
    </nav>

    <div class="border-t border-slate-200 dark:border-slate-800 pt-3">
      <div class="text-[11px] font-semibold uppercase tracking-wide text-slate-400 px-2 mb-1">On this page</div>
      {sidebar_outlines}
    </div>

    <div class="mt-auto pt-4 text-[11px] text-slate-400 px-2">
      Generated from README.md / README-dev-stack.md / CHEZMOI-GUIDE.md
    </div>
  </aside>

  <!-- Mobile nav -->
  <div class="md:hidden sticky top-0 z-10 bg-white/90 dark:bg-slate-950/90 backdrop-blur border-b border-slate-200 dark:border-slate-800 px-4 py-3 flex items-center gap-2">
    <div class="h-6 w-6 rounded bg-teal-500 flex items-center justify-center text-white font-bold text-xs">o</div>
    <select id="mobile-doc-select" class="flex-1 text-sm bg-transparent border border-slate-200 dark:border-slate-700 rounded px-2 py-1"></select>
    <button id="theme-toggle-mobile" class="text-slate-400">
      <svg class="h-4 w-4" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M21 12.79A9 9 0 1111.21 3 7 7 0 0021 12.79z"/></svg>
    </button>
  </div>

  <!-- Content -->
  <main class="flex-1 min-w-0">
    <div class="max-w-3xl mx-auto px-6 py-10 md:py-14">
      {sections}
    </div>
  </main>
</div>

<script>
  const docButtons = document.querySelectorAll('[data-doc-target]');
  const docSections = document.querySelectorAll('.doc-section');
  const docOutlines = document.querySelectorAll('.doc-outline');
  const mobileSelect = document.getElementById('mobile-doc-select');

  const docMeta = [...docButtons].map(b => ({{
    slug: b.dataset.docTarget,
    label: b.querySelector('div').textContent
  }}));
  docMeta.forEach(d => {{
    const opt = document.createElement('option');
    opt.value = d.slug; opt.textContent = d.label;
    mobileSelect.appendChild(opt);
  }});

  function activate(slug, {{ scrollTop = true }} = {{}}) {{
    docSections.forEach(s => s.classList.toggle('hidden', s.dataset.doc !== slug));
    docOutlines.forEach(o => o.classList.toggle('hidden', o.dataset.outlineFor !== slug));
    docButtons.forEach(b => {{
      const on = b.dataset.docTarget === slug;
      b.classList.toggle('bg-teal-50', on);
      b.classList.toggle('text-teal-700', on);
      b.classList.toggle('dark:bg-slate-800', on);
      b.classList.toggle('dark:text-teal-400', on);
    }});
    mobileSelect.value = slug;
    if (scrollTop) window.scrollTo({{ top: 0 }});
  }}

  docButtons.forEach(b => b.addEventListener('click', () => {{
    activate(b.dataset.docTarget);
    history.replaceState(null, '', '#' + b.dataset.docTarget);
  }}));
  mobileSelect.addEventListener('change', () => activate(mobileSelect.value));

  document.querySelectorAll('.doc-outline-link').forEach(link => {{
    link.addEventListener('click', (e) => {{
      const [slug, id] = link.getAttribute('href').slice(1).split('/');
      activate(slug, {{ scrollTop: false }});
      setTimeout(() => document.getElementById(id)?.scrollIntoView({{ behavior: 'smooth', block: 'start' }}), 30);
      e.preventDefault();
    }});
  }});

  // Deep-link on load: #slug or #slug/heading-id
  const initial = location.hash.replace('#', '').split('/');
  if (initial[0] && docMeta.some(d => d.slug === initial[0])) {{
    activate(initial[0], {{ scrollTop: !initial[1] }});
    if (initial[1]) setTimeout(() => document.getElementById(initial[1])?.scrollIntoView({{ block: 'start' }}), 30);
  }}

  // Theme toggle (in-memory only, no storage APIs)
  function setTheme(dark) {{
    document.documentElement.classList.toggle('dark', dark);
    document.getElementById('icon-sun').classList.toggle('hidden', !dark);
    document.getElementById('icon-moon').classList.toggle('hidden', dark);
  }}
  let isDark = window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches;
  setTheme(isDark);
  function toggleTheme() {{ isDark = !isDark; setTheme(isDark); }}
  document.getElementById('theme-toggle').addEventListener('click', toggleTheme);
  document.getElementById('theme-toggle-mobile').addEventListener('click', toggleTheme);
</script>
</body>
</html>
"""


def compile_tailwind_css(intermediate_html_path):
    """Run the local Tailwind CLI (via npx) against the intermediate HTML so
    only the utility classes actually used are compiled - no CDN, no JIT
    script at page-load time. Requires `npm install` to have been run once
    in the repo root (tailwindcss + @tailwindcss/typography as devDeps)."""
    npx = shutil.which("npx")
    if not npx:
        sys.exit("npx not found - install Node.js, then `npm install` in the repo root")
    input_css = SCRIPT_DIR / "input.css"
    config = SCRIPT_DIR / "tailwind.config.js"
    tmp_css = SCRIPT_DIR / "_tw-output.css"
    result = subprocess.run(
        [npx, "tailwindcss", "-i", str(input_css), "-o", str(tmp_css),
         "--config", str(config), "--minify"],
        cwd=str(REPO_ROOT), capture_output=True, text=True,
    )
    if result.returncode != 0:
        sys.exit(f"tailwindcss build failed:\n{result.stdout}\n{result.stderr}")
    css = tmp_css.read_text(encoding="utf-8")
    tmp_css.unlink(missing_ok=True)
    return css


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=str(REPO_ROOT / "docs" / "index.html"))
    args = ap.parse_args()
    out_path = Path(args.out)
    out_path.parent.mkdir(parents=True, exist_ok=True)

    intermediate_html = build()
    intermediate_path = SCRIPT_DIR / "_intermediate.html"
    intermediate_path.write_text(intermediate_html, encoding="utf-8")

    css = compile_tailwind_css(intermediate_path)
    final_html = intermediate_html.replace("/*__TAILWIND_CSS__*/", css, 1)
    intermediate_path.unlink(missing_ok=True)

    out_path.write_text(final_html, encoding="utf-8")
    print(f"Wrote {out_path} ({out_path.stat().st_size:,} bytes, {len(css):,} bytes of compiled CSS)")


if __name__ == "__main__":
    main()
