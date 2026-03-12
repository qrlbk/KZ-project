import Foundation

/// Writes ProjectModel to Microsoft Project Data Interchange (MSPDI) XML.
final class MSPDIWriter {
    private let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    func write(project: ProjectModel) throws -> Data {
        var xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Project xmlns="http://schemas.microsoft.com/project/2007">
        <SaveVersion>\(project.saveVersion)</SaveVersion>
        <UID>\(project.uid)</UID>
        <Name>\(escape(project.name))</Name>
        <Title>\(escape(project.title))</Title>
        <ScheduleFromStart>\(project.scheduleFromStart ? 1 : 0)</ScheduleFromStart>
        <MinutesPerDay>\(project.minutesPerDay)</MinutesPerDay>
        <MinutesPerWeek>\(project.minutesPerWeek)</MinutesPerWeek>
        <CurrentDate>\(formatDate(project.currentDate ?? Date()))</CurrentDate>
        """
        if let d = project.startDate { xml += "\n<StartDate>\(formatDate(d))</StartDate>" }
        if let d = project.finishDate { xml += "\n<FinishDate>\(formatDate(d))</FinishDate>" }
        if let uid = project.calendarUID { xml += "\n<CalendarUID>\(uid)</CalendarUID>" }
        if let d = project.creationDate { xml += "\n<CreationDate>\(formatDate(d))</CreationDate>" }
        if let d = project.lastSaved { xml += "\n<LastSaved>\(formatDate(d))</LastSaved>" }
        xml += "\n<DefaultStartTime>\(formatTime(project.defaultStartTime))</DefaultStartTime>"
        xml += "\n<DefaultFinishTime>\(formatTime(project.defaultFinishTime))</DefaultFinishTime>"

        xml += "\n<Calendars>"
        for cal in project.calendars {
            xml += "\n  <Calendar><UID>\(cal.uid)</UID><Name>\(escape(cal.name))</Name>"
            for wd in cal.weekDays {
                xml += "\n    <WeekDay DayType=\"\(wd.dayType)\" DayWorking=\"\(wd.dayWorking ? 1 : 0)\">"
                if let from = wd.timeFrom { xml += "<TimeFrom>\(formatDuration(from))</TimeFrom>" }
                if let to = wd.timeTo { xml += "<TimeTo>\(formatDuration(to))</TimeTo>" }
                xml += "</WeekDay>"
            }
            xml += "\n  </Calendar>"
        }
        xml += "\n</Calendars>"

        xml += "\n<Tasks>"
        for t in project.tasks {
            xml += "\n  <Task>"
            xml += "\n    <UID>\(t.uid)</UID><Name>\(escape(t.name))</Name>"
            // MS Project expects OutlineLevel to be 1-based; 0 can break some views.
            let outlineLevel = max(1, t.outlineLevel)
            if let s = t.start { xml += "\n    <Start>\(formatDate(s))</Start>" }
            if let f = t.finish { xml += "\n    <Finish>\(formatDate(f))</Finish>" }
            xml += "\n    <Duration>\(formatDuration(t.duration))</Duration>"
            xml += "\n    <DurationFormat>\(t.durationFormat)</DurationFormat>"
            xml += "\n    <PercentComplete>\(t.percentComplete)</PercentComplete>"
            xml += "\n    <OutlineLevel>\(outlineLevel)</OutlineLevel>"
            if let n = t.outlineNumber, !n.isEmpty, n != "0" { xml += "\n    <OutlineNumber>\(escape(n))</OutlineNumber>" }
            xml += "\n    <Priority>\(t.priority)</Priority>"
            // Omit invalid calendar UID values like -1
            if let uid = t.calendarUID, uid > 0 { xml += "\n    <CalendarUID>\(uid)</CalendarUID>" }
            xml += "\n    <Summary>\(t.isSummary ? 1 : 0)</Summary>"
            xml += "\n    <Milestone>\(t.isMilestone ? 1 : 0)</Milestone>"
            if let wbs = t.wbs { xml += "\n    <WBS>\(escape(wbs))</WBS>" }
            if let ct = t.constraintType { xml += "\n    <ConstraintType>\(ct)</ConstraintType>" }
            if let d = t.constraintDate { xml += "\n    <ConstraintDate>\(formatDate(d))</ConstraintDate>" }
            for pl in t.predecessorLinks {
                xml += "\n    <PredecessorLink><PredecessorUID>\(pl.predecessorUID)</PredecessorUID><Type>\(pl.type)</Type><LinkLag>\(pl.linkLag)</LinkLag><LagFormat>\(pl.lagFormat)</LagFormat></PredecessorLink>"
            }
            xml += "\n  </Task>"
        }
        xml += "\n</Tasks>"

        xml += "\n<Resources>"
        for r in project.resources {
            xml += "\n  <Resource><UID>\(r.uid)</UID><Name>\(escape(r.name))</Name><Type>\(r.type)</Type><MaxUnits>\(r.maxUnits)</MaxUnits><StdRate>\(r.stdRate)</StdRate><OvertimeRate>\(r.overtimeRate)</OvertimeRate></Resource>"
        }
        xml += "\n</Resources>"

        xml += "\n<Assignments>"
        for a in project.assignments {
            xml += "\n  <Assignment><UID>\(a.uid)</UID><TaskUID>\(a.taskUID)</TaskUID><ResourceUID>\(a.resourceUID)</ResourceUID><Units>\(a.units)</Units><Work>\(formatDuration(a.work))</Work>"
            if let s = a.start { xml += "<Start>\(formatDate(s))</Start>" }
            if let f = a.finish { xml += "<Finish>\(formatDate(f))</Finish>" }
            xml += "</Assignment>"
        }
        xml += "\n</Assignments>"

        xml += "\n</Project>"
        return xml.data(using: String.Encoding.utf8) ?? Data()
    }

    private func escape(_ s: String) -> String {
        s
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }

    private func formatDate(_ d: Date) -> String {
        iso8601.string(from: d)
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let h = Int(seconds) / 3600
        let m = (Int(seconds) % 3600) / 60
        return String(format: "PT%02dH%02dM0S", h, m)
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let totalMinutes = Int64(seconds / 60)
        if totalMinutes % 480 == 0 {
            return "PT\(totalMinutes / 480)D"
        }
        let h = Int(seconds) / 3600
        let m = (Int(seconds) % 3600) / 60
        return String(format: "PT%02dH%02dM0S", h, m)
    }
}
