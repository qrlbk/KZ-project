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

    static func exportGanttToPDF(project: ProjectModel, window: NSWindow?) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = "Gantt.pdf"
        panel.canCreateDirectories = true

        let handler: (NSApplication.ModalResponse) -> Void = { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                let data = try renderGanttAsPDF(project: project)
                try data.write(to: url)
            } catch {
                showExportError(message: error.localizedDescription)
            }
        }

        if let window = window {
            panel.beginSheetModal(for: window, completionHandler: handler)
        } else {
            let response = panel.runModal()
            handler(response)
        }
    }

    static func exportGanttToPNG(project: ProjectModel, window: NSWindow?) {
        exportGanttAsImage(project: project, window: window, fileType: .png, contentType: UTType.png, defaultName: "Gantt.png")
    }

    static func exportGanttToJPEG(project: ProjectModel, window: NSWindow?) {
        exportGanttAsImage(project: project, window: window, fileType: .jpeg, contentType: UTType.jpeg, defaultName: "Gantt.jpg")
    }

    // MARK: - Private helpers (Gantt)

    private static func exportGanttAsImage(project: ProjectModel,
                                           window: NSWindow?,
                                           fileType: NSBitmapImageRep.FileType,
                                           contentType: UTType,
                                           defaultName: String) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [contentType]
        panel.nameFieldStringValue = defaultName
        panel.canCreateDirectories = true

        let handler: (NSApplication.ModalResponse) -> Void = { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                let data = try renderGanttAsImage(project: project, fileType: fileType)
                try data.write(to: url)
            } catch {
                showExportError(message: error.localizedDescription)
            }
        }

        if let window = window {
            panel.beginSheetModal(for: window, completionHandler: handler)
        } else {
            let response = panel.runModal()
            handler(response)
        }
    }

    private static func renderGanttSize(for project: ProjectModel) -> CGSize {
        let tasks = project.tasks
        let rowHeight: CGFloat = 32
        let minHeight: CGFloat = 300

        let starts = tasks.compactMap(\.start)
        let ends = tasks.compactMap(\.finish)
        let all = starts + ends

        let baseStart = all.min() ?? (project.startDate ?? Date())
        let baseEnd = all.max() ?? Calendar.current.date(byAdding: .day, value: 30, to: baseStart) ?? baseStart
        let days = max(1, Calendar.current.dateComponents([.day], from: baseStart, to: baseEnd).day ?? 30)

        let dayWidth: CGFloat = 28
        let labelWidth: CGFloat = 180
        let headerHeight: CGFloat = 40

        let width = max(labelWidth + CGFloat(days) * dayWidth, 600)
        let height = max(CGFloat(tasks.count) * rowHeight + headerHeight, minHeight)
        return CGSize(width: width, height: height)
    }

    private static func makeGanttHostingView(project: ProjectModel, size: CGSize) -> NSView {
        let hosting = NSHostingView(rootView: GanttView(project: project))
        hosting.frame = CGRect(origin: .zero, size: size)
        hosting.layoutSubtreeIfNeeded()
        return hosting
    }

    private static func renderGanttAsPDF(project: ProjectModel) throws -> Data {
        let size = renderGanttSize(for: project)
        let view = makeGanttHostingView(project: project, size: size)
        let data = view.dataWithPDF(inside: view.bounds)
        return data
    }

    private static func renderGanttAsImage(project: ProjectModel,
                                           fileType: NSBitmapImageRep.FileType) throws -> Data {
        let size = renderGanttSize(for: project)
        let view = makeGanttHostingView(project: project, size: size)

        guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) ?? NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(size.width),
            pixelsHigh: Int(size.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            throw NSError(domain: "MSProjectAnalog", code: 1, userInfo: [NSLocalizedDescriptionKey: "Не удалось подготовить буфер изображения"])
        }

        view.cacheDisplay(in: view.bounds, to: rep)
        guard let data = rep.representation(using: fileType, properties: [:]) else {
            throw NSError(domain: "MSProjectAnalog", code: 2, userInfo: [NSLocalizedDescriptionKey: "Не удалось сохранить изображение"])
        }
        return data
    }

    private static func showExportError(message: String) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = L10n.exportGanttFailed
            alert.informativeText = message
            alert.alertStyle = .warning
            alert.runModal()
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
