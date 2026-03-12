import SwiftUI

struct ProjectPropertiesView: View {
    @Binding var project: ProjectModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(L10n.projectProperties)
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Button("Готово") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()

            Form {
                Section {
                    TextField(L10n.projectName, text: $project.name)
                        .textFieldStyle(.roundedBorder)
                    TextField(L10n.projectTitle, text: $project.title)
                        .textFieldStyle(.roundedBorder)
                } header: {
                    Text("Основное")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section {
                    DatePicker(L10n.start, selection: Binding(get: { project.startDate ?? Date() }, set: { project.startDate = $0 }), displayedComponents: .date)
                    DatePicker(L10n.finish, selection: Binding(get: { project.finishDate ?? Date() }, set: { project.finishDate = $0 }), displayedComponents: .date)
                } header: {
                    Text("Сроки проекта")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section {
                    Picker(L10n.defaultCalendar, selection: $project.calendarUID) {
                        Text("—").tag(nil as Int?)
                        ForEach(project.calendars) { c in
                            Text(c.name.isEmpty ? "№\(c.uid)" : c.name).tag(c.uid as Int?)
                        }
                    }
                    .pickerStyle(.menu)
                } header: {
                    Text(L10n.tabCalendars)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
        }
        .frame(minWidth: 360, minHeight: 320)
    }
}
