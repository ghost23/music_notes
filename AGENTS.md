# AGENTS.md

For a basic understanding of what we're doing in this project, please read
`docs/architecture.md` and `docs/rewrite-plan.md`.

## Setup commands

- run `flutter pub get` to install dependencies
- run `flutter upgrade` to upgrade flutter itself
- run `flutter doctor` to check for any issues with your setup
- run `flutter pub outdated` to check for outdated dependencies

## Build commands
- run `flutter pub run build_runner build` to build the app
- The SMUFL standard defines a set of glyphs that are used in music notation.
  To generate the proper Dart files for the glyph definitions from the SMUFL standard,
  run `node convertJsonToDart.mjs`.

We are only interested in the desktop build targets (macOS and Windows)

## Finding files / code from flutter or installed packages

When searching for files / code from flutter or from installed packages,
please make use of the fact that you know that flutter is installed in ~/development/flutter/.
And installed packages can be found in ~/.pub-cache/hosted/pub.dev/.
So please avoid searches with a wildcard prefix that will search the entire filesystem if possible.

Alternatively, you could search the web to find documentation, like e.g.:
- https://api.flutter.dev/flutter/painting

## Geometry, Drawing, Rendering and Canvas

This library deals a lot with geometry, with rendering and layout. Before you implement
something yourself, check if the flutter framework and its painting package in particular
or the vector_math package provide what you need.

## Naming things

- Use descriptive yet concise names that accurately reflect the purpose of the code or file.
- Do not name things from the perspective of an entity that uses the thing but rather
  from the perspective of the thing itself and what it provides.
- A name for a thing that lives in a well-defined context does not need to carry its context
  in the name.
- Avoid using abbreviations or acronyms unless they are widely recognized and unambiguous.