import OpenRCT2Core
// Simple test for OpenRCT2Core
import XCTest

final class OpenRCT2CoreTests: XCTestCase {
    func testInit() {
        XCTAssertTrue(openrct2_init(nil))
    }

    func testFrameBuffer() {
        _ = openrct2_init(nil)

        XCTAssertEqual(openrct2_get_frame_width(), UInt32(ORCT2_SCREEN_WIDTH))
        XCTAssertEqual(openrct2_get_frame_height(), UInt32(ORCT2_SCREEN_HEIGHT))
        XCTAssertNotNil(openrct2_get_frame_buffer())
        XCTAssertNotNil(openrct2_get_palette())
    }

    func testTick() {
        _ = openrct2_init(nil)

        // Should not crash
        for _ in 0..<100 {
            openrct2_tick()
        }
    }

    func testShutdown() {
        _ = openrct2_init(nil)
        openrct2_shutdown()
        // Should be able to re-init
        XCTAssertTrue(openrct2_init(nil))
    }
}
