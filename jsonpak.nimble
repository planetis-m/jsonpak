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
    for filename in ["builder", "dollar", "extra", "jsonptr",
        "mapper", "parser", "patch", "sorted"]:
      # Generate the docs for the submodules
      buildDoc(srcDir / "jsonpak" / (filename & ".nim"), docsDir / (filename & ".html"))
    # Generate the docs for the main module
    buildDoc(srcDir / "jsonpak.nim", docsDir / "jsonpak.html")
    # Generate the index.html
    exec("nim buildIndex --out:" & (docsDir / "index.html") & " " & docsDir)
