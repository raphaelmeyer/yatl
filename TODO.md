# TODO

## Conformance Suite

Goal: a `conformance/` package at the repo root — a Haskell/hspec suite that
drives the *shipped* compiler over small `.yatl` programs, each carrying its
own expectations as comments:

```
// [out]: Hello World!
module main
import stdio;
fn main() -> {
   stdio::print("Hello");
   stdio::print(" World!\n");
}
```

or, for a program that must not compile:

```
// [error]: 1:14: Expect '{'.
fn main() -> }
```

One `[out]:` annotation per *line* the program is expected to write — not
per print call. The annotations are collected in source order and compared
against the program's stdout split into lines, so the two calls above
produce a single line and a single annotation. `[error]:` works the same
way, one annotation per rendered compiler error, in source order. A case
has either kind, never both.

The suite runs *now*, against today's hardcoded `Generator.example` output,
so the Vertical Cut below has an executable safety net from its first step
instead of only at the end.

**`[out]:` cases first, `[error]:` cases after.** Error cases are part of the
design, not a maybe — but they're sequenced behind the output cases because
they pull in compiler-side work that isn't done: the CLI still exits 0 on a
failed compile (`Compiler.compile` does `mapM_ print errors`), so a caller
can't tell failure from success, and the errors are `show`n rather than
rendered in the `line:col: message` shape the annotations use. No filename in
that shape for now — a case is a single file and the harness knows which one
it ran. Until those land, the harness treats a compile failure as a plain
toolchain failure: the case fails, with whatever the compiler printed
attached.

**Black box, by design.** `conformance` does *not* depend on the `yatlc`
library — it shells out to the `yatlc` binary and then to the component
tooling, exactly as a user would. That keeps the two packages independent
(no root `cabal.project`) and makes the suite a statement about the shipped
compiler rather than its internals.

**Annotations live in the source file**, which means the language needs
comments before the suite can exist. That prerequisite is done.

- [ ] **Harness: refactor the control flow.** `conformance/test/Harness.hs`
      exists and is exercised end to end: `Harness.runCase` locates the three
      binaries (`$YATLC`/`$WASM_TOOLS`/`$WASMTIME`, falling back to `$PATH`),
      gives the case a fresh `_build/<case>/` with the WASI wit `deps` linked
      in, then runs `yatlc -b <dir>` → `wasm-tools component embed --world
      example:foo/foo` → `wasm-tools component new` → `wasmtime run`,
      returning a `CaseResult` (`Success`/`CompileError`/`RuntimeError`, no
      exceptions). `HarnessSpec` runs it against `conformance/cases/hello.yatl`
      (`fn main() -> {}`, no annotation yet) and asserts the hardcoded
      `["foo"]`. It works, but was written for exactly one case and three
      fixed binaries, so the control flow is more repetitive than it should
      be long-term: the three binary lookups are a manually nested
      `case ... of Left/Right`, the four pipeline steps
      (compile/embed/new/run) are the same nested-Either shape again, and the
      `wasmPath`/`embedPath`/`componentPath` construction repeats
      `buildDir SysFP.</> name` three times. Don't fix this speculatively —
      revisit once `[error]:` cases and the multi-case `CasesSpec` below give
      it a second real call site, so the abstraction is shaped by an actual
      second use rather than guessed at now.
- [ ] **Annotation parser, wired in immediately.**
      `conformance/test/Annotations.hs` with a pure
      `expectedLines :: Text -> [Text]` scanning `// [out]: ...` comments and
      returning one expected output line each, in source order. Add
      `// [out]: foo` to `hello.yatl` and replace the hardcoded `["foo"]` in
      `HarnessSpec` with `expectedLines` read from the case file, so the
      previous step's test now derives its expectation from the annotation
      instead of a literal — the parser is used the moment it exists. New
      `AnnotationsSpec` tests for the scanning logic itself: several `[out]:`
      lines, none at all, ordinary comments and blank lines ignored, an empty
      `// [out]:` meaning an empty output line, interior whitespace preserved.
