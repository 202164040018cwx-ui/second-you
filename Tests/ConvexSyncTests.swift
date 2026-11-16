import XCTest
@testable import OpenDate

final class ConvexSyncTests: XCTestCase {
    private let body = ConvexSync.payload(match: "Ari", place: "Cafe Luna", rating: 4, agentScore: 0.82,
                                          summary: "Good chat", next: "Second date", recorded: true, deviceId: "device-123")

    func testPathAndFormat() {
        XCTAssertEqual(body["path"] as? String, "dates:save")
        XCTAssertEqual(body["format"] as? String, "json")
        XCTAssertEqual(Set(body.keys), ["path", "args", "format"])
    }

    func testArgsHaveAllEightFieldsWithCorrectTypes() throws {
        let args = try XCTUnwrap(body["args"] as? [String: Any])
        XCTAssertEqual(args.count, 8)
        XCTAssertEqual(args["deviceId"] as? String, "device-123")
        XCTAssertEqual(args["matchName"] as? String, "Ari")
        XCTAssertEqual(args["place"] as? String, "Cafe Luna")
        XCTAssertEqual(args["rating"] as? Int, 4)
        XCTAssertEqual(args["agentScore"] as? Double, 0.82)
        XCTAssertEqual(args["summary"] as? String, "Good chat")
        XCTAssertEqual(args["next"] as? String, "Second date")
        XCTAssertEqual(args["recorded"] as? Bool, true)
    }

    func testPayloadSerializesToJSON() throws {
        XCTAssertTrue(JSONSerialization.isValidJSONObject(body))
        let data = try JSONSerialization.data(withJSONObject: body)
        let decoded = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(decoded["path"] as? String, "dates:save")
    }
}
