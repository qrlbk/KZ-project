import SwiftUI

@main
struct MSProjectAnalogApp: App {
    var body: some Scene {
        DocumentGroup(newDocument: { ProjectDocument() }) { config in
            ContentView(document: config.document, fileURL: config.fileURL)
        }
        .commands {
            CommandGroup(after: .saveItem) {
                Button(L10n.menuExportXML) {
                    NotificationCenter.default.post(name: .exportXML, object: nil)
                }
                .keyboardShortcut("e", modifiers: [.command])

                Divider()

                Button(L10n.menuExportGanttPDF) {
                    NotificationCenter.default.post(name: .exportGanttPDF, object: nil)
                }
                Button(L10n.menuExportGanttPNG) {
                    NotificationCenter.default.post(name: .exportGanttPNG, object: nil)
                }
                Button(L10n.menuExportGanttJPEG) {
                    NotificationCenter.default.post(name: .exportGanttJPEG, object: nil)
                }
            }
        }
    }
}

extension Notification.Name {
    static let exportXML = Notification.Name("exportXML")
    static let exportGanttPDF = Notification.Name("exportGanttPDF")
    static let exportGanttPNG = Notification.Name("exportGanttPNG")
    static let exportGanttJPEG = Notification.Name("exportGanttJPEG")
}