- [ ] **Cases + dynamic spec.** Generalize `HarnessSpec` into `CasesSpec`,
      using `runIO` to list `cases/*.yatl` and generating one `it` per case,
      each checking that it compiles, runs, and that its output lines match
      its `[out]:` annotations. Add a second trivial case alongside
      `hello.yatl` to prove the generalization isn't just re-hardcoding a
      single file.
- [ ] **Wire into CI.** Add `conformance:ci` to the root `Taskfile.yml`'s
      `ci` task, and add `wasmtime` + `wasm-tools` (pinned versions from the
      first step) to the CI image alongside GHC. The `deps` task must fetch
      the WASI wit definitions before the suite runs.
- [ ] **Compiler: render errors and fail.** Add
      `Compiler.Error.render :: Error -> Text` producing `line:col: message`,
      and have the CLI write those to stderr and exit non-zero instead of
      `mapM_ print errors` with a success exit code. New `Compiler.ErrorSpec`
      covering the rendered shape for a scan and a parse error, plus a
      `CompilerSpec` case that a broken program yields the rendered errors.
- [ ] **`[error]:` cases.** Extend the annotation parser to `[error]:`
      (rejecting a case that mixes the two kinds), and the harness to return
      the compiler's stderr lines when `yatlc` exits non-zero, skipping the
      component/run steps. `CasesSpec` then checks those lines against the
      `[error]:` annotations. First case: whatever scan error is cheapest to
      trigger today, e.g. a lone `@`.

Note: `conformance/cases/*.yatl` are *living* — each step of the Vertical Cut
that changes what the compiler accepts or emits should add/update cases and
their `[out]`/`[error]` annotations, rather than the harness being
reassembled from scratch at the end.

## Vertical Cut

Goal: a real, non-hardcoded end-to-end path from source to a running program.
Target program:

```
module main

import stdio;

fn main() -> {
   stdio::print("Hello");
   stdio::print(" World!\n");
}
```

`stdio::print` is resolved to a "standard library" import (concretely, for
now, the wasi `wasi:cli/stdout` + `wasi:io/streams` write path already
hand-encoded in `Generator.example`) — `import stdio;` is what licenses the
`stdio::` qualifier to resolve. Each step that changes what the compiler
accepts/emits should also update `conformance/cases/hello.yatl` (and/or add
new cases) with matching `[out]`/`[error]` annotations from the Conformance
Suite section above. Each step below should be a small, independently
reviewable commit.

- [ ] **Scanner: string literals.** Add `Token.Str Text.Text`, scan `"..."`
      (no escapes yet, just reject unterminated strings with a scan error).
      New tests in `ScannerSpec`: simple string, empty string, unterminated
      string error.
- [ ] **Scanner: module/import syntax.** Add keywords `module`, `import` and
      a `::` symbol token (`Token.DoubleColon`). New tests in `ScannerSpec`:
      keywords tokenize, `::` tokenizes (and doesn't get eaten as two `:`
      since `:` alone isn't a token yet — decide it's a scan error on its
      own).

Each of the steps below plugs its AST/grammar addition into the *real*
compiler pipeline in the same commit — updating `hello.yatl` (or adding a
case) and keeping the conformance suite invoked and green (or intentionally,
explainably red where noted) — rather than growing the AST or grammar up
front and only wiring it into `yatlc`/the conformance suite once everything
exists. That's a deliberate departure from a purely architectural ordering:
it surfaces contract mismatches (CLI exit codes, AST shapes the generator
actually needs, etc.) at the step that introduces them instead of at a big
"wire it up" step at the end.

- [ ] **AST + Parser: module declaration, wired immediately.** Give `Tree` a
      `moduleName :: Text.Text` field (it stops being a bare `newtype` over
      `[Function]`) and parse the required leading `module <identifier>` into
      it — leave `imports` and `Function`'s shape for the next two steps
      rather than designing the full AST now. `Generator`/`Compiler` don't
      need to change; they still ignore everything and emit the hardcoded
      module. Update `conformance/cases/hello.yatl` to prepend `module main`
      above its body, keeping the `// [out]: foo` annotation green — that's
      what proves the new grammar is wired into the shipped compiler, not
      just exercised by a parser unit test. New tests: missing module name,
      missing `module` keyword entirely.
- [ ] **AST + Parser: import declarations, wired immediately.** Add
      `imports :: [Text.Text]` to `Tree`; parse zero or more
      `import <identifier> ;` after the module declaration into it. Update
      `hello.yatl` to add `import stdio;`; still green against
      `// [out]: foo`. New tests: no imports, one import, missing `;`.
- [ ] **AST + Parser: function name + qualified call-statement grammar.**
      Give `Function` a `name :: Text.Text` and `body :: [Statement]`; add
      `Statement = ExpressionStatement Expr`; add
      `Expr = Call {callNamespace :: Text.Text, callFunction :: Text.Text, callArgs :: [Expr]} | StringLiteral Text.Text`
      (single-arg calls only, no types, no return values yet). Thread the
      identifier already consumed in `function` into `name`, and parse the
      body as zero or more `identifier "::" identifier "(" [Str] ")" ";"`
      statements. Update `hello.yatl` to its final target body (both
      `stdio::print` calls) — the generator still ignores it and emits the
      old hardcoded bytes, so the annotation *stays* `// [out]: foo` for now.
      That mismatch between what the source says and what actually runs is
      intentional and temporary: it's what proves the full target grammar
      round-trips through the real `yatlc`/`wasm-tools`/`wasmtime` pipeline
      before any generator work starts, rather than only through
      `Parser.parse` in isolation. New `FunctionSpec`/`Parser.StatementSpec`
      cases: call with no args, call with one string arg, two calls in
      sequence, missing `::`, missing `;`, missing `)`.
- [ ] **Parser/Compiler: unresolved-namespace error.** If a call's namespace
      wasn't declared via `import`, raise a clear error (e.g. "stdio is not
      imported") rather than silently accepting it — this is what makes
      `import stdio;` load-bearing rather than decorative. New test: calling
      `stdio::print(...)` without `import stdio;` produces that error, checked
      at the `Compiler` level for now. A conformance-level `[error]:` case for
      this can land once the Conformance Suite's "Compiler: render errors and
      fail" step has landed, in whichever order the two tracks happen to run.
- [ ] **Generator: parameterize the hand-encoded module — cut lands.**
      Without changing *how* the wasm bytes are built, make `Generator.emit`
      walk the AST: find `main`, and for each `stdio::print(StringLiteral s)`
      call in order, emit a call to the existing wasi write import against a
      data segment holding `s`, concatenating results in program order. In
      the same commit, flip `hello.yatl`'s annotation from `// [out]: foo` to
      `// [out]: Hello World!` — this is the point the conformance suite goes
      green on the real target program instead of the placeholder, landing
      together with the change that makes it true rather than as a separate
      follow-up step. New golden tests in `CompilerSpec`: the target
      program's AST produces a module that prints exactly `Hello World!\n`
      and matches a captured golden `.wasm` byte-for-byte; a single-call
      program reduces to the current byte-for-byte `example` shape (proves
      it's derived, not just re-hardcoded). If the Conformance Suite's
      error-rendering has landed by now, also add the `[error]:` case for the
      unresolved-namespace error from the step above.
- [ ] **Cut complete:** delete/replace the now-unused hardcoded parts of
      `Generator.example` and `exampleWit` that aren't derived from the AST.
      Update this TODO to move remaining generalization work (multi-arg
      calls, other stdlib functions/namespaces, real LEB128/section encoding
      helpers instead of hand counted byte offsets, etc.) into `## TODOs`
      below.

## TODOs

- extract toolchain binaries from conformance test runner and only locate
  them once
- fix handling and reporting of error location in scanner after the scanner
  supports more variations (-, ->, !, !=, ...)
- managing the dependencies (`deps` in build folder). should system
  dependencies (wasi) be copied into the build folder? is it possible to
  reference other and multiple locations?
- extract the compile/build steps from the conformance tests into the yatlc
  binary. getting wasi files, invoking wasm-tools etc should be part of the
  build process managed by yatlc.
