import SwiftUI

struct CalendarsView: View {
    @Binding var project: ProjectModel
    @State private var selection: Set<Int> = []

    private var selectedCalendarIndex: Int? {
        guard let id = selection.first else { return nil }
        return project.calendars.firstIndex(where: { $0.uid == id })
    }

    private static let dayNames = ["Вс", "Пн", "Вт", "Ср", "Чт", "Пт", "Сб"]

    var body: some View {
        HSplitView {
            VStack(spacing: 0) {
                HStack {
                    Text("Календари проекта: рабочие дни и исключения.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button(L10n.addCalendar, systemImage: "plus", action: addCalendar)
                        .buttonStyle(.borderedProminent)
                    Button(L10n.delete, systemImage: "trash", action: deleteSelected)
                        .buttonStyle(.bordered)
                        .disabled(selection.isEmpty)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(nsColor: .controlBackgroundColor))

                List(project.calendars, selection: $selection) { cal in
                    HStack {
                        Text(cal.name.isEmpty ? "Календарь \(cal.uid)" : cal.name)
                        Spacer()
                        Text("№\(cal.uid)")
                            .foregroundStyle(.secondary)
                    }
                }

                if !project.calendars.isEmpty {
                    HStack {
                        Text(L10n.projectCalendar)
                            .font(.caption)
                        Picker("", selection: Binding(
                            get: { project.calendarUID },
                            set: { project.calendarUID = $0 }
                        )) {
                            Text("—").tag(nil as Int?)
                            ForEach(project.calendars) { c in
                                Text(c.name.isEmpty ? "№\(c.uid)" : c.name).tag(c.uid as Int?)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    .padding(12)
                }
            }
            .frame(minWidth: 220)

            if let idx = selectedCalendarIndex, idx >= 0 && idx < project.calendars.count {
                CalendarInspectorView(calendar: $project.calendars[idx])
                    .frame(minWidth: 280, maxWidth: 380)
            } else {
                emptyInspector
                    .frame(minWidth: 280, maxWidth: 380)
            }
        }
        .frame(minWidth: 320)
    }

    private var emptyInspector: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            Text("Выберите календарь")
                .font(.headline)
            Text("или нажмите «Добавить календарь»")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func addCalendar() {
        let nextUID = (project.calendars.map(\.uid).max() ?? 0) + 1
        let weekDays: [CalendarWeekDay] = (0..<7).map { i in
            CalendarWeekDay(dayType: i, dayWorking: i >= 1 && i <= 5, timeFrom: 8 * 3600, timeTo: 17 * 3600)
        }
        project.calendars.append(CalendarModel(uid: nextUID, name: "Новый календарь", weekDays: weekDays, exceptions: []))
    }

    private func deleteSelected() {
        project.calendars.removeAll { selection.contains($0.uid) }
        if project.calendarUID != nil, !project.calendars.contains(where: { $0.uid == project.calendarUID }) {
            project.calendarUID = project.calendars.first?.uid
        }
        selection.removeAll()
    }
}

struct CalendarInspectorView: View {
    @Binding var calendar: CalendarModel

    private static let dayNames = ["Вс", "Пн", "Вт", "Ср", "Чт", "Пт", "Сб"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Календарь")
                    .font(.headline)
                    .padding(.bottom, 12)

                Form {
                    Section {
                        TextField(L10n.calendarName, text: $calendar.name)
                            .textFieldStyle(.roundedBorder)
                    } header: {
                        Text(L10n.name)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Section {
                        ForEach(0..<7, id: \.self) { i in
                            weekDayRow(dayType: i)
                        }
                    } header: {
                        Text(L10n.workDays)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Section {
                        ForEach(Array(calendar.exceptions.enumerated()), id: \.offset) { idx, ex in
                            HStack {
                                Text(formatDate(ex.date))
                                Spacer()
                                Button(L10n.delete, role: .destructive) {
                                    calendar.exceptions.remove(at: idx)
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                        AddExceptionButton(calendar: $calendar)
                    } header: {
                        Text(L10n.exceptions)
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

    private func weekDayRow(dayType: Int) -> some View {
        HStack {
            Text(CalendarInspectorView.dayNames[dayType])
                .frame(width: 28, alignment: .leading)
            Toggle("", isOn: Binding(
                get: { calendar.weekDays.first(where: { $0.dayType == dayType })?.dayWorking ?? (dayType >= 1 && dayType <= 5) },
                set: { newVal in
                    if let idx = calendar.weekDays.firstIndex(where: { $0.dayType == dayType }) {
                        var cal = calendar
                        cal.weekDays[idx].dayWorking = newVal
                        calendar = cal
                    } else {
                        var cal = calendar
                        cal.weekDays.append(CalendarWeekDay(dayType: dayType, dayWorking: newVal, timeFrom: 8 * 3600, timeTo: 17 * 3600))
                        calendar = cal
                    }
                }
            ))
            .labelsHidden()
        }
    }

    private func formatDate(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .short
        f.locale = Locale(identifier: "ru_RU")
        return f.string(from: d)
    }
}

private struct AddExceptionButton: View {
    @Binding var calendar: CalendarModel
    @State private var newDate = Date()

    var body: some View {
        HStack {
            DatePicker("", selection: $newDate, displayedComponents: .date)
                .labelsHidden()
            Button("Добавить") {
                calendar.exceptions.append(CalendarException(date: newDate, timeFrom: nil, timeTo: nil, enteredByOccurrences: false, occurrenceCount: nil))
            }
        }
    }
}
