import Foundation
import UIKit

final class ClipboardService {
    static let shared = ClipboardService()

    private var clearTimer: Timer?
    private let clearInterval: TimeInterval = 30

    private init() {}

    func copy(_ string: String, sensitive: Bool = true) {
        UIPasteboard.general.string = string

        if sensitive {
            scheduleClear()
        }
    }

    private func scheduleClear() {
        clearTimer?.invalidate()
        clearTimer = Timer.scheduledTimer(withTimeInterval: clearInterval, repeats: false) { [weak self] _ in
            self?.clearClipboard()
        }
    }

    func clearClipboard() {
        UIPasteboard.general.items = []
        clearTimer?.invalidate()
        clearTimer = nil
    }
}