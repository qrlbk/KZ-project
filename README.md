# MS Project Analog for macOS

Native macOS app (Swift/SwiftUI) to open, edit, and save project files compatible with Microsoft Project.

## Features

- **Open:** XML (MSPDI) and MPP (via Python mpxj converter)
- **Edit:** Tasks (name, dates, duration, % complete, outline level, predecessors), Resources, Assignments
- **Save / Export:** Save as XML (MSPDI); Export XML… and Share from toolbar or File menu
- **Views:** Task table (with inspector), Gantt chart, Resources table

## Build and run

```bash
cd "ms project"
swift build
swift run MSProjectAnalog
```

To get a proper `.app` bundle and document types (Open dialog for .xml/.mpp):

1. Open the folder in Xcode: **File → Open** → select the `ms project` folder.
2. Add a new **macOS → App** target (or add the existing sources to an app target).
3. In the app target **Build Settings**, set **Info.plist File** to `Sources/MSProjectAnalog/Info.plist` (or copy the provided `Info.plist` into the app target). It declares document types for `public.xml` and `.mpp`.
4. Build and run from Xcode.

## Opening MPP files

The app can open `.mpp` files by converting them to XML using Python and the mpxj library.

**Dependencies:** Install both packages (jpype1 is required by mpxj):

```bash
pip install jpype1 mpxj
```

**How the app finds Python:** When you run from Finder or an IDE, the app first tries your “terminal” Python by running the converter via a login shell (so pyenv/Homebrew paths are used). It then tries pyenv paths (`~/.pyenv/shims/python3`, `~/.pyenv/versions/*/bin/python3`), then `env python3`, Xcode’s Python, and system Python.

**If opening MPP fails:** Run the app from Terminal so it uses the same Python as your shell: `swift run MSProjectAnalog`. Alternatively, install the dependencies for the system Python: `/usr/bin/python3 -m pip install --user jpype1 mpxj`.

If Python or mpxj is not available, only XML (MSPDI) files can be opened.

## Sample file

Open `SampleProject.xml` to try the app.

## License

Use as you like.
