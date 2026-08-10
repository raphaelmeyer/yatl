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

- [ ] **Pin the runtime tooling.** Decide `wasmtime` vs `wasm-tools run` for
      executing a WASI component and capturing its stdout; add it to the dev
      environment / CI image and record the version. `poc/` already assumes
      `wasmtime` + `wasm-tools` and pins WASI wit at `v0.2.12`; match that.
      If neither can be installed in CI yet, stop here and leave this whole
      section as a blocked follow-up rather than guessing at a harness that
      can't run.
- [x] **Scanner: `//` line comments.** `Parser.Scanner.scanToken` dispatches
      on `{ } ( ) ; -` plus whitespace and identifiers; `/` currently hits
      `unexpectedCharacter`, so annotation comments would fail to scan. Add
      `'/' -> lineComment`, matching a second `/` and skipping to end of
      line (a lone `/` stays a scan error). New `ScannerSpec` tests: comment
      at end of line, whole-line comment, comment on the last line with no
      trailing newline, lone `/` is an error, and that the following line's
      token locations are still right.
- [ ] **The `conformance` package skeleton.** `conformance/conformance.cabal`
      with a `conformance-test` (hspec + `process` + `directory` +
      `filepath`) and a `conformance-style` stanza mirroring `yatlc`'s
      (ormolu + hlint via `build-tool-depends`, `tools/Style.hs`), plus
      `.hlint.yaml`, `.gitignore` (`dist-newstyle/`, `_build/`) and a
      `conformance.tasks.yml` exposing `build` / `test` / `check` / `lint` /
      `format` / `deps` in the shape `yatlc.tasks.yml` already uses. Wire it
      into the root `Taskfile.yml` and add the folder to
      `yatl.code-workspace`. No license file — the root `LICENSE` covers it.
- [ ] **Annotation parser.** `conformance/test/Annotations.hs` with a pure
      `expectedLines :: Text -> [Text]` scanning `// [out]: ...` comments and
      returning one expected output line each, in source order. New
      `AnnotationsSpec` tests: several `[out]:` lines, none at all, ordinary
      comments and blank lines ignored, an empty `// [out]:` meaning an empty
      output line, and interior whitespace preserved.
- [ ] **Harness.** `conformance/test/Harness.hs` with
      `runCase :: Case -> IO Text` that locates the three binaries
      (`$YATLC`/`$WASM_TOOLS`/`$WASMTIME`, falling back to `$PATH`, with a
      clear message when missing), gives each case a fresh `_build/<case>/`
      with the WASI wit `deps` linked in, then runs
      `yatlc -b <dir>` → `wasm-tools component embed --world example:foo/foo`
      → `wasm-tools component new` → `wasmtime run`, returning stdout split
      into lines. Any step failing fails the case with that step's output
      attached. No tests of its own — exercised by the case spec below.
- [ ] **Cases + dynamic spec.** `conformance/cases/` starting with the
      currently *parseable* program, `fn main -> void {}` annotated
      `// [out]: foo` (the generator ignores the body today, so this pins the
      hardcoded baseline). `CasesSpec` uses `runIO` to list `cases/*.yatl`
      and generates one `it` per case, checking that it compiles, runs and
      that its output lines match the `[out]:` annotations.
      This is the "already works" baseline — no generator or parser changes
      needed, it just proves the harness end to end.
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
- [ ] **AST: module/import/statement shape.** Replace the empty
      `AST.Function` placeholder with: `Tree` gets `moduleName :: Text.Text`,
      `imports :: [Text.Text]`, `functions :: [Function]`; `Function` gets
      `name :: Text.Text` and `body :: [Statement]`; add
      `Statement = ExpressionStatement Expr`; add
      `Expr = Call {callNamespace :: Text.Text, callFunction :: Text.Text, callArgs :: [Expr]} | StringLiteral Text.Text`.
      Keep it minimal — single-arg calls only, no types, no return values yet.
      No new tests (structural change; covered by the parser tests below).
- [ ] **Parser: module declaration.** Parse the required leading
      `module <identifier>` and store it as `Tree`'s `moduleName`. New tests:
      missing module name, missing `module` keyword entirely.
- [ ] **Parser: import declarations.** Parse zero or more
      `import <identifier> ;` after the module declaration, storing names in
      `imports`. New tests: no imports, one import, missing `;`.
- [ ] **Parser: function name + qualified call-statement grammar.** Thread
      the identifier already consumed in `function` into `Function`'s `name`
      field. Parse a function body as zero or more statements of the shape
      `identifier "::" identifier "(" [Str] ")" ";"`. New
      `FunctionSpec`/`Parser.StatementSpec` cases: call with no args, call
      with one string arg, two calls in sequence, missing `::`, missing `;`,
      missing `)`.
- [ ] **Parser/Compiler: unresolved-namespace error.** If a call's namespace
      wasn't declared via `import`, raise a clear error (e.g. "stdio is not
      imported") rather than silently accepting it — this is what makes
      `import stdio;` load-bearing rather than decorative. New test: calling
      `stdio::print(...)` without `import stdio;` produces that error.
- [ ] **Generator: parameterize the hand-encoded module.** Without changing
      *how* the wasm bytes are built, make `Generator.emit` walk the AST:
      find `main`, and for each `stdio::print(StringLiteral s)` call in
      order, emit a call to the existing wasi write import against a data
      segment holding `s`, concatenating results in program order. New
      golden tests: AST for the target program (`print("Hello")` then
      `print(" World!\n")`) produces a module that prints exactly
      `Hello World!\n`; a single-call case reduces to the current
      byte-for-byte `example` shape (proves it's no longer hardcoded, not
      just re-hardcoded).
- [ ] **Compiler + conformance: wire it up.** Update
      `conformance/cases/hello.yatl` to the exact target program above with a
      single `// [out]: Hello World!` annotation. New test: a
      `CompilerSpec` that runs `compile`/`compileFile` on that program and
      checks the emitted `.wasm` bytes match the golden output from the
      previous step. This is the point where the conformance suite goes green
      on the real target program instead of the `foo\n` placeholder — also a
      good point to add an `[error]:` case exercising the
      unresolved-namespace error from two steps above.
- [ ] **Cut complete:** delete/replace the now-unused hardcoded parts of
      `Generator.example` and `exampleWit` that aren't derived from the AST.
      Update this TODO to move remaining generalization work (multi-arg
      calls, other stdlib functions/namespaces, real LEB128/section encoding
      helpers instead of hand counted byte offsets, etc.) into `## TODOs`
      below.

## TODOs

- fix handling and reporting of error location in scanner after the scanner supports more variations (-, ->, !, !=, ...)
