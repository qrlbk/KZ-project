import Foundation

/// Converts MPP (binary MS Project) to MSPDI XML using Python (mpxj).
/// Используется только ваш Python: путь из шелла (command -v python3) и явные пути pyenv (~/.pyenv/versions/*/bin/python3).
enum MPPConverter {
    static func convertToXML(mppData: Data, sourceURL: URL? = nil) throws -> Data {
        let tempDir = FileManager.default.temporaryDirectory
        let mppPath = tempDir.appendingPathComponent(UUID().uuidString + ".mpp")
        let xmlPath = tempDir.appendingPathComponent(UUID().uuidString + ".xml")
        defer { try? FileManager.default.removeItem(at: mppPath); try? FileManager.default.removeItem(at: xmlPath) }
        try mppData.write(to: mppPath)

        let scriptPath = tempDir.appendingPathComponent("mpp_convert_\(UUID().uuidString).py")
        let script = """
        import sys
        try:
            import jpype
            import os
            import pathlib
            import mpxj

            # Ensure MPXJ jars are on the JVM classpath
            libdir = pathlib.Path(mpxj.__file__).parent / "lib"
            jars = [str(p) for p in libdir.glob("*.jar")]
            if not jars:
                raise RuntimeError(f"No MPXJ jars found in {libdir}")

            if not jpype.isJVMStarted():
                # JPype accepts classpath as string or list; string is most reliable
                jpype.startJVM(classpath=os.pathsep.join(jars))

            # Use JClass to avoid import-hook issues
            UniversalProjectReader = jpype.JClass("org.mpxj.reader.UniversalProjectReader")
            UniversalProjectWriter = jpype.JClass("org.mpxj.writer.UniversalProjectWriter")
            FileFormat = jpype.JClass("org.mpxj.writer.FileFormat")

            reader = UniversalProjectReader()
            project = reader.read(sys.argv[1])
            writer = UniversalProjectWriter(FileFormat.MSPDI)
            writer.write(project, sys.argv[2])
        except Exception as e:
            try:
                cp = jpype.getClassPath() if hasattr(jpype, "getClassPath") else ""
            except Exception:
                cp = ""
            print(str(e), file=sys.stderr)
            print(f"MPXJ jars: {len(jars) if 'jars' in locals() else 'unknown'}", file=sys.stderr)
            if cp:
                print(f"JPype classpath: {cp}", file=sys.stderr)
            sys.exit(1)
        """
        try script.write(to: scriptPath, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: scriptPath) }

        var lastStderr: String?

        // 1) Путь к python3 из интерактивного логин-шелла (тот же, что в терминале)
        if let resolvedPath = resolvePythonPathViaShell(), resolvedPath.hasPrefix("/"),
           FileManager.default.isExecutableFile(atPath: resolvedPath) {
            switch runPython(executable: resolvedPath, arguments: [scriptPath.path, mppPath.path, xmlPath.path], xmlPath: xmlPath) {
            case .success(let data): return data
            case .failure(let err): lastStderr = err.message
            }
        }

        // 2) Явные пути pyenv (только ваш Python из ~/.pyenv)
        for pyPath in pyenvPythonPaths() {
            switch runPython(executable: pyPath, arguments: [scriptPath.path, mppPath.path, xmlPath.path], xmlPath: xmlPath) {
            case .success(let data): return data
            case .failure(let err): lastStderr = err.message
            }
        }

