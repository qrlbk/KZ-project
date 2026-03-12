import Foundation

/// Reads Microsoft Project Data Interchange (MSPDI) XML format.
final class MSPDIReader {
    private let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private let iso8601NoFraction: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    func read(data: Data) throws -> ProjectModel {
        let parser = XMLParser(data: data)
        let delegate = MSPDIParserDelegate()
        parser.delegate = delegate
        if !parser.parse() {
            throw delegate.lastError ?? NSError(domain: "MSPDIReader", code: -1, userInfo: [NSLocalizedDescriptionKey: "XML parse failed"])
        }
        var project = try delegate.buildProject(reader: self)
        project = normalizeDates(project)
        return project
    }

    func read(url: URL) throws -> ProjectModel {
        var data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw error
        }
        if data.count >= 3, data[0] == 0xEF, data[1] == 0xBB, data[2] == 0xBF {
            data = data.dropFirst(3)
        }
        return try read(data: data)
    }

    func parseDate(_ s: String?) -> Date? {
        guard let s = s, !s.isEmpty else { return nil }
        if let d = iso8601.date(from: s) ?? iso8601NoFraction.date(from: s) {
            return d
        }
        // MPXJ/MSPDI иногда пишет без таймзоны: "yyyy-MM-dd'T'HH:mm:ss" или с миллисекундами.
        let candidates = [
            "yyyy-MM-dd'T'HH:mm:ss.SSS",
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd",
        ]
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone(secondsFromGMT: 0)
        for fmt in candidates {
            df.dateFormat = fmt
            if let d = df.date(from: s) { return d }
        }
        return nil
    }

    /// Parses MS Project duration (e.g. PT8H0M0S, PT1D, or minutes as integer).
    func parseDuration(_ s: String?) -> TimeInterval {
        guard let s = s, !s.isEmpty else { return 0 }
        if let minutes = Int(s) {
            return TimeInterval(minutes) * 60
        }
        var total: TimeInterval = 0
        var num = ""
        var unit: Character?
        for c in s.uppercased() {
            if c.isNumber || c == "." || c == "-" {
                if let u = unit {
                    total += durationComponent(num, unit: u)
                    unit = nil
                }
                num.append(c)
            } else if c == "D" || c == "H" || c == "M" || c == "S" || c == "W" {
                unit = c
            } else {
                num = ""
            }
        }
        if let u = unit, !num.isEmpty {
            total += durationComponent(num, unit: u)
        }
        return total
    }

    private func durationComponent(_ num: String, unit: Character) -> TimeInterval {
        let v = Double(num) ?? 0
        switch unit {
        case "D": return v * 24 * 3600
        case "H": return v * 3600
        case "M": return v * 60
        case "S": return v
        case "W": return v * 7 * 24 * 3600
        default: return 0
        }
    }

    func parseInt(_ s: String?) -> Int? {
        guard let s = s, !s.isEmpty else { return nil }
        return Int(s)
    }

    func parseDouble(_ s: String?) -> Double? {
        guard let s = s, !s.isEmpty else { return nil }
        return Double(s)
    }

    func parseBool(_ s: String?) -> Bool {
        guard let s = s else { return false }
        return s.lowercased() == "1" || s.lowercased() == "true" || s == "1"
    }

    /// Некоторые источники (в т.ч. конвертация из MPP) могут не заполнять Finish для задач.
    /// Для отображения диаграммы Ганта вычисляем Finish = Start + Duration, если возможно.
    private func normalizeDates(_ project: ProjectModel) -> ProjectModel {
        var p = project
        p.tasks = p.tasks.map { t in
            var tt = t
            if tt.finish == nil, let s = tt.start, tt.duration > 0 {
                tt.finish = s.addingTimeInterval(tt.duration)
            }
            // Milestone: часто duration=0 и finish отсутствует — ставим finish=start
            if tt.finish == nil, let s = tt.start, tt.isMilestone {
                tt.finish = s
            }
            return tt
        }
        return p
    }
}

