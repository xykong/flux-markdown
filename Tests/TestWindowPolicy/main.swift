import Foundation

func require(_ condition: @autoclosure () -> Bool) {
    if !condition() { fatalError("Window policy regression") }
}
let primary = CGRect(x: 0, y: 0, width: 1512, height: 949)
let secondary = CGRect(x: 1512, y: -98, width: 1920, height: 1080)
let size = CGSize(width: 900, height: 840)
require(TestWindowPolicy(environment: [:]) == .secondaryBackground)
require(TestWindowPolicy(environment: ["FLUX_TEST_WINDOW_POLICY":"invalid"]) == nil)
require(!TestWindowPolicy.secondaryBackground.allowsFocus)
require(TestWindowPolicy.secondaryForeground.allowsFocus)
require(TestWindowPolicy.secondaryBackground.frame(size: size, screens: [primary]) == nil)
require(TestWindowPolicy.secondaryBackground.frame(size: CGSize(width: 2000, height: 1200), screens: [primary, secondary]) == nil)
let frame = TestWindowPolicy.secondaryBackground.frame(size: size, screens: [primary, secondary])!
require(secondary.contains(frame))
require(!primary.intersects(frame))
let left = CGRect(x: -1920, y: 0, width: 1920, height: 1080)
require(left.contains(TestWindowPolicy.secondaryBackground.frame(size: size, screens: [primary, left])!))
require(primary.contains(TestWindowPolicy.ciForeground.frame(size: size, screens: [primary])!))
print("PASS test-window policy: defaults, focus, missing/oversized/left secondary, explicit CI")
