import Foundation

enum DesignerStatus: Equatable, Sendable {
    case available
    /// 使えない理由（画面に出す）
    case unavailable(String)
}

enum DesignError: Error, Equatable {
    case emptyInput
    case emptyResult
}

/// 気になることから実験の形を考える役。本物は端末の中のモデル（OnDeviceDesigner）、テストでは偽物に差し替える。
protocol ExperimentDesigner: Sendable {
    var status: DesignerStatus { get }
    func design(worry: String) async throws -> [ExperimentDraft]
}

/// モデルを使わない（使えない）ときの役
struct UnavailableDesigner: ExperimentDesigner {
    var reason: String
    var status: DesignerStatus { .unavailable(reason) }

    func design(worry: String) async throws -> [ExperimentDraft] {
        throw DesignError.emptyResult
    }
}
