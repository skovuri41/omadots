---
name: clojure-style
description: Write, review, or refactor Clojure/ClojureScript code in the idiomatic community style - naming, formatting, namespace layout, threading macros, data-structure and control-flow idioms, docstrings, and test conventions. Use for any .clj/.cljs/.cljc file, or when asked to write or review Clojure code.
license: MIT
---

# Idiomatic Clojure style

Community conventions distilled from the Clojure Style Guide
(https://guide.clojure.style/, the successor to bbatsov/clojure-style-guide).
Apply these when writing new Clojure/ClojureScript code, reviewing a diff, or
refactoring existing code - not just to a single function in isolation, but
to how it fits the surrounding namespace.

## Naming

- Functions and vars: `kebab-case`, e.g. `(defn some-fun ...)`, `(def some-var ...)`.
- Predicates (anything returning a boolean-ish value) end in `?`: `even?`, `valid-email?`.
- Functions with side effects, or unsafe outside a transaction, end in `!`: `save-user!`, `reset!`.
- Protocols, records, types: `CapitalCase` - `defprotocol Serializable`, `defrecord HttpRequest`.
- Vars meant to be dynamically rebound get earmuffs: `(def ^:dynamic *connection* nil)`.
- Intentionally-ignored bindings use `_`: `(let [[a b _ c] values] ...)`.
- Conversion functions use `->` in the name, not "to": `f->c`, not `f-to-c`.
- Private functions get `defn-`, not a naming convention - use it whenever a function is an implementation detail, not part of the namespace's public surface.

## Formatting and layout

- 2-space indentation, never tabs.
- ~80 columns as a soft target; some projects agree on 100-120, but pick one width per project and stay consistent.
- Align `let` bindings and map keys vertically:
  ```clojure
  (let [thing1 "some stuff"
        thing2 "other stuff"]
    ...)

  {:name "Bruce"
   :age  30}
  ```
- Gather closing parens on one line rather than spreading them across lines - don't put a `)` alone on its own line the way C-family braces do.
- One blank line between top-level forms; no blank lines inside a function body (except to visually pair `let`/`cond` clauses).
- Sort `:require`/`:import` entries alphabetically inside the `ns` form; order is `refer-clojure`, then `require`, then `import`.

## Namespace organization

- Always multi-segment: `project.module` or `org.project.module`, never a bare `(ns example)`.
- Prefer `(:require [clojure.string :as str])` - never `:use`, which is deprecated.
- Use the idiomatic aliases everyone already expects: `str` for `clojure.string`, `set` for `clojure.set`, `io` for `clojure.java.io`, `pp` for `clojure.pprint`.

## Functions

- Keep functions short - aim under 10 lines, ideally under 5. A long function is a namespace-organization problem more often than it looks.
- More than 3-4 positional args is a sign to accept a single options map instead.
- Multiple arities: order from fewest args to most, each aligned with its own parameter vector.
- Prefer `{:pre [...]} {:post [...]}` conditions for argument/return validation over inline `(when-not ... (throw ...))` checks at the top of a function body.

## Control flow and data idioms

- Threading macros over nested calls - this is the single highest-leverage idiom:
  ```clojure
  ;; good
  (->> (range 1 10)
       (filter even?)
       (map (partial * 2)))

  ;; avoid - reads inside-out
  (map (partial * 2) (filter even? (range 1 10)))
  ```
  `->` threads into the first argument position (good for accessor-style chains, e.g. maps/records), `->>` threads into the last (good for sequence pipelines).
- `when` instead of `(if pred (do ...))` for a single branch with no `else`.
- `if-let` / `when-let` instead of a separate `let` + `if`/`when` when the condition and the value you need are the same expression.
- Higher-order functions (`map`, `filter`, `reduce`, `keep`, ...) over `loop`/`recur` whenever the shape fits - reach for `loop/recur` only when you genuinely need custom recursion the built-ins can't express.
- `(seq coll)` as the nil/empty check for sequences, not `(not (empty? coll))` or a manual length check.
- Sets as predicates: `(filter #{:a :e :i :o :u} coll)` reads better than an `or` chain of `=` checks.
- `case` over `cond` when every branch tests the same value against compile-time constants; use `:else` (not `true`) as `cond`'s catch-all.
- Don't wrap an existing function in an unnecessary lambda: `(filter even? xs)`, not `(filter #(even? %) xs)`.
- Vectors for general-purpose ordered storage; reserve lists for code-as-data / macro contexts.
- Keywords as map keys, and as the accessor: `(:name m)`, not `(get m :name)` and never `(m :name)` (throws on a non-associative `m`).
- Destructuring over positional `nth` access - it documents intent and survives shape changes better.
- Don't shadow anything from `clojure.core` with a local binding name.

## Docstrings and comments

- Docstrings go in the `defn` form itself, not as separate metadata.
- First line is a complete, capitalized sentence - tools extract just that line for summaries.
- Wrap parameter names in backticks inside the docstring text so editors can pick them out: `` "Takes `x`, returns double `x`." ``.
- Comment density by leading-semicolon count: `;;;;` for a major section heading, `;;;` for a top-level comment outside any form, `;;` for a comment on its own line inside code, `;` for a trailing inline comment.
- `TODO` / `FIXME` / `OPTIMIZE` / `HACK` / `REVIEW` markers are fine and expected; keep the format consistent within a project.
- Prefer making the code self-explanatory over commenting what it does; comment *why*, not *what*.

## State and mutation

- `swap!` over `reset!` for atoms whenever the new value depends on the old one - `reset!` should mean "I'm deliberately discarding history," not "this happens to be the usual way to update."
- `alter` (not `ref-set`) for coordinated updates inside `dosync` transactions; keep transactions small to limit retry contention.
- Never update an atom from inside a `dosync` block - atom updates aren't transactional and will re-run on every STM retry.
- `send` for CPU-bound agent actions, `send-off` for actions that block on I/O.

## Testing

- Test namespace `foo.bar` lives in `test/foo/bar_test.clj`, namespaced `foo.bar-test`.
- `deftest` names end in `-test`.
- Group related assertions under `testing` so failures report contextually.
- Use `are` for tabular input/expected-output tests instead of repeating near-identical `is` forms.
- One logical behavior per `deftest`; use nested `testing` blocks for edge cases of that behavior, not a second top-level `deftest`.

## Macros and exceptions

- Don't reach for a macro if a plain function does the job - macros can't be passed to `map`/`filter`/`comp`, which quietly forecloses a lot of composition.
- Write example call sites before the macro's implementation, to keep its surface clean.
- Reuse standard exception types (`IllegalArgumentException`, etc.); use `ex-info` when you need structured data attached to the error.
- `with-open` over manual `try`/`finally` for anything that needs closing.
- Catch specific exception types - catching bare `Throwable` risks swallowing serious `Error`s the process should not suppress.

## When conventions conflict

The style guide itself is explicit that some of this is taste, not law (indentation style for macros vs. function calls, comment-marker density, and similar). When a project's existing code has already made a consistent choice - even a different one from above - match the surrounding file over this guide. Consistency within a codebase beats any single rule here.