// MARK: - Parser Delegate

private final class MSPDIParserDelegate: NSObject, XMLParserDelegate {
    private var stack: [String] = []
    private var currentText = ""
    private var project = ProjectBuilder()
    private var taskBuilder: TaskBuilder?
    private var resourceBuilder: ResourceBuilder?
    private var assignmentBuilder: AssignmentBuilder?
    private var calendarBuilder: CalendarBuilder?
    private var predecessorBuilder: PredecessorBuilder?
    private var weekDayBuilder: WeekDayBuilder?
    private var exceptionBuilder: ExceptionBuilder?

    var lastError: Error?

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        let name = (qName ?? elementName).split(separator: ":").last.map(String.init) ?? elementName
        currentText = ""
        stack.append(name)

        switch name {
        case "Task":
            taskBuilder = TaskBuilder()
        case "Resource":
            resourceBuilder = ResourceBuilder()
        case "Assignment":
            assignmentBuilder = AssignmentBuilder()
        case "Calendar":
            calendarBuilder = CalendarBuilder()
        case "PredecessorLink":
            predecessorBuilder = PredecessorBuilder()
        case "WeekDay":
            weekDayBuilder = WeekDayBuilder()
            if let dt = attributeDict["DayType"] ?? attributeDict.first(where: { $0.key.hasSuffix("DayType") })?.value {
                weekDayBuilder?.dayType = Int(dt) ?? 0
            }
            if let dw = attributeDict["DayWorking"] ?? attributeDict.first(where: { $0.key.hasSuffix("DayWorking") })?.value {
                weekDayBuilder?.dayWorking = dw == "1" || dw.lowercased() == "true"
            }
        case "TimePeriod", "Exception":
            exceptionBuilder = ExceptionBuilder()
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let name = (qName ?? elementName).split(separator: ":").last.map(String.init) ?? elementName
        let text = currentText.trimmingCharacters(in: .whitespacesAndNewlines)

        if var pd = predecessorBuilder {
            switch name {
            case "PredecessorUID": pd.predecessorUID = Int(text) ?? 0
            case "Type": pd.type = Int(text) ?? 1
            case "LinkLag": pd.linkLag = Int(text) ?? 0
            case "LagFormat": pd.lagFormat = Int(text) ?? 7
            case "PredecessorLink":
                if var t = taskBuilder {
                    t.predecessorLinks.append(pd)
                    taskBuilder = t
                }
                predecessorBuilder = nil
            default: break
            }
            if predecessorBuilder != nil { predecessorBuilder = pd }
        } else if var t = taskBuilder {
            switch name {
            case "UID": t.uid = Int(text) ?? 0
            case "ID": break
            case "Name": t.name = text
            case "Start": t.start = text
            case "Finish": t.finish = text
            case "Duration": t.duration = text
            case "DurationFormat": t.durationFormat = Int(text) ?? 7
            case "PercentComplete": t.percentComplete = Int(text) ?? 0
            case "OutlineLevel": t.outlineLevel = Int(text) ?? 0
            case "OutlineNumber": t.outlineNumber = text.isEmpty ? nil : text
            case "Priority": t.priority = Int(text) ?? 500
            case "CalendarUID": t.calendarUID = Int(text)
            case "Summary": t.isSummary = text == "1" || text.lowercased() == "true"
            case "Milestone": t.isMilestone = text == "1" || text.lowercased() == "true"
            case "WBS": t.wbs = text.isEmpty ? nil : text
            case "ConstraintType": t.constraintType = Int(text)
            case "ConstraintDate": t.constraintDate = text.isEmpty ? nil : text
            case "Task":
                project.tasks.append(t)
                taskBuilder = nil
            default: break
            }
            if taskBuilder != nil { taskBuilder = t }
        } else if var r = resourceBuilder {
            switch name {
            case "UID": r.uid = Int(text) ?? 0
            case "Name": r.name = text
            case "Type": r.type = Int(text) ?? 1
            case "MaxUnits": r.maxUnits = Double(text) ?? 1
            case "StdRate": r.stdRate = parseRate(text)
            case "OvertimeRate": r.overtimeRate = parseRate(text)
            case "Resource":
                project.resources.append(r)
                resourceBuilder = nil
            default: break
            }
            if resourceBuilder != nil { resourceBuilder = r }
        } else if var a = assignmentBuilder {
            switch name {
            case "UID": a.uid = Int(text) ?? 0
            case "TaskUID": a.taskUID = Int(text) ?? 0
            case "ResourceUID": a.resourceUID = Int(text) ?? 0
            case "Units": a.units = Double(text) ?? 1
            case "Work": a.work = text
            case "Start": a.start = text
            case "Finish": a.finish = text
            case "Assignment":
                project.assignments.append(a)
                assignmentBuilder = nil
            default: break
            }
            if assignmentBuilder != nil { assignmentBuilder = a }
        } else if var c = calendarBuilder {
            switch name {
            case "UID": c.uid = Int(text) ?? 0
            case "Name": c.name = text
            case "Calendar":
                project.calendars.append(c)
                calendarBuilder = nil
            default: break
            }
            if calendarBuilder != nil { calendarBuilder = c }
        } else if name == "WeekDay", let wd = weekDayBuilder {
            if var cal = calendarBuilder {
                cal.weekDays.append(WeekDayRecord(dayType: wd.dayType, dayWorking: wd.dayWorking, timeFrom: wd.timeFrom, timeTo: wd.timeTo))
                calendarBuilder = cal
            }
            weekDayBuilder = nil
        } else if name == "TimeFrom", var wd = weekDayBuilder {
            wd.timeFrom = parseTimeToSeconds(text)
            weekDayBuilder = wd
        } else if name == "TimeTo", var wd = weekDayBuilder {
            wd.timeTo = parseTimeToSeconds(text)
            weekDayBuilder = wd
        } else if name == "StartDate", var ex = exceptionBuilder {
            ex.startDate = text
            exceptionBuilder = ex
        } else if name == "EndDate", var ex = exceptionBuilder {
            ex.endDate = text
            exceptionBuilder = ex
        } else if (name == "Exception" || name == "TimePeriod"), let ex = exceptionBuilder, let start = ex.startDate, var cal = calendarBuilder, let startDate = parseDateISO(start) {
            cal.exceptions.append(CalendarExceptionRecord(date: startDate))
            calendarBuilder = cal
            exceptionBuilder = nil
        } else {
            project.setValue(name, text: text)
        }

        _ = stack.popLast()
        currentText = ""
    }

