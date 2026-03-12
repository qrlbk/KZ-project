import SwiftUI

struct TaskTableView: View {
    @Binding var project: ProjectModel
    @State private var sortOrder: [KeyPathComparator<TaskModel>] = [.init(\.uid, order: .forward)]
    @State private var selection: Set<TaskModel.ID> = []

    private var selectedTaskIndex: Int? {
        guard let id = selection.first else { return nil }
        return project.tasks.firstIndex(where: { $0.uid == id })
    }

    var body: some View {
        HSplitView {
            VStack(spacing: 0) {
                PanelHeader(
                    title: "Задачи",
                    subtitle: "Список задач проекта. Выберите задачу для редактирования справа."
                ) {
                    Button(action: addTask) {
                        Label(L10n.addTask, systemImage: "plus")
                    }
                    .buttonStyle(PrimaryToolbarButtonStyle())
                    .keyboardShortcut("n", modifiers: [.command])

                    Button(action: deleteSelectedTasks) {
                        Label(L10n.delete, systemImage: "trash")
                    }
                    .buttonStyle(.bordered)
                    .disabled(selection.isEmpty)
                    .keyboardShortcut(.delete, modifiers: [])
                }

                Table(project.tasks, selection: $selection, sortOrder: $sortOrder) {
                    TableColumn(L10n.colId) { task in Text("\(task.uid)") }
                        .width(min: 44, max: 60)
                    TableColumn(L10n.colName) { task in
                        if let binding = binding(for: task.uid) {
                            AppKitTextField(
                                text: Binding(
                                    get: { binding.wrappedValue.name },
                                    set: { newValue in
                                        var t = binding.wrappedValue
                                        t.name = newValue
                                        binding.wrappedValue = t
                                    }
                                ),
                                placeholder: L10n.colName
                            )
                                .padding(.leading, CGFloat(task.outlineLevel) * 14)
                        } else {
                            Text(task.name.isEmpty ? "—" : task.name)
                                .padding(.leading, CGFloat(task.outlineLevel) * 14)
                        }
                    }
                    .width(min: 120)
                    TableColumn(L10n.colStart) { task in
                        if let binding = binding(for: task.uid) {
                            DatePicker(
                                "",
                                selection: Binding(get: { binding.wrappedValue.start ?? Date() }, set: { binding.wrappedValue.start = $0 }),
                                displayedComponents: .date
                            )
                            .labelsHidden()
                        } else {
                            Text(task.start.map { formatDate($0) } ?? L10n.noData)
                        }
                    }
                    .width(min: 90)
                    TableColumn(L10n.colFinish) { task in
                        if let binding = binding(for: task.uid) {
                            DatePicker(
                                "",
                                selection: Binding(get: { binding.wrappedValue.finish ?? (binding.wrappedValue.start ?? Date()) }, set: { binding.wrappedValue.finish = $0 }),
                                displayedComponents: .date
                            )
                            .labelsHidden()
                        } else {
                            Text(task.finish.map { formatDate($0) } ?? L10n.noData)
                        }
                    }
                    .width(min: 90)
                    TableColumn(L10n.colDuration) { task in
                        Text(formatDuration(task.duration))
                    }
                    .width(min: 70)
                    TableColumn(L10n.colPercentComplete) { task in
                        if let binding = binding(for: task.uid) {
                            Stepper("", value: binding.percentComplete, in: 0...100, step: 5)
                                .labelsHidden()
                        } else {
                            Text("\(task.percentComplete)%")
                        }
                    }
                        .width(min: 80)
                    TableColumn(L10n.colPredecessors) { task in
                        Text(task.predecessorLinks.map { String($0.predecessorUID) }.joined(separator: ", "))
                    }
                    .width(min: 100)
                }
                .onChange(of: sortOrder) { newOrder in
                    project.tasks.sort(using: newOrder)
                }
            }

            if let idx = selectedTaskIndex, idx >= 0 && idx < project.tasks.count {
                TaskInspectorView(task: $project.tasks[idx], project: project)
                    .frame(minWidth: 260, maxWidth: 340)
            } else {
                emptyInspectorView
                    .frame(minWidth: 260, maxWidth: 340)
            }
        }
    }

    private var emptyInspectorView: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            Text("Выберите задачу")
                .font(.headline)
            Text("в таблице слева, чтобы изменить её свойства")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func addTask() {
        let nextUID = (project.tasks.map(\.uid).max() ?? 0) + 1
        let newTask = TaskModel(uid: nextUID, name: L10n.newTask)
        project.tasks.append(newTask)
    }

    private func deleteSelectedTasks() {
        project.tasks.removeAll { selection.contains($0.uid) }
        selection.removeAll()
    }

    private func binding(for uid: Int) -> Binding<TaskModel>? {
        guard let idx = project.tasks.firstIndex(where: { $0.uid == uid }) else { return nil }
        return $project.tasks[idx]
    }

