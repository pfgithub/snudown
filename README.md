﻿Demo:

Interactive: https://pfg.pw/snudown/demo

Run Tests: https://pfg.pw/snudown/test

snudown fork for wasm

Also adds some features from new.reddit markdown parsing

- adds code fence support

# Snudown

`Snudown` is a reddit-specific fork of the [Sundown](http://github.com/vmg/sundown)
Markdown parser used by GitHub.

## Setup

1. Install the latest master version of zig for your platform from the [downloads page](https://ziglang.org/download/) (this is the only dependency)
2. Test `zig build test`
3. Build entry_wasm.wasm `zig build -Drelease-small && cp zig-cache/lib/entry_wasm.wasm docs/entry_wasm.wasm`
4. Run a local webserver (eg `php -S docs` or `serve docs` or something) and navigate to `/demo.html` or `/test.html`

To automatically build on save, use `onchange` (from npm) or something like: `onchange src/\*\*/\* -- fish -c "echo Building… && zig build -Drelease-small && cp zig-cache/lib/entry_wasm.wasm docs/entry_wasm.wasm && echo Finished Building"`

## Thanks

Many thanks to @vmg for implementing the initial version of this fork!

## License

Permission to use, copy, modify, and distribute this software for any
purpose with or without fee is hereby granted, provided that the above
copyright notice and this permission notice appear in all copies.

THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

## TODO

- deinit the GPA to ensure there are no leaks
