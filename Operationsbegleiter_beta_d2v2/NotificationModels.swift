import Foundation

struct AppStateForNotifications: Codable {
    var notifications: Bool?
    var profile: Profile
    var appointments: [Appointment]
    var medications: [Medication]
    var fastingAlarms: FastingAlarm?
    var woundAlarms: WoundAlarm?

    struct Profile: Codable {
        var opDate: String?
    }

    struct Appointment: Codable {
        var id: String
        var title: String
        var datetime: String
        var location: String?
        var reminder: Bool?
    }

    struct Medication: Codable {
        var id: String
        var name: String
        var dose: String?
        var alarms: [MedAlarm]
        var asNeeded: Bool?

        struct MedAlarm: Codable {
            var time: String
            var enabled: Bool
        }
    }

    struct FastingAlarm: Codable {
        var time: String?
        var created: String?
    }

    struct WoundAlarm: Codable {
        var time: String?
        var days: [String]?
        var created: String?
    }
}
