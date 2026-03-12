import AppKit
import SwiftUI
import UniformTypeIdentifiers

enum ShareExportHelper {
    static func exportToXML(project: ProjectModel, window: NSWindow?) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.xml]
        panel.nameFieldStringValue = "Project.xml"
        panel.canCreateDirectories = true
        let handler: (NSApplication.ModalResponse) -> Void = { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                let data = try MSPDIWriter().write(project: project)
                try data.write(to: url)
            } catch {
                DispatchQueue.main.async {
                    let alert = NSAlert()
                    alert.messageText = L10n.exportFailed
                    alert.informativeText = error.localizedDescription
                    alert.alertStyle = .warning
                    alert.runModal()
                }
            }
        }
        if let window = window {
            panel.beginSheetModal(for: window, completionHandler: handler)
        } else {
            let response = panel.runModal()
            handler(response)
        }
    }

    static func shareXML(project: ProjectModel, window: NSWindow?) {
        do {
            let data = try MSPDIWriter().write(project: project)
            let tempDir = FileManager.default.temporaryDirectory
            let url = tempDir.appendingPathComponent("Project-\(UUID().uuidString).xml")
            try data.write(to: url)
            let picker = NSSharingServicePicker(items: [url])
            if let view = window?.contentView {
                picker.show(relativeTo: .zero, of: view, preferredEdge: .minY)
            }
        } catch {
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = L10n.shareFailed
                alert.informativeText = error.localizedDescription
                alert.alertStyle = .warning
                alert.runModal()
            }
        }
    }
}
