import Foundation
import UIKit

/// Saves date reviews to the Open Date Convex backend (summary and scores only; transcripts stay on the phone).
enum ConvexSync {
    static let deployment = URL(string: "https://compassionate-kangaroo-784.convex.cloud")!
    static var deviceId: String { UIDevice.current.identifierForVendor?.uuidString ?? "unknown" }

    struct Reply: Decodable { let status: String; let errorMessage: String? }

    @discardableResult
    static func saveReview(match: String, place: String, rating: Int, agentScore: Double, summary: String, next: String, recorded: Bool) async -> Bool {
        await call("api/mutation", body: payload(match: match, place: place, rating: rating, agentScore: agentScore,
                                                 summary: summary, next: next, recorded: recorded, deviceId: deviceId))
    }

    static func payload(match: String, place: String, rating: Int, agentScore: Double, summary: String, next: String, recorded: Bool, deviceId: String) -> [String: Any] {
        let args: [String: Any] = ["deviceId": deviceId, "matchName": match, "place": place, "rating": rating,
                                   "agentScore": agentScore, "summary": summary, "next": next, "recorded": recorded]
        return ["path": "dates:save", "args": args, "format": "json"]
    }

    private static func call(_ endpoint: String, body: [String: Any]) async -> Bool {
        var req = URLRequest(url: deployment.appendingPathComponent(endpoint), timeoutInterval: 15)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let reply = try? JSONDecoder().decode(Reply.self, from: data) else { return false }
        return reply.status == "success"
    }
}
