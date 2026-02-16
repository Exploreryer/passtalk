import Foundation

final class DeviceIDProvider {
    static let shared = DeviceIDProvider()
    private let defaults = UserDefaults.standard
    private let key = "passtalk.device_id"

    private init() {}

    var deviceID: String {
        if let existing = defaults.string(forKey: key) {
            return existing
        }
        let value = UUID().uuidString
        defaults.set(value, forKey: key)
        return value
    }
}