    private func parseRate(_ s: String) -> Double {
        guard !s.isEmpty else { return 0 }
        if let d = Double(s) { return d }
        var num = ""
        for c in s where c.isNumber || c == "." { num.append(c) }
        return Double(num) ?? 0
    }

    private func parseDateISO(_ s: String) -> Date? {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.date(from: s) ?? ISO8601DateFormatter().date(from: s)
    }

    private func parseTimeToSeconds(_ s: String) -> TimeInterval? {
        guard !s.isEmpty else { return nil }
        if let m = Int(s) { return TimeInterval(m) * 60 }
        var total: TimeInterval = 0
        var num = ""
        var unit: Character?
        for c in s.uppercased() {
            if c.isNumber || c == "." || c == "-" {
                if let u = unit {
                    total += durationPart(num, unit: u)
                    unit = nil
                }
                num.append(c)
            } else if c == "D" || c == "H" || c == "M" || c == "S" || c == "W" {
                unit = c
            } else {
                num = ""
            }
        }
        if let u = unit, !num.isEmpty { total += durationPart(num, unit: u) }
        return total
    }

    private func durationPart(_ num: String, unit: Character) -> TimeInterval {
        let v = Double(num) ?? 0
        switch unit {
        case "D": return v * 24 * 3600
        case "H": return v * 3600
        case "M": return v * 60
        case "S": return v
        case "W": return v * 7 * 24 * 3600
        default: return 0
        }
    }

