import Foundation

enum Provider: String, Codable { case claude, codex }

struct UsageWindow: Identifiable, Codable, Equatable {
    let id: String
    let label: String
    let usedPercent: Double
    let resetsAt: Date?

    var clampedPercent: Double { min(100, max(0, usedPercent)) }
}

struct ProviderUsage: Codable, Equatable {
    let provider: Provider
    let updatedAt: Date
    let windows: [UsageWindow]
}

struct ProviderStatus {
    var usage: ProviderUsage?
    var errorMessage: String?
    var isRefreshing = false
}

func durationLabel(_ minutes: Int?) -> String {
    guard let minutes, minutes > 0 else { return "Usage" }
    if minutes % 1_440 == 0 { return "\(minutes / 1_440)d" }
    if minutes >= 1_440 { return "\(minutes / 1_440)d \((minutes % 1_440) / 60)h" }
    if minutes % 60 == 0 { return "\(minutes / 60)h" }
    return minutes < 60 ? "\(minutes)m" : "\(minutes / 60)h \(minutes % 60)m"
}
