import XCTest
import UIKit
import ObjectiveC

/// Runs for the whole live session: launches the app under test, then serves
/// screenshots and accepts taps, swipes and typing over HTTP until told to stop.
///
/// Configured through environment variables that xcodebuild passes on from
/// `TEST_RUNNER_<NAME>`: TARGET_BUNDLE_ID and DRIVER_PORT.
final class LiveDriverUITests: XCTestCase {
    func testLiveSession() throws {
        continueAfterFailure = true
        Quiescence.disable()

        let environment = ProcessInfo.processInfo.environment
        let bundleID = environment["TARGET_BUNDLE_ID"] ?? ""
        let port = UInt16(environment["DRIVER_PORT"] ?? "") ?? 8100

        let app = bundleID.isEmpty ? XCUIApplication() : XCUIApplication(bundleIdentifier: bundleID)
        app.launch()

        let driver = Driver(app: app)
        let server = try HTTPServer(port: port) { driver.handle($0) }
        server.start()
        print("LiveDriver: listening on port \(port), driving \(bundleID)")

        while !driver.stopped {
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))
        }
        server.stop()
        print("LiveDriver: session ended")
    }
}

final class Driver {
    let app: XCUIApplication
    let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
    private(set) var stopped = false

    init(app: XCUIApplication) {
        self.app = app
    }

    /// The app on screen: the app under test, or the home screen after Home was pressed.
    private var front: XCUIApplication {
        app.state == .runningForeground ? app : springboard
    }

    /// Converts normalized (0–1) screen coordinates from the viewer into a tap point.
    private func point(_ body: [String: Any], _ xKey: String = "x", _ yKey: String = "y") -> XCUICoordinate {
        let x = (body[xKey] as? Double) ?? 0.5
        let y = (body[yKey] as? Double) ?? 0.5
        return front.coordinate(withNormalizedOffset: CGVector(dx: x, dy: y))
    }

    func handle(_ request: HTTPRequest) -> HTTPResponse {
        let body = request.json
        switch (request.method, request.path) {
        case ("GET", "/health"):
            return .json(["ok": true, "foreground": app.state == .runningForeground])
        case ("GET", "/frame"):
            return frame(maxWidth: Double(request.query["w"] ?? "") ?? 600)
        case ("POST", "/tap"):
            point(body).tap()
        case ("POST", "/longpress"):
            point(body).press(forDuration: 0.8)
        case ("POST", "/swipe"):
            let start = point(body, "x1", "y1")
            let end = point(body, "x2", "y2")
            start.press(forDuration: 0.05, thenDragTo: end)
        case ("POST", "/type"):
            let target = front
            guard target.keyboards.count > 0 else {
                return .json(["ok": false, "error": "Tap a text field first, then type."])
            }
            let text = (body["text"] as? String ?? "")
                .replacingOccurrences(of: "\n", with: XCUIKeyboardKey.return.rawValue)
            target.typeText(text)
        case ("POST", "/home"):
            XCUIDevice.shared.press(.home)
        case ("POST", "/launch"):
            app.activate()
        case ("POST", "/relaunch"):
            app.terminate()
            app.launch()
        case ("POST", "/rotate"):
            let device = XCUIDevice.shared
            device.orientation = device.orientation.isLandscape ? .portrait : .landscapeLeft
        case ("POST", "/stop"):
            stopped = true
        default:
            return .json(["ok": false, "error": "Unknown command \(request.path)"], status: 404)
        }
        return .json(["ok": true])
    }

    /// A JPEG of the simulator screen, scaled down to at most `maxWidth` pixels wide.
    private func frame(maxWidth: Double) -> HTTPResponse {
        let image = XCUIScreen.main.screenshot().image
        let pixelWidth = image.size.width * image.scale
        let factor = min(1, maxWidth / pixelWidth)
        let size = CGSize(width: (pixelWidth * factor).rounded(),
                          height: (image.size.height * image.scale * factor).rounded())
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let jpeg = UIGraphicsImageRenderer(size: size, format: format).jpegData(withCompressionQuality: 0.6) { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return HTTPResponse(status: 200, contentType: "image/jpeg", body: jpeg)
    }
}

enum Quiescence {
    /// XCUITest waits for the app to stop animating before every action. Animated
    /// widgets never stop, so every tap would stall; turn the wait off, the same way
    /// WebDriverAgent does.
    static func disable() {
        guard let processClass = NSClassFromString("XCUIApplicationProcess") else { return }
        let noop: @convention(block) (AnyObject) -> Void = { _ in }
        let implementation = imp_implementationWithBlock(noop)
        for name in ["waitForQuiescenceIncludingAnimationsIdle:", "waitForQuiescenceIncludingAnimationsIdle:isPreEvent:"] {
            if let method = class_getInstanceMethod(processClass, NSSelectorFromString(name)) {
                method_setImplementation(method, implementation)
            }
        }
    }
}
