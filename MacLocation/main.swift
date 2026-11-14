import AppKit
import CoreLocation

final class Feed: NSObject, CLLocationManagerDelegate {
    let manager = CLLocationManager()
    let cache: URL
    var active = false
    init(cache: URL) {
        self.cache = cache
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }
    func poll() {
        let request = cache.appendingPathComponent("location-request")
        let changed = try? request.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
        let needed = changed.map { abs($0.timeIntervalSinceNow) < 5 } ?? false
        if needed && !active {
            active = true
            manager.requestWhenInUseAuthorization()
            manager.startUpdatingLocation()
        } else if !needed && active {
            active = false
            manager.stopUpdatingLocation()
            try? FileManager.default.removeItem(at: cache.appendingPathComponent("mac-location"))
        }
        guard active else { return }
        if [.restricted, .denied].contains(manager.authorizationStatus) {
            write(["status":"Enable Open Date Location in Mac System Settings → Privacy & Security → Location Services."])
        } else if let loc = manager.location, loc.horizontalAccuracy >= 0, abs(loc.timestamp.timeIntervalSinceNow) < 60 {
            write(["lat":loc.coordinate.latitude, "lon":loc.coordinate.longitude, "accuracy":loc.horizontalAccuracy, "time":loc.timestamp.timeIntervalSince1970])
        } else {
            write(["status":"Allow Open Date Location on your Mac. Waiting for a location fix…"])
        }
    }
    func write(_ fields: [String: Any]) {
        var packet = fields
        if packet["time"] == nil { packet["time"] = Date().timeIntervalSince1970 }
        try? JSONSerialization.data(withJSONObject: packet).write(to: cache.appendingPathComponent("mac-location"), options: .atomic)
    }
}
let app = NSApplication.shared
guard CommandLine.arguments.count > 1 else { exit(1) }
let feed = Feed(cache: URL(fileURLWithPath: CommandLine.arguments[1]))
let timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in feed.poll() }
app.run()
