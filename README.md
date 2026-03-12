# MS Project Analog for macOS

Native macOS app (Swift/SwiftUI) to open, edit, and save project files compatible with Microsoft Project.

## Features

- **Open:** XML (MSPDI) and MPP (via bundled Java/Python MPXJ converter)
- **Edit:** Tasks (name, dates, duration, % complete, outline level, predecessors), Resources, Assignments
- **Save / Export:** Save as XML (MSPDI); Export XML… and Share from toolbar or File menu; export Gantt diagram to PDF/PNG/JPEG
- **Views:** Task table (with inspector), Gantt chart, Resources table

## Build and run (Swift Package)

```bash
cd "ms project"
swift build
swift run MSProjectAnalog
```

### Сборка на GitHub (CI)

В репозитории есть workflow **Build macOS** (`.github/workflows/build-macos.yml`). Он запускается при push в `main`/`master` и по кнопке «Run workflow». После успешной сборки артефакт **MSProjectAnalog-macOS** (папка `.app`) можно скачать на странице **Actions → выбранный запуск → Artifacts**.

To get a proper `.app` bundle and document types (Open dialog for .xml/.mpp) using Xcode:

1. Open the folder in Xcode: **File → Open** → select the `ms project` folder.
2. Add a new **macOS → App** target (or add the existing sources to an app target).
3. In the app target **Build Settings**, set **Info.plist File** to `Sources/MSProjectAnalog/Info.plist` (or copy the provided `Info.plist` into the app target). It declares document types for `public.xml` and `.mpp`.
4. Add all sources from `Sources/MSProjectAnalog` to the app target and make `MSProjectAnalogApp` the main app entry point.
5. Build and run from Xcode.

## Releases (.app / .dmg)

For end users it is recommended to ship a ready-to-run `.app` inside a `.dmg`:

1. In Xcode select the macOS App target and configure **Signing & Capabilities** with your Developer ID certificate (for distribution outside Mac App Store).
2. Select **Any Mac (Apple Silicon, Intel)** as the destination.
3. Use **Product → Archive**, then export the archive as a Developer ID–signed app.
4. Create a `.dmg` containing the exported `.app` (either via Xcode Organizer or using `hdiutil create` in Terminal).
5. Attach the resulting `.dmg` to a GitHub Release so users can download and run the app with a double click.

## Opening MPP files

The app can open `.mpp` files by converting them to XML (MSPDI).

### Preferred path: bundled Java MPXJ converter

If you add a Java-based MPXJ converter JAR into the app bundle resources as `mpxj-converter.jar`, the app will try to use it first:

1. Build your Java converter on top of MPXJ so that it accepts two arguments: `<input.mpp> <output.xml>` and writes MSPDI XML to the output path.
2. Place the resulting `mpxj-converter.jar` into the app bundle resources (for example by adding it to the Xcode app target resources).
3. At runtime the Swift code calls:
   - `/usr/bin/java -jar mpxj-converter.jar input.mpp output.xml`

With this in place, `.mpp` files will open without requiring Python or `pip` on the user’s machine.

### Fallback: Python + MPXJ (for development)

If the JAR is not present, the app falls back to the Python-based MPXJ converter:

**Dependencies:** install both packages (jpype1 is required by mpxj):

```bash
pip install jpype1 mpxj
```

**How the app finds Python:** when you run from Finder or an IDE, the app first tries your “terminal” Python by running the converter via a login shell (so pyenv/Homebrew paths are used). It then tries pyenv paths (`~/.pyenv/shims/python3`, `~/.pyenv/versions/*/bin/python3`), then `env python3`, Xcode’s Python, and system Python.

**If opening MPP fails:** run the app from Terminal so it uses the same Python as your shell: `swift run MSProjectAnalog`. Alternatively, install the dependencies for the system Python: `/usr/bin/python3 -m pip install --user jpype1 mpxj`.

If neither the Java converter JAR nor Python+mpxj are available, only XML (MSPDI) files can be opened.

## Exporting the Gantt chart

The Gantt chart view can be exported for sharing with stakeholders who do not use project management tools:

- From the toolbar, use the **“Экспорт диаграммы”** menu to export the current Gantt view as:
  - PDF (`Gantt.pdf`)
  - PNG (`Gantt.png`)
  - JPEG (`Gantt.jpg`)
- From the **File → Save/Export** menu group, use:
  - **Export Gantt as PDF…**
  - **Export Gantt as PNG…**
  - **Export Gantt as JPEG…**

## Sample file

Open `SampleProject.xml` to try the app.

## License

This project is licensed under the MIT License – see the `LICENSE` file for details.