        throw MPPConverterError.noConverterAvailable(pythonStderr: lastStderr)
    }

    private struct PythonRunError: Error { let message: String }

    /// Путь к python3 из интерактивного логин-шелла (как в терминале пользователя).
    private static func resolvePythonPathViaShell() -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-l", "-i", "-c", "command -v python3"]
        process.environment = minimalShellEnvironment()
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        guard (try? process.run()) != nil else { return nil }
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let path = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: "\n").first
            .map(String.init) ?? ""
        return path.hasPrefix("/") ? path : nil
    }

    /// Минимальное окружение для шелла (без PATH из приложения), чтобы PATH задал профиль (.zshrc, pyenv).
    private static func minimalShellEnvironment() -> [String: String] {
        let env = ProcessInfo.processInfo.environment
        var minimal: [String: String] = [:]
        if let home = env["HOME"] { minimal["HOME"] = home }
        if let user = env["USER"] { minimal["USER"] = user }
        return minimal
    }

    /// Пути к python3 в pyenv: сначала реальные бинарники (versions), затем shim.
    private static func pyenvPythonPaths() -> [String] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        var paths: [String] = []
        let versionsDir = URL(fileURLWithPath: "\(home)/.pyenv/versions")
        if let entries = try? FileManager.default.contentsOfDirectory(at: versionsDir, includingPropertiesForKeys: nil) {
            for dir in entries.sorted(by: { $0.path > $1.path }) where (try? dir.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
                let py = dir.appendingPathComponent("bin/python3").path
                if FileManager.default.isExecutableFile(atPath: py) { paths.append(py) }
            }
        }
        let shim = "\(home)/.pyenv/shims/python3"
        if FileManager.default.isExecutableFile(atPath: shim) { paths.append(shim) }
        return paths
    }

    /// Путь к Java (JAVA_HOME) для JPype/mpxj. Проверяем Homebrew OpenJDK.
    private static func javaHome() -> String? {
        let candidates = [
            "/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home",
            "/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home",
            "/opt/homebrew/opt/openjdk/libexec/openjdk.jdk/Contents/Home",
        ]
        for path in candidates {
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue {
                return path
            }
        }
        return nil
    }

    private static func runPython(executable: String, arguments: [String], xmlPath: URL) -> Result<Data, PythonRunError> {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        var env = ProcessInfo.processInfo.environment
        if let jh = javaHome() {
            env["JAVA_HOME"] = jh
            let javaBin = jh + "/bin"
            env["PATH"] = javaBin + ":" + (env["PATH"] ?? "")
        }
        process.environment = env
        let errPipe = Pipe()
        process.standardOutput = FileHandle.nullDevice
        process.standardError = errPipe
        guard (try? process.run()) != nil else { return .failure(PythonRunError(message: "Не удалось запустить \(executable)")) }
        process.waitUntilExit()
        let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
        let stderr = String(data: errData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard process.terminationStatus == 0 else { return .failure(PythonRunError(message: stderr.isEmpty ? "Код выхода \(process.terminationStatus)" : stderr)) }
        guard let data = try? Data(contentsOf: xmlPath) else { return .failure(PythonRunError(message: "Не удалось прочитать результат")) }
        return .success(data)
    }

    private static func convertWithJava(mppPath: URL, xmlPath: URL) throws -> Data {
        // Expect MPXJ JAR in app bundle Resources or on PATH; not bundled by default
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/java")
        process.arguments = ["-jar", "mpxj.jar", mppPath.path, "-o", xmlPath.path]
        process.currentDirectoryURL = Bundle.main.resourceURL
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw MPPConverterError.javaFailed }
        return try Data(contentsOf: xmlPath)
    }
}

enum MPPConverterError: LocalizedError {
    case noConverterAvailable(pythonStderr: String?)
    case pythonFailed
    case javaFailed
    var errorDescription: String? {
        switch self {
        case .noConverterAvailable(let stderr):
            var msg = "Не удалось открыть MPP. Используется только Python из pyenv (например 3.11.8). Установите зависимости: pip install jpype1 mpxj. Запускайте приложение из Терминала (swift run MSProjectAnalog или open -a MSProjectAnalog), чтобы использовался ваш pyenv Python."
            if let s = stderr, !s.isEmpty { msg += "\n\nПоследняя ошибка: " + s }
            return msg
        case .pythonFailed: return "Конвертация MPP не удалась. Проверьте: python3 -c \"import mpxj\" (без ошибки). Установите: pip install jpype1 mpxj"
        case .javaFailed: return "Конвертация через Java MPXJ не удалась."
        }
    }
}
