import Foundation

// MARK: - Project

struct ProjectModel: Identifiable {
    var id: String { uid }
    var uid: String
    var name: String
    var title: String
    var startDate: Date?
    var finishDate: Date?
    var calendarUID: Int?
    var minutesPerDay: Int
    var minutesPerWeek: Int
    var defaultStartTime: TimeInterval
    var defaultFinishTime: TimeInterval
    var scheduleFromStart: Bool
    var currentDate: Date?
    var creationDate: Date?
    var lastSaved: Date?
    var saveVersion: Int

    var tasks: [TaskModel]
    var resources: [ResourceModel]
    var assignments: [AssignmentModel]
    var calendars: [CalendarModel]

    init(
        uid: String = UUID().uuidString,
        name: String = "",
        title: String = "",
        startDate: Date? = nil,
        finishDate: Date? = nil,
        calendarUID: Int? = nil,
        minutesPerDay: Int = 480,
        minutesPerWeek: Int = 2400,
        defaultStartTime: TimeInterval = 8 * 3600,
        defaultFinishTime: TimeInterval = 17 * 3600,
        scheduleFromStart: Bool = true,
        currentDate: Date? = nil,
        creationDate: Date? = nil,
        lastSaved: Date? = nil,
        saveVersion: Int = 12,
        tasks: [TaskModel] = [],
        resources: [ResourceModel] = [],
        assignments: [AssignmentModel] = [],
        calendars: [CalendarModel] = []
    ) {
        self.uid = uid
        self.name = name
        self.title = title
        self.startDate = startDate
        self.finishDate = finishDate
        self.calendarUID = calendarUID
        self.minutesPerDay = minutesPerDay
        self.minutesPerWeek = minutesPerWeek
        self.defaultStartTime = defaultStartTime
        self.defaultFinishTime = defaultFinishTime
        self.scheduleFromStart = scheduleFromStart
        self.currentDate = currentDate ?? Date()
        self.creationDate = creationDate
        self.lastSaved = lastSaved
        self.saveVersion = saveVersion
        self.tasks = tasks
        self.resources = resources
        self.assignments = assignments
        self.calendars = calendars
    }
}

// MARK: - Task

struct TaskModel: Identifiable {
    var id: Int { uid }
    var uid: Int
    var name: String
    var start: Date?
    var finish: Date?
    var duration: TimeInterval
    var durationFormat: Int
    var percentComplete: Int
    var outlineLevel: Int
    var outlineNumber: String?
    var priority: Int
    var calendarUID: Int?
    var predecessorLinks: [PredecessorLink]
    var isSummary: Bool
    var isMilestone: Bool
    var wbs: String?
    var constraintType: Int?
    var constraintDate: Date?

    init(
        uid: Int,
        name: String = "",
        start: Date? = nil,
        finish: Date? = nil,
        duration: TimeInterval = 0,
        durationFormat: Int = 7,
        percentComplete: Int = 0,
        outlineLevel: Int = 0,
        outlineNumber: String? = nil,
        priority: Int = 500,
        calendarUID: Int? = nil,
        predecessorLinks: [PredecessorLink] = [],
        isSummary: Bool = false,
        isMilestone: Bool = false,
        wbs: String? = nil,
        constraintType: Int? = nil,
        constraintDate: Date? = nil
    ) {
        self.uid = uid
        self.name = name
        self.start = start
        self.finish = finish
        self.duration = duration
        self.durationFormat = durationFormat
        self.percentComplete = percentComplete
        self.outlineLevel = outlineLevel
        self.outlineNumber = outlineNumber
        self.priority = priority
        self.calendarUID = calendarUID
        self.predecessorLinks = predecessorLinks
        self.isSummary = isSummary
        self.isMilestone = isMilestone
        self.wbs = wbs
        self.constraintType = constraintType
        self.constraintDate = constraintDate
    }
}

struct PredecessorLink {
    var predecessorUID: Int
    var type: Int // 0=FF, 1=FS, 2=SF, 3=SS
    var linkLag: Int
    var lagFormat: Int
}

// MARK: - Resource

struct ResourceModel: Identifiable {
    var id: Int { uid }
    var uid: Int
    var name: String
    var type: Int // 1=work, 2=material
    var maxUnits: Double
    var stdRate: Double
    var overtimeRate: Double

    init(
        uid: Int,
        name: String = "",
        type: Int = 1,
        maxUnits: Double = 1,
        stdRate: Double = 0,
        overtimeRate: Double = 0
    ) {
        self.uid = uid
        self.name = name
        self.type = type
        self.maxUnits = maxUnits
        self.stdRate = stdRate
        self.overtimeRate = overtimeRate
    }
}

// MARK: - Assignment

struct AssignmentModel: Identifiable {
    var id: Int { uid }
    var uid: Int
    var taskUID: Int
    var resourceUID: Int
    var units: Double
    var work: TimeInterval
    var start: Date?
    var finish: Date?

    init(
        uid: Int,
        taskUID: Int,
        resourceUID: Int,
        units: Double = 1,
        work: TimeInterval = 0,
        start: Date? = nil,
        finish: Date? = nil
    ) {
        self.uid = uid
        self.taskUID = taskUID
        self.resourceUID = resourceUID
        self.units = units
        self.work = work
        self.start = start
        self.finish = finish
    }
}

// MARK: - Calendar

struct CalendarModel: Identifiable {
    var id: Int { uid }
    var uid: Int
    var name: String
    var weekDays: [CalendarWeekDay]
    var exceptions: [CalendarException]

    init(
        uid: Int,
        name: String = "",
        weekDays: [CalendarWeekDay] = [],
        exceptions: [CalendarException] = []
    ) {
        self.uid = uid
        self.name = name
        self.weekDays = weekDays
        self.exceptions = exceptions
    }
}

struct CalendarWeekDay {
    var dayType: Int // 0=Sunday..6=Saturday, 7=nonworking
    var dayWorking: Bool
    var timeFrom: TimeInterval?
    var timeTo: TimeInterval?
}

struct CalendarException {
    var date: Date
    var timeFrom: TimeInterval?
    var timeTo: TimeInterval?
    var enteredByOccurrences: Bool
    var occurrenceCount: Int?
}