    func buildProject(reader: MSPDIReader) throws -> ProjectModel {
        let proj = project.build(reader: reader)
        return proj
    }
}

// MARK: - Builders (data collectors)

private struct ProjectBuilder {
    var saveVersion: Int = 12
    var uid: String = ""
    var name: String = ""
    var title: String = ""
    var startDate: String = ""
    var finishDate: String = ""
    var calendarUID: String = ""
    var minutesPerDay: String = "480"
    var minutesPerWeek: String = "2400"
    var defaultStartTime: String = ""
    var defaultFinishTime: String = ""
    var scheduleFromStart: String = "1"
    var currentDate: String = ""
    var creationDate: String = ""
    var lastSaved: String = ""
    var tasks: [TaskBuilder] = []
    var resources: [ResourceBuilder] = []
    var assignments: [AssignmentBuilder] = []
    var calendars: [CalendarBuilder] = []

    mutating func setValue(_ elementName: String, text: String) {
        switch elementName {
        case "SaveVersion": saveVersion = Int(text) ?? 12
        case "UID": uid = text
        case "Name": name = text
        case "Title": title = text
        case "StartDate": startDate = text
        case "FinishDate": finishDate = text
        case "CalendarUID": calendarUID = text
        case "MinutesPerDay": minutesPerDay = text.isEmpty ? "480" : text
        case "MinutesPerWeek": minutesPerWeek = text.isEmpty ? "2400" : text
        case "DefaultStartTime": defaultStartTime = text
        case "DefaultFinishTime": defaultFinishTime = text
        case "ScheduleFromStart": scheduleFromStart = text
        case "CurrentDate": currentDate = text
        case "CreationDate": creationDate = text
        case "LastSaved": lastSaved = text
        default: break
        }
    }

    func build(reader: MSPDIReader) -> ProjectModel {
        func timeFromISO(_ s: String) -> TimeInterval {
            guard !s.isEmpty else { return 8 * 3600 }
            let parts = s.split(separator: "T").last?.split(separator: ":")
            guard parts?.count ?? 0 >= 2 else { return 8 * 3600 }
            let h = Double(parts![0]) ?? 8
            let m = Double(parts?.count ?? 0 > 1 ? parts![1] : "0") ?? 0
            return h * 3600 + m * 60
        }
        return ProjectModel(
            uid: uid.isEmpty ? UUID().uuidString : uid,
            name: name,
            title: title,
            startDate: reader.parseDate(startDate.isEmpty ? nil : startDate),
            finishDate: reader.parseDate(finishDate.isEmpty ? nil : finishDate),
            calendarUID: reader.parseInt(calendarUID),
            minutesPerDay: Int(minutesPerDay) ?? 480,
            minutesPerWeek: Int(minutesPerWeek) ?? 2400,
            defaultStartTime: defaultStartTime.isEmpty ? 8 * 3600 : timeFromISO(defaultStartTime),
            defaultFinishTime: defaultFinishTime.isEmpty ? 17 * 3600 : timeFromISO(defaultFinishTime),
            scheduleFromStart: scheduleFromStart == "1" || scheduleFromStart.lowercased() == "true",
            currentDate: reader.parseDate(currentDate.isEmpty ? nil : currentDate),
            creationDate: reader.parseDate(creationDate.isEmpty ? nil : creationDate),
            lastSaved: reader.parseDate(lastSaved.isEmpty ? nil : lastSaved),
            saveVersion: saveVersion,
            tasks: tasks.map { $0.build(reader: reader) },
            resources: resources.map { $0.build(reader: reader) },
            assignments: assignments.map { $0.build(reader: reader) },
            calendars: calendars.map { $0.build(reader: reader) }
        )
    }
}

