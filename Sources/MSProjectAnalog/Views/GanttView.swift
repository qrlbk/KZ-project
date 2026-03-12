import SwiftUI

struct GanttView: View {
    let project: ProjectModel

    @State private var zoomLevel: Int = 1
    @State private var nameColumnWidth: CGFloat = 160
    @State private var dragStartNameWidth: CGFloat?

    private var dayWidth: CGFloat {
        switch zoomLevel {
        case 0: return 18
        case 2: return 36
        default: return 28
        }
    }

    private var dateRange: (start: Date, end: Date) {
        let starts = project.tasks.compactMap(\.start)
        let ends = project.tasks.compactMap(\.finish)
        let all = starts + ends

        let calendar = Calendar.current

        // Если задач нет — показываем месяц вперёд от стартовой даты проекта
        guard !all.isEmpty else {
            let d = project.startDate ?? Date()
            return (d, calendar.date(byAdding: .day, value: 30, to: d) ?? d)
        }

        let minD = all.min()!
        let maxD = all.max()!

        let rawDays = max(1, calendar.dateComponents([.day], from: minD, to: maxD).day ?? 1)
        // Добавляем «воздух» только справа, чтобы было куда «смотреть вперёд»
        let rightPaddingDays = max(10, rawDays / 5)

        let paddedEnd = calendar.date(byAdding: .day, value: rightPaddingDays, to: maxD) ?? maxD

        return (minD, paddedEnd)
    }

    var body: some View {
        VStack(spacing: 0) {
            PanelHeader(
                title: "Диаграмма Ганта",
                subtitle: "Полосы — длительность задач, оранжевые — вехи"
            ) {
                Picker("", selection: $zoomLevel) {
                    Text("Сжато").tag(0)
                    Text("Обычно").tag(1)
                    Text("Подробно").tag(2)
                }
                .pickerStyle(.segmented)
                .frame(width: 220)
            }

            if project.tasks.isEmpty {
                emptyGantt
            } else {
                ganttContent
            }
        }
        .frame(minWidth: 480, minHeight: 220)
    }

    private var emptyGantt: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            Text("Нет задач для отображения")
                .font(.headline)
            Text("Добавьте задачи на вкладке «Задачи» и укажите даты начала и окончания")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var ganttContent: some View {
        ScrollView([.horizontal, .vertical]) {
            let range = dateRange
            let days = max(1, Calendar.current.dateComponents([.day], from: range.start, to: range.end).day ?? 30)
            let rowHeight: CGFloat = 32
            let totalWidth = max(CGFloat(days) * dayWidth, 500)
            let totalHeight = CGFloat(project.tasks.count) * rowHeight
            let labelWidth = nameColumnWidth

            ZStack(alignment: .topLeading) {
                // Сетка по строкам
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(0..<project.tasks.count, id: \.self) { _ in
                        Rectangle()
                            .fill(Color.clear)
                            .frame(height: rowHeight)
                            .overlay(
                                Rectangle()
                                    .frame(height: 1)
                                    .foregroundStyle(.quaternary),
                                alignment: .bottom
                            )
                    }
                }
                .frame(width: totalWidth, height: totalHeight)

                // Заголовки дней
                HStack(spacing: 0) {
                    ForEach(0..<days, id: \.self) { d in
                        let date = Calendar.current.date(byAdding: .day, value: d, to: range.start)!
                        Text(dayLabel(date))
                            .font(.caption)
                            .fontWeight(.medium)
                            .frame(width: dayWidth, height: 24)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.leading, labelWidth + 10)

                // Линии зависимостей (под полосами)
                GanttDependencyLines(
                    project: project,
                    range: range,
                    days: days,
                    dayWidth: dayWidth,
                    rowHeight: rowHeight
                )
                .padding(.leading, labelWidth + 10)
                .padding(.top, 24)

                // Вертикальный разделитель между названиями задач и полосами (перетаскиваемый)
                Rectangle()
                    .fill(Color(nsColor: .separatorColor))
                    .frame(width: 1, height: totalHeight + 24)
                    .offset(x: labelWidth + 5, y: 24)

                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .frame(width: 10, height: totalHeight + 24)
                    .offset(x: labelWidth, y: 24)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                if dragStartNameWidth == nil {
                                    dragStartNameWidth = nameColumnWidth
                                }
                                let start = dragStartNameWidth ?? nameColumnWidth
                                let proposed = start + value.translation.width
                                nameColumnWidth = min(max(100, proposed), 320)
                            }
                            .onEnded { _ in
                                dragStartNameWidth = nil
                            }
                    )

                // Названия задач и полосы
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(project.tasks) { task in
                        HStack(spacing: 10) {
                            Text(task.name.isEmpty ? "—" : task.name)
                                .lineLimit(1)
                                .font(.subheadline)
                                .frame(width: labelWidth, alignment: .leading)
                            if let start = task.start, let finish = task.finish {
                                let s = Calendar.current.startOfDay(for: range.start)
                                let startOffset = Calendar.current.dateComponents([.day], from: s, to: start).day ?? 0
                                let durationDays = max(1, Calendar.current.dateComponents([.day], from: start, to: finish).day ?? 1)
                                Rectangle()
                                    .fill(task.isMilestone ? Color.orange : Color.accentColor)
                                    .frame(width: max(6, CGFloat(durationDays) * dayWidth), height: rowHeight - 6)
                                    .cornerRadius(3)
                                    .offset(x: CGFloat(startOffset) * dayWidth)
                            }
                        }
                        .frame(height: rowHeight)
                    }
                }
                .padding(.top, 24)
            }
        }
    }

    private func dayLabel(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "d"
        f.locale = Locale(identifier: "ru_RU")
        return f.string(from: d)
    }
}

