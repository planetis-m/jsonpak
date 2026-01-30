# Package

version       = "1.1.2"
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

task docs, "Generate documentation":
  # https://nim-lang.github.io/Nim/docgen.html
  let filenames = [
    "jsonpak",
    "jsonpak" / "builder",
    "jsonpak" / "dollar",
    "jsonpak" / "extra",
    "jsonpak" / "jsonptr",
    "jsonpak" / "mapper",
    "jsonpak" / "parser",
    "jsonpak" / "patch",
    "jsonpak" / "sorted"
  ]
  withDir(pkgDir):
    for file in filenames:
      let doc = docsDir / (file.extractFilename & ".html")
      # Generate the docs for {src}
      exec("nim doc --index:on --verbosity:0 --git.url:" & projectUrl &
          " --git.devel:main --git.commit:main --out:" & doc & " " & (srcDir / file))
    exec("nim buildIndex --out:" & (docsDir / "index.html") & " " & docsDir)

