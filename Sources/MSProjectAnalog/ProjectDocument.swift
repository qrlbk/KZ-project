import SwiftUI
import UniformTypeIdentifiers

private let mppType = UTType(filenameExtension: "mpp") ?? .data

final class ProjectDocument: ReferenceFileDocument, ObservableObject {
    /// XML (MSPDI), MPP и общий data — чтобы система передавала .mpp при открытии из Finder.
    static var readableContentTypes: [UTType] { [.xml, .data, mppType] }
    static var writableContentTypes: [UTType] { [.xml] }

    @Published var project: ProjectModel

    init(project: ProjectModel = ProjectModel()) {
        self.project = project
    }

    required init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        let dataToParse: Data
        let name = configuration.file.preferredFilename ?? ""
        let isMPP = configuration.contentType == mppType
            || name.lowercased().hasSuffix(".mpp")
            || !Self.looksLikeXML(data)
        if isMPP {
            dataToParse = try MPPConverter.convertToXML(mppData: data)
        } else {
            dataToParse = data
        }
        let reader = MSPDIReader()
        self.project = try reader.read(data: dataToParse)
    }

    /// MPP — бинарный формат; XML начинается с <?xml или \<.
    private static func looksLikeXML(_ data: Data) -> Bool {
        guard data.count >= 2 else { return false }
        let first = data.prefix(100)
        if let s = String(data: first, encoding: .utf8) ?? String(data: first, encoding: .ascii) {
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
            return t.hasPrefix("<?xml") || t.hasPrefix("<")
        }
        return false
    }

    func snapshot(contentType: UTType) throws -> ProjectModel {
        project
    }

    func fileWrapper(snapshot: ProjectModel, configuration: WriteConfiguration) throws -> FileWrapper {
        let data = try MSPDIWriter().write(project: snapshot)
        return FileWrapper(regularFileWithContents: data)
    }
}