    private func formatDate(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .short
        f.locale = Locale(identifier: "ru_RU")
        return f.string(from: d)
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let h = Int(seconds) / 3600
        let m = (Int(seconds) % 3600) / 60
        if h >= 24 {
            let days = h / 24
            return "\(days) дн"
        }
        return String(format: "%d ч %d мин", h, m)
    }
}

// MARK: - Панель свойств задачи

struct TaskInspectorView: View {
    @Binding var task: TaskModel
    let project: ProjectModel

    private static func linkTypeName(_ type: Int) -> String {
        switch type {
        case 0: return L10n.linkTypeFF
        case 1: return L10n.linkTypeFS
        case 2: return L10n.linkTypeSF
        case 3: return L10n.linkTypeSS
        default: return "\(type)"
        }
    }

    private func taskName(uid: Int) -> String {
        project.tasks.first(where: { $0.uid == uid })?.name ?? "№\(uid)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.inspectorTask)
                .font(.headline)
                .padding(.bottom, 4)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        SectionHeaderText(L10n.name)
                        AppKitTextField(
                            text: Binding(
                                get: { task.name },
                                set: { newValue in
                                    var t = task
                                    t.name = newValue
                                    task = t
                                }
                            ),
                            placeholder: L10n.name
                        )
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        SectionHeaderText("Сроки")
                        DatePicker(L10n.start, selection: Binding(get: { task.start ?? Date() }, set: { task.start = $0 }), displayedComponents: .date)
                        DatePicker(L10n.finish, selection: Binding(get: { task.finish ?? Date() }, set: { task.finish = $0 }), displayedComponents: .date)
                        HStack {
                            Text(L10n.duration)
                            Spacer()
                            Text(durationString(task.duration))
                                .foregroundStyle(.secondary)
                        }
                        Stepper(value: Binding(
                            get: { Int(task.duration / 3600) },
                            set: { h in
                                task.duration = TimeInterval(h * 3600)
                                if task.start != nil, task.finish == nil {
                                    task.finish = task.start!.addingTimeInterval(task.duration)
                                } else if let start = task.start {
                                    task.finish = start.addingTimeInterval(task.duration)
                                }
                            }
                        ), in: 0...8760) {
                            Text("")
                        }
                        .labelsHidden()
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        SectionHeaderText(L10n.colPercentComplete)
                        HStack {
                            Text(L10n.completePercent(task.percentComplete))
                            Spacer()
                            Stepper("", value: $task.percentComplete, in: 0...100)
                                .labelsHidden()
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        SectionHeaderText(L10n.sectionPredecessors)
                        ForEach(Array(task.predecessorLinks.enumerated()), id: \.offset) { idx, link in
                            HStack {
                                Text(taskName(uid: link.predecessorUID))
                                    .lineLimit(1)
                                Spacer()
                                Text(TaskInspectorView.linkTypeName(link.type))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Button(L10n.delete, role: .destructive) {
                                    var t = task
                                    t.predecessorLinks.remove(at: idx)
                                    task = t
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                        AddPredecessorButton(task: $task, project: project)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        SectionHeaderText("Тип")
                        Picker(L10n.outlineLevel, selection: $task.outlineLevel) {
                            ForEach(0..<10, id: \.self) { i in
                                Text(L10n.level(i)).tag(i)
                            }
                        }
                        .pickerStyle(.menu)
                        Toggle(L10n.summary, isOn: $task.isSummary)
                        Toggle(L10n.milestone, isOn: $task.isMilestone)
                    }
                }
            }
        }
        .padding()
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func durationString(_ seconds: TimeInterval) -> String {
        let h = Int(seconds) / 3600
        if h >= 24 {
            return "\(h / 24) \(L10n.days)"
        }
        return "\(h) \(L10n.hours)"
    }
}

// Кнопка и выбор предшественника
private struct AddPredecessorButton: View {
    @Binding var task: TaskModel
    let project: ProjectModel
    @State private var selectedPredecessorUID: Int?
    @State private var selectedType: Int = 1

    var body: some View {
        HStack {
            Picker("", selection: $selectedPredecessorUID) {
                Text("— Выберите задачу —").tag(nil as Int?)
                ForEach(project.tasks.filter { $0.uid != task.uid }) { t in
                    Text("\(t.name.isEmpty ? "№\(t.uid)" : t.name)").tag(t.uid as Int?)
                }
            }
            .pickerStyle(.menu)
            Picker("", selection: $selectedType) {
                Text(L10n.linkTypeFS).tag(1)
                Text(L10n.linkTypeSS).tag(3)
                Text(L10n.linkTypeFF).tag(0)
                Text(L10n.linkTypeSF).tag(2)
            }
            .pickerStyle(.menu)
            Button(L10n.addPredecessor) {
                guard let uid = selectedPredecessorUID else { return }
                let link = PredecessorLink(predecessorUID: uid, type: selectedType, linkLag: 0, lagFormat: 7)
                task.predecessorLinks.append(link)
            }
            .disabled(selectedPredecessorUID == nil)
        }
    }
}
