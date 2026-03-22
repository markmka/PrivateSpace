// CloudSyncService.swift
import Foundation
import Combine

final class CloudSyncService: ObservableObject {
    static let shared = CloudSyncService()

    @Published var syncStatus: SyncStatus = .unknown
    @Published var lastSyncDate: Date?

    enum SyncStatus {
        case unknown
        case connected
        case syncing
        case disconnected
        case error(String)
    }

    private init() {}
}
