import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ContentView: View {
    @ObservedObject var document: ProjectDocument
    let fileURL: URL?

    @State private var selectedTab = 0
    @State private var showProjectProperties = false
    @State private var openError: String?

    var body: some View {
        VStack(spacing: 0) {
            // Заголовок окна: имя проекта или «Проект»
            headerView

            TabView(selection: $selectedTab) {
                taskTable
                    .tabItem { Label(L10n.tabTasks, systemImage: "list.bullet") }
                    .tag(0)
                GanttView(project: document.project)
                    .tabItem { Label(L10n.tabGantt, systemImage: "chart.bar") }
                    .tag(1)
                ResourcesView(project: Binding(get: { document.project }, set: { document.project = $0 }))
                    .tabItem { Label(L10n.tabResources, systemImage: "person.2") }
                    .tag(2)
                AssignmentsView(project: Binding(get: { document.project }, set: { document.project = $0 }))
                    .tabItem { Label(L10n.tabAssignments, systemImage: "link") }
                    .tag(3)
                CalendarsView(project: Binding(get: { document.project }, set: { document.project = $0 }))
                    .tabItem { Label(L10n.tabCalendars, systemImage: "calendar") }
                    .tag(4)
            }
            .tabViewStyle(.automatic)
        }
        .frame(minWidth: 720, minHeight: 480)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: openFile) {
                    Label(L10n.openFile, systemImage: "folder.badge.plus")
                }
                .help("Открыть проект (.xml или .mpp)")
            }
            ToolbarItem(placement: .primaryAction) {
                Button(action: { ShareExportHelper.exportToXML(project: document.project, window: NSApp.keyWindow) }) {
                    Label(L10n.exportXML, systemImage: "square.and.arrow.down")
                }
                .help(L10n.exportXML)
            }
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button(action: {
                        ShareExportHelper.exportGanttToPDF(project: document.project, window: NSApp.keyWindow)
                    }) {
                        Text(L10n.exportGanttPDF)
                    }
                    Button(action: {
                        ShareExportHelper.exportGanttToPNG(project: document.project, window: NSApp.keyWindow)
                    }) {
                        Text(L10n.exportGanttPNG)
                    }
                    Button(action: {
                        ShareExportHelper.exportGanttToJPEG(project: document.project, window: NSApp.keyWindow)
                    }) {
                        Text(L10n.exportGanttJPEG)
                    }
                } label: {
                    Label("Экспорт диаграммы", systemImage: "chart.bar.doc.horizontal")
                }
                .help("Экспорт диаграммы Ганта в PDF/PNG/JPEG")
            }
            ToolbarItem(placement: .primaryAction) {
                Button(action: { ShareExportHelper.shareXML(project: document.project, window: NSApp.keyWindow) }) {
                    Label(L10n.share, systemImage: "square.and.arrow.up")
                }
                .help(L10n.share)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .exportXML)) { _ in
            ShareExportHelper.exportToXML(project: document.project, window: NSApp.keyWindow)
        }
        .onReceive(NotificationCenter.default.publisher(for: .exportGanttPDF)) { _ in
            ShareExportHelper.exportGanttToPDF(project: document.project, window: NSApp.keyWindow)
        }
        .onReceive(NotificationCenter.default.publisher(for: .exportGanttPNG)) { _ in
            ShareExportHelper.exportGanttToPNG(project: document.project, window: NSApp.keyWindow)
        }
        .onReceive(NotificationCenter.default.publisher(for: .exportGanttJPEG)) { _ in
            ShareExportHelper.exportGanttToJPEG(project: document.project, window: NSApp.keyWindow)
        }
        .alert("Ошибка открытия файла", isPresented: Binding(get: { openError != nil }, set: { if !$0 { openError = nil } })) {
            Button("OK", role: .cancel) { openError = nil }
        } message: {
            Text(openError ?? "")
        }
    }

    private var headerView: some View {
        HStack {
            Text(projectTitle)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
            Spacer()
            Button(L10n.projectProperties) {
                showProjectProperties = true
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(isPresented: $showProjectProperties) {
            ProjectPropertiesView(project: Binding(get: { document.project }, set: { document.project = $0 }))
        }
    }

    private func openFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.xml, UTType(filenameExtension: "mpp") ?? .data]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.message = "Выберите файл проекта (.xml или .mpp)"
        panel.runModal()
        guard let url = panel.url else { return }
        do {
            var data = try Data(contentsOf: url)
            if url.pathExtension.lowercased() == "mpp" {
                data = try MPPConverter.convertToXML(mppData: data)
            }
            let reader = MSPDIReader()
            let project = try reader.read(data: data)
            document.project = project
        } catch {
            openError = error.localizedDescription
        }
    }

    private var projectTitle: String {
        let name = document.project.name
        let title = document.project.title
        if !name.isEmpty { return name }
        if !title.isEmpty { return title }
        return "Проект"
    }

    private var taskTable: some View {
        TaskTableView(project: Binding(get: { document.project }, set: { document.project = $0 }))
    }
}
