import Foundation

enum SyncState: String, Codable, CaseIterable {
    case localOnly = "local_only"
    case pendingUpload = "pending_upload"
    case synced
    case conflict
}
