import Foundation
import UserNotifications

final class NotificationScheduler {
    static let shared = NotificationScheduler()
    private init() {}

    private let prefix = "ob_"

    func rescheduleAll(from state: AppStateForNotifications) {
        if state.notifications == false {
            clearAll()
            return
        }

        clearAll()

        // Ohne OP-Datum: trotzdem Termine + Meds
        scheduleAppointments(state.appointments)
        scheduleMedications(state.medications)

        guard let opDateStr = state.profile.opDate,
              let opDate = parseISODateOnly(opDateStr) else {
            return
        }

        // 1) Timeline daily 08:00
        scheduleDaily(id: "\(prefix)timeline_daily_0800", hour: 8, minute: 0,
                      title: "Timeline",
                      body: "Schau in deine Timeline: Was sind heute die nächsten Aufgaben?")

        // 1) OP-Reminder: -1 Tag 20:00
        if let date = combine(dateOnly: addDays(opDate, -1), hour: 20, minute: 0) {
            scheduleOnce(id: "\(prefix)op_tomorrow_2000", date: date,
                         title: "Morgen ist OP",
                         body: "Morgen findet deine Operation statt.")
        }

        // 4) Packliste: -1 Tag 21:00
        if let date = combine(dateOnly: addDays(opDate, -1), hour: 21, minute: 0) {
            scheduleOnce(id: "\(prefix)packlist_2100", date: date,
                         title: "Packliste",
                         body: "Bitte Packliste prüfen und alles bereitlegen.")
        }

        // Extra sinnvoll: Nüchtern-Wecker -1 Tag zur gewählten Uhrzeit
        if let t = state.fastingAlarms?.time,
           let (h, m) = parseHHmm(t),
           let date = combine(dateOnly: addDays(opDate, -1), hour: h, minute: m) {
            scheduleOnce(id: "\(prefix)fasting_alarm", date: date,
                         title: "Nüchternheit",
                         body: "Bitte ab jetzt Nüchternheitsregeln beachten (wie besprochen).")
        }

        // 5) Wundtagebuch: ausgewählte Tage nach OP zur Uhrzeit
        if let wound = state.woundAlarms,
           let time = wound.time,
           let (h, m) = parseHHmm(time),
           let days = wound.days {
            for dStr in days {
                let dayOffset = Int(dStr) ?? 0
                guard dayOffset >= 0 else { continue }
                if let fireDate = combine(dateOnly: addDays(opDate, dayOffset), hour: h, minute: m) {
                    scheduleOnce(id: "\(prefix)wound_day_\(dayOffset)_\(h)\(m)", date: fireDate,
                                 title: "Wundtagebuch",
                                 body: "Bitte Wunde dokumentieren (Foto/Notiz).")
                }
            }
        }

        // 6) Post-OP Tracking Tag 1..12 um 12:00
        for day in 1...12 {
            if let date = combine(dateOnly: addDays(opDate, day), hour: 12, minute: 0) {
                scheduleOnce(id: "\(prefix)postop_tracking_day_\(day)", date: date,
                             title: "Tägliche Doku",
                             body: "Bitte Schmerz-Tracking, Vitalwerte und Medikamentendoku eintragen.")
            }
        }
    }

    func clearAll() {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { [prefix] reqs in
            let ids = reqs.map(\.identifier).filter { $0.hasPrefix(prefix) }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
        }
    }

    private func scheduleAppointments(_ appts: [AppStateForNotifications.Appointment]) {
        for a in appts {
            if a.reminder == false { continue }
            guard let dt = parseISODateTimeLocal(a.datetime) else { continue }

            // 1 Tag vorher 21:00
            if let d1 = combine(dateOnly: addDays(startOfDay(dt), -1), hour: 21, minute: 0) {
                scheduleOnce(
                    id: "\(prefix)appt_\(a.id)_daybefore_2100",
                    date: d1,
                    title: "Termin morgen",
                    body: "\(a.title) ist morgen."
                )
            }

            // 3 Stunden vorher
            let d2 = dt.addingTimeInterval(-3 * 3600)
            if d2 > Date() {
                scheduleOnce(
                    id: "\(prefix)appt_\(a.id)_3h",
                    date: d2,
                    title: "Termin in 3 Stunden",
                    body: "\(a.title) um \(formatTime(dt))."
                )
            }
        }
    }

    private func scheduleMedications(_ meds: [AppStateForNotifications.Medication]) {
        for m in meds {
            if m.asNeeded == true { continue }
            for alarm in m.alarms where alarm.enabled {
                guard let (h, mi) = parseHHmm(alarm.time) else { continue }
                scheduleDaily(
                    id: "\(prefix)med_\(m.id)_\(h)\(mi)",
                    hour: h,
                    minute: mi,
                    title: "Medikament",
                    body: "\(m.name)\(m.dose.map { " – \($0)" } ?? "")"
                )
            }
        }
    }

    private func scheduleOnce(id: String, date: Date, title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let comps = Calendar.current.dateComponents([.year,.month,.day,.hour,.minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)

        let req = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(req)
    }

    private func scheduleDaily(id: String, hour: Int, minute: Int, title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        var comps = DateComponents()
        comps.calendar = .current
        comps.hour = hour
        comps.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        let req = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(req)
    }

    private func parseISODateOnly(_ s: String) -> Date? {
        let trimmed = String(s.prefix(10))
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: trimmed)
    }

    private func parseISODateTimeLocal(_ s: String) -> Date? {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd'T'HH:mm"
        return f.date(from: s)
    }

    private func parseHHmm(_ s: String) -> (Int, Int)? {
        let parts = s.split(separator: ":")
        guard parts.count == 2,
              let h = Int(parts[0]),
              let m = Int(parts[1]),
              (0...23).contains(h),
              (0...59).contains(m) else { return nil }
        return (h, m)
    }

    private func addDays(_ date: Date, _ days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: date) ?? date
    }

    private func startOfDay(_ date: Date) -> Date {
        Calendar.current.startOfDay(for: date)
    }

    private func combine(dateOnly: Date, hour: Int, minute: Int) -> Date? {
        var c = Calendar.current.dateComponents([.year,.month,.day], from: dateOnly)
        c.hour = hour
        c.minute = minute
        return Calendar.current.date(from: c)
    }

    private func formatTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.timeZone = .current
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }
}
