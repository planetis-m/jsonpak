# Package

version       = "1.0.0"
author        = "planetis-m"
description   = "Packed ASTs for compact and efficient JSON representation, with JSON Pointer, JSON Patch support."
license       = "MIT"
srcDir        = "src"

# Dependencies

requires "nim >= 1.9.3"

import os

let
  projectUrl = "https://github.com/planetis-m/jsonpak"
  pkgDir = thisDir().quoteShell
  docsDir = "docs"

proc buildDoc(src, doc: string) =
  exec("nim doc --index:on --verbosity:0 --git.url:" & projectUrl &
      " --git.devel:main --git.commit:main --out:" & doc & " " & src)

task docs, "Generate documentation":
  # https://nim-lang.github.io/Nim/docgen.html
  withDir(pkgDir):
    let filenames = [
      "builder", "dollar", "extra", "jsonptr",
      "mapper", "parser", "patch", "sorted"
    ]
    for file in filenames:
      # Generate the docs for {src}
      buildDoc(srcDir / "jsonpak" / (file & ".nim"), docsDir / (file & ".html"))
    buildDoc(srcDir / "jsonpak.nim", docsDir / "jsonpak.html")
    exec("nim buildIndex --out:" & (docsDir / "index.html") & " " & docsDir)
