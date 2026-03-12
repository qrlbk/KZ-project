import SwiftUI

struct AssignmentsView: View {
    @Binding var project: ProjectModel
    @State private var selection: Set<Int> = []
    @State private var sortOrder: [KeyPathComparator<AssignmentModel>] = [.init(\.uid, order: .forward)]

    private var selectedAssignmentIndex: Int? {
        guard let id = selection.first else { return nil }
        return project.assignments.firstIndex(where: { $0.uid == id })
    }

    var body: some View {
        HSplitView {
            VStack(spacing: 0) {
                HStack {
                    Text("Назначения ресурсов на задачи. Выберите назначение для редактирования справа.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button(action: addAssignment) {
                        Label(L10n.addAssignment, systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                    Button(action: deleteSelected) {
                        Label(L10n.delete, systemImage: "trash")
                    }
                    .buttonStyle(.bordered)
                    .disabled(selection.isEmpty)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(nsColor: .controlBackgroundColor))

                Table(project.assignments, selection: $selection, sortOrder: $sortOrder) {
                    TableColumn(L10n.colId) { a in Text("\(a.uid)") }
                        .width(min: 44, max: 60)
                    TableColumn(L10n.colTask) { a in
                        Text(taskName(uid: a.taskUID))
                    }
                    .width(min: 120)
                    TableColumn(L10n.colResource) { a in
                        Text(resourceName(uid: a.resourceUID))
                    }
                    .width(min: 120)
                    TableColumn(L10n.colUnits) { a in Text(String(format: "%.0f%%", a.units * 100)) }
                        .width(min: 60)
                    TableColumn(L10n.colWork) { a in Text(formatWork(a.work)) }
                        .width(min: 80)
                }
                .onChange(of: sortOrder) { newOrder in
                    project.assignments.sort(using: newOrder)
                }
            }

            if let idx = selectedAssignmentIndex, idx >= 0 && idx < project.assignments.count {
                AssignmentInspectorView(assignment: $project.assignments[idx], project: project)
                    .frame(minWidth: 260, maxWidth: 340)
            } else {
                emptyInspector
                    .frame(minWidth: 260, maxWidth: 340)
            }
        }
        .frame(minWidth: 320)
    }

    private var emptyInspector: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.badge.plus")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            Text("Выберите назначение")
                .font(.headline)
            Text("или нажмите «Добавить назначение»")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func taskName(uid: Int) -> String {
        project.tasks.first(where: { $0.uid == uid })?.name ?? "№\(uid)"
    }

    private func resourceName(uid: Int) -> String {
        project.resources.first(where: { $0.uid == uid })?.name ?? "№\(uid)"
    }

    private func formatWork(_ seconds: TimeInterval) -> String {
        let h = Int(seconds) / 3600
        if h >= 24 {
            return "\(h / 24) дн"
        }
        return "\(h) ч"
    }

    private func addAssignment() {
        let nextUID = (project.assignments.map(\.uid).max() ?? 0) + 1
        let taskUID = project.tasks.first?.uid ?? 0
        let resourceUID = project.resources.first?.uid ?? 0
        project.assignments.append(AssignmentModel(uid: nextUID, taskUID: taskUID, resourceUID: resourceUID, units: 1, work: 0))
    }

    private func deleteSelected() {
        project.assignments.removeAll { selection.contains($0.uid) }
        selection.removeAll()
    }
}

struct AssignmentInspectorView: View {
    @Binding var assignment: AssignmentModel
    let project: ProjectModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Назначение")
                    .font(.headline)
                    .padding(.bottom, 12)

                Form {
                    Section {
                        Picker(L10n.colTask, selection: Binding(
                            get: { assignment.taskUID },
                            set: { assignment.taskUID = $0 }
                        )) {
                            ForEach(project.tasks) { t in
                                Text(t.name.isEmpty ? "№\(t.uid)" : t.name).tag(t.uid)
                            }
                        }
                        .pickerStyle(.menu)
                        Picker(L10n.colResource, selection: Binding(
                            get: { assignment.resourceUID },
                            set: { assignment.resourceUID = $0 }
                        )) {
                            ForEach(project.resources) { r in
                                Text(r.name.isEmpty ? "№\(r.uid)" : r.name).tag(r.uid)
                            }
                        }
                        .pickerStyle(.menu)
                        TextField(L10n.colUnits, value: Binding(
                            get: { assignment.units },
                            set: { assignment.units = $0 }
                        ), format: .percent)
                        .textFieldStyle(.roundedBorder)
                        TextField(L10n.colWork, value: Binding(
                            get: { assignment.work / 3600 },
                            set: { assignment.work = TimeInterval($0) * 3600 }
                        ), format: .number)
                        .textFieldStyle(.roundedBorder)
                    } header: {
                        Text("Параметры")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .formStyle(.grouped)
            }
            .padding()
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
