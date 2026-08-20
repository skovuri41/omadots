/** Scans the intermediate doc HTML for utility classes actually used, so the
 *  compiled CSS stays small. Re-run via build_docs.py, not directly. */
module.exports = {
  darkMode: 'class',
  content: ['./docs/_intermediate.html'],
  theme: {
    extend: {
      fontFamily: { mono: ['ui-monospace', 'SFMono-Regular', 'Menlo', 'monospace'] },
    },
  },
  plugins: [require('@tailwindcss/typography')],
}
