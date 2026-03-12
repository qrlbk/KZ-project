import SwiftUI

struct ResourcesView: View {
    @Binding var project: ProjectModel
    @State private var selection: Set<ResourceModel.ID> = []
    @State private var sortOrder: [KeyPathComparator<ResourceModel>] = [.init(\.uid, order: .forward)]

    private var selectedResourceIndex: Int? {
        guard let id = selection.first else { return nil }
        return project.resources.firstIndex(where: { $0.uid == id })
    }

    var body: some View {
        HSplitView {
            VStack(spacing: 0) {
                PanelHeader(
                    title: "Ресурсы",
                    subtitle: "Исполнители и материалы проекта. Выберите ресурс для редактирования справа."
                ) {
                    Button(action: addResource) {
                        Label(L10n.addResource, systemImage: "plus")
                    }
                    .buttonStyle(PrimaryToolbarButtonStyle())
                    .keyboardShortcut("r", modifiers: [.command])

                    Button(action: deleteSelected) {
                        Label(L10n.delete, systemImage: "trash")
                    }
                    .buttonStyle(.bordered)
                    .disabled(selection.isEmpty)
                    .keyboardShortcut(.delete, modifiers: [])
                }

                Table(project.resources, selection: $selection, sortOrder: $sortOrder) {
                    TableColumn(L10n.colId) { r in Text("\(r.uid)") }
                        .width(min: 44, max: 60)
                    TableColumn(L10n.colName, value: \.name)
                        .width(min: 120)
                    TableColumn(L10n.colType) { r in Text(r.type == 1 ? L10n.typeWork : L10n.typeMaterial) }
                        .width(min: 80)
                    TableColumn(L10n.colUnits) { r in Text(String(format: "%.1f", r.maxUnits)) }
                        .width(min: 70)
                    TableColumn(L10n.colStdRate) { r in Text(String(format: "%.2f", r.stdRate)) }
                        .width(min: 80)
                }
                .onChange(of: sortOrder) { newOrder in
                    project.resources.sort(using: newOrder)
                }
            }

            if let idx = selectedResourceIndex, idx >= 0 && idx < project.resources.count {
                ResourceInspectorView(resource: $project.resources[idx])
                    .frame(minWidth: 260, maxWidth: 340)
            } else {
                resourceEmptyInspector
                    .frame(minWidth: 260, maxWidth: 340)
            }
        }
        .frame(minWidth: 320)
    }

    private var resourceEmptyInspector: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.crop.circle.badge.plus")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            Text("Выберите ресурс")
                .font(.headline)
            Text("в таблице слева или нажмите «Добавить ресурс»")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func addResource() {
        let nextUID = (project.resources.map(\.uid).max() ?? 0) + 1
        project.resources.append(ResourceModel(uid: nextUID, name: L10n.newResource))
    }

    private func deleteSelected() {
        project.resources.removeAll { selection.contains($0.uid) }
        selection.removeAll()
    }
}

struct ResourceInspectorView: View {
    @Binding var resource: ResourceModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(L10n.inspectorResource)
                    .font(.headline)
                    .padding(.bottom, 12)

                Form {
                    Section {
                        TextField(L10n.name, text: $resource.name)
                            .textFieldStyle(.roundedBorder)
                    } header: {
                        SectionHeaderText(L10n.name)
                    }

                    Section {
                        Picker(L10n.colType, selection: $resource.type) {
                            Text(L10n.typeWork).tag(1)
                            Text(L10n.typeMaterial).tag(2)
                        }
                        .pickerStyle(.menu)
                        TextField(L10n.maxUnits, value: $resource.maxUnits, format: .number)
                            .textFieldStyle(.roundedBorder)
                        TextField(L10n.stdRate, value: $resource.stdRate, format: .number)
                            .textFieldStyle(.roundedBorder)
                        TextField(L10n.overtimeRate, value: $resource.overtimeRate, format: .number)
                            .textFieldStyle(.roundedBorder)
                    } header: {
                        SectionHeaderText("Параметры")
                    }
                }
                .formStyle(.grouped)
            }
            .padding()
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