private struct TaskBuilder {
    var uid: Int = 0
    var name: String = ""
    var start: String = ""
    var finish: String = ""
    var duration: String = ""
    var durationFormat: Int = 7
    var percentComplete: Int = 0
    var outlineLevel: Int = 0
    var outlineNumber: String?
    var priority: Int = 500
    var calendarUID: Int?
    var predecessorLinks: [PredecessorBuilder] = []
    var isSummary: Bool = false
    var isMilestone: Bool = false
    var wbs: String?
    var constraintType: Int?
    var constraintDate: String?

    func build(reader: MSPDIReader) -> TaskModel {
        TaskModel(
            uid: uid,
            name: name,
            start: reader.parseDate(start.isEmpty ? nil : start),
            finish: reader.parseDate(finish.isEmpty ? nil : finish),
            duration: reader.parseDuration(duration.isEmpty ? nil : duration),
            durationFormat: durationFormat,
            percentComplete: percentComplete,
            outlineLevel: outlineLevel,
            outlineNumber: outlineNumber,
            priority: priority,
            calendarUID: calendarUID,
            predecessorLinks: predecessorLinks.map { PredecessorLink(predecessorUID: $0.predecessorUID, type: $0.type, linkLag: $0.linkLag, lagFormat: $0.lagFormat) },
            isSummary: isSummary,
            isMilestone: isMilestone,
            wbs: wbs,
            constraintType: constraintType,
            constraintDate: reader.parseDate(constraintDate ?? nil)
        )
    }
}

private struct PredecessorBuilder {
    var predecessorUID: Int = 0
    var type: Int = 1
    var linkLag: Int = 0
    var lagFormat: Int = 7
}

private struct ResourceBuilder {
    var uid: Int = 0
    var name: String = ""
    var type: Int = 1
    var maxUnits: Double = 1
    var stdRate: Double = 0
    var overtimeRate: Double = 0

    func build(reader: MSPDIReader) -> ResourceModel {
        ResourceModel(uid: uid, name: name, type: type, maxUnits: maxUnits, stdRate: stdRate, overtimeRate: overtimeRate)
    }
}

private struct AssignmentBuilder {
    var uid: Int = 0
    var taskUID: Int = 0
    var resourceUID: Int = 0
    var units: Double = 1
    var work: String = ""
    var start: String = ""
    var finish: String = ""

    func build(reader: MSPDIReader) -> AssignmentModel {
        AssignmentModel(
            uid: uid,
            taskUID: taskUID,
            resourceUID: resourceUID,
            units: units,
            work: reader.parseDuration(work.isEmpty ? nil : work),
            start: reader.parseDate(start.isEmpty ? nil : start),
            finish: reader.parseDate(finish.isEmpty ? nil : finish)
        )
    }
}

private struct CalendarBuilder {
    var uid: Int = 0
    var name: String = ""
    var weekDays: [WeekDayRecord] = []
    var exceptions: [CalendarExceptionRecord] = []

    func build(reader: MSPDIReader) -> CalendarModel {
        CalendarModel(
            uid: uid,
            name: name,
            weekDays: weekDays.map { CalendarWeekDay(dayType: $0.dayType, dayWorking: $0.dayWorking, timeFrom: $0.timeFrom, timeTo: $0.timeTo) },
            exceptions: exceptions.map { CalendarException(date: $0.date, timeFrom: nil, timeTo: nil, enteredByOccurrences: false, occurrenceCount: nil) }
        )
    }
}

private struct WeekDayRecord {
    var dayType: Int
    var dayWorking: Bool
    var timeFrom: TimeInterval?
    var timeTo: TimeInterval?
}

private struct CalendarExceptionRecord {
    var date: Date
}

private struct WeekDayBuilder {
    var dayType: Int = 0
    var dayWorking: Bool = false
    var timeFrom: TimeInterval?
    var timeTo: TimeInterval?
}

private struct ExceptionBuilder {
    var startDate: String?
    var endDate: String?
}