// MARK: - Линии зависимостей на Ганте (FS: от конца предшественника к началу текущей)

private struct GanttDependencyLines: View {
    let project: ProjectModel
    let range: (start: Date, end: Date)
    let days: Int
    let dayWidth: CGFloat
    let rowHeight: CGFloat

    private var taskIndexByUID: [Int: Int] {
        Dictionary(uniqueKeysWithValues: project.tasks.enumerated().map { ($0.element.uid, $0.offset) })
    }

    var body: some View {
        Canvas { context, size in
            let s = Calendar.current.startOfDay(for: range.start)
            for (taskRow, task) in project.tasks.enumerated() {
                guard let taskStart = task.start else { continue }
                let currentStartDay = Calendar.current.dateComponents([.day], from: s, to: taskStart).day ?? 0
                let currentCenterX = CGFloat(currentStartDay) * dayWidth
                let currentCenterY = CGFloat(taskRow) * rowHeight + rowHeight / 2

                for link in task.predecessorLinks {
                    guard let predRow = taskIndexByUID[link.predecessorUID],
                          let predTask = project.tasks.first(where: { $0.uid == link.predecessorUID }),
                          let predFinish = predTask.finish else { continue }
                    let predEndDay = Calendar.current.dateComponents([.day], from: s, to: predFinish).day ?? 0
                    let predEndX = CGFloat(predEndDay) * dayWidth
                    let predCenterY = CGFloat(predRow) * rowHeight + rowHeight / 2

                    var path = Path()
                    let cornerOffset: CGFloat = 12
                    path.move(to: CGPoint(x: predEndX, y: predCenterY))
                    path.addLine(to: CGPoint(x: predEndX + cornerOffset, y: predCenterY))
                    path.addLine(to: CGPoint(x: predEndX + cornerOffset, y: currentCenterY))
                    path.addLine(to: CGPoint(x: currentCenterX, y: currentCenterY))
                    context.stroke(path, with: .color(.secondary.opacity(0.8)), lineWidth: 1.5)
                }
            }
        }
        .frame(width: CGFloat(days) * dayWidth, height: CGFloat(project.tasks.count) * rowHeight)
    }
}
