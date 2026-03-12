import SwiftUI

struct GanttView: View {
    let project: ProjectModel

    private var dateRange: (start: Date, end: Date) {
        let starts = project.tasks.compactMap(\.start)
        let ends = project.tasks.compactMap(\.finish)
        let all = starts + ends
        guard !all.isEmpty else {
            let d = project.startDate ?? Date()
            return (d, Calendar.current.date(byAdding: .day, value: 30, to: d) ?? d)
        }
        let minD = all.min()!
        let maxD = all.max()!
        return (minD, maxD)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Временная шкала задач. Полосы — длительность, оранжевые — вехи.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(nsColor: .controlBackgroundColor))

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
            let dayWidth: CGFloat = 28
            let rowHeight: CGFloat = 32
            let totalWidth = max(CGFloat(days) * dayWidth, 500)
            let totalHeight = CGFloat(project.tasks.count) * rowHeight

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
                .padding(.leading, 160)

                // Линии зависимостей (под полосами)
                GanttDependencyLines(
                    project: project,
                    range: range,
                    days: days,
                    dayWidth: dayWidth,
                    rowHeight: rowHeight
                )
                .padding(.leading, 160)
                .padding(.top, 24)

                // Названия задач и полосы
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(project.tasks) { task in
                        HStack(spacing: 10) {
                            Text(task.name.isEmpty ? "—" : task.name)
                                .lineLimit(1)
                                .font(.subheadline)
                                .frame(width: 150, alignment: .leading)
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
