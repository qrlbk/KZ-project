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
            }
        }
    }
}

extension Notification.Name {
    static let exportXML = Notification.Name("exportXML")
}
