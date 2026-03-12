import Foundation

/// Русские строки интерфейса
enum L10n {
    // Вкладки
    static let tabTasks = "Задачи"
    static let tabGantt = "Диаграмма Ганта"
    static let tabResources = "Ресурсы"

    // Тулбар
    static let openFile = "Открыть файл"
    static let exportXML = "Экспорт в XML…"
    static let share = "Поделиться"

    // Задачи
    static let addTask = "Добавить задачу"
    static let delete = "Удалить"
    static let newTask = "Новая задача"
    static let colId = "№"
    static let colName = "Название"
    static let colStart = "Начало"
    static let colFinish = "Окончание"
    static let colDuration = "Длительность"
    static let colPercentComplete = "% выполнения"
    static let colPredecessors = "Предшественники"
    static let sectionTask = "Задача"
    static let name = "Название"
    static let start = "Начало"
    static let finish = "Окончание"
    static func completePercent(_ value: Int) -> String { "Выполнено: \(value)%" }
    static let outlineLevel = "Уровень структуры"
    static func level(_ i: Int) -> String { "Уровень \(i)" }
    static let summary = "Сводная"
    static let milestone = "Веха"
    static let inspectorTask = "Свойства задачи"
    static let sectionPredecessors = "Предшественники"
    static let addPredecessor = "Добавить предшественника"
    static let linkTypeFS = "Окончание–Начало (FS)"
    static let linkTypeSS = "Начало–Начало (SS)"
    static let linkTypeFF = "Окончание–Окончание (FF)"
    static let linkTypeSF = "Начало–Окончание (SF)"
    static let duration = "Длительность"
    static let hours = "часов"
    static let days = "дней"

    // Ресурсы
    static let addResource = "Добавить ресурс"
    static let newResource = "Новый ресурс"
    static let colType = "Тип"
    static let colUnits = "Единицы"
    static let colStdRate = "Ставка"
    static let typeWork = "Труд"
    static let typeMaterial = "Материал"
    static let sectionResource = "Ресурс"
    static let maxUnits = "Макс. единиц"
    static let stdRate = "Ставка"
    static let overtimeRate = "Ставка сверхурочных"
    static let inspectorResource = "Свойства ресурса"

    // Назначения
    static let tabAssignments = "Назначения"
    static let sectionAssignments = "Назначенные ресурсы"
    static let addAssignment = "Добавить назначение"
    static let colTask = "Задача"
    static let colResource = "Ресурс"
    static let colWork = "Трудозатраты"
    static let assignResource = "Назначить ресурс"

    // Календари
    static let tabCalendars = "Календари"
    static let addCalendar = "Добавить календарь"
    static let calendarName = "Название календаря"
    static let workDays = "Рабочие дни"
    static let exceptions = "Исключения"
    static let projectCalendar = "Календарь проекта"

    // Свойства проекта
    static let projectProperties = "Свойства проекта"
    static let projectName = "Имя проекта"
    static let projectTitle = "Название"
    static let defaultCalendar = "Календарь по умолчанию"

    // Общее
    static let noData = "—"

    // Ошибки
    static let exportFailed = "Ошибка экспорта"
    static let shareFailed = "Ошибка отправки"

    // Меню
    static let menuExportXML = "Экспорт в XML…"
}
