#!/usr/bin/env python3
"""Link the Flutter SwiftPM plugin package into the hostless RunnerTests bundle.

`flutter build ios --config-only` with SwiftPM enabled adds the generated plugin
package (FlutterGeneratedPluginSwiftPackage) to the Runner target only. RunnerTests
has no TEST_HOST, so it cannot borrow Runner's link and the test link fails with
undefined `purchasely_flutter` symbols. This adds the same package product to the
RunnerTests Frameworks phase. It edits the CI checkout only and is idempotent.

Usage: link-runnertests-spm.py purchasely/example/ios/Runner.xcodeproj/project.pbxproj
"""
import re
import sys

TARGET_ID = "AABBCC001122334455667794"  # RunnerTests native target
PHASE_ID = "AABBCC001122334455667792"  # RunnerTests Frameworks phase
FILE_ID = "AABBCC0011223344556677C0"  # new PBXBuildFile
DEP_ID = "AABBCC0011223344556677C1"  # new XCSwiftPackageProductDependency
NAME = "FlutterGeneratedPluginSwiftPackage"

path = sys.argv[1]
src = open(path, encoding="utf-8").read()
if DEP_ID in src:
    print("RunnerTests already linked")
    sys.exit(0)
if "XCLocalSwiftPackageReference" not in src:
    sys.exit("error: SwiftPM integration missing; run `flutter build ios --config-only` first")


def sub_once(pattern, repl, text):
    out, n = re.subn(pattern, repl, text, count=1, flags=re.S)
    if n != 1:
        sys.exit(f"error: pattern not found: {pattern}")
    return out


src = sub_once(
    r"(/\* Begin PBXBuildFile section \*/\n)",
    rf"\1\t\t{FILE_ID} /* {NAME} in Frameworks */ = {{isa = PBXBuildFile; productRef = {DEP_ID} /* {NAME} */; }};\n",
    src,
)
src = sub_once(
    rf"({PHASE_ID} /\* Frameworks \*/ = \{{.*?files = \(\n)",
    rf"\1\t\t\t\t{FILE_ID} /* {NAME} in Frameworks */,\n",
    src,
)
src = sub_once(
    rf"({TARGET_ID} /\* RunnerTests \*/ = \{{\n)",
    rf"\1\t\t\tpackageProductDependencies = (\n\t\t\t\t{DEP_ID} /* {NAME} */,\n\t\t\t);\n",
    src,
)
src = sub_once(
    r"(/\* Begin XCSwiftPackageProductDependency section \*/\n)",
    rf"\1\t\t{DEP_ID} /* {NAME} */ = {{\n\t\t\tisa = XCSwiftPackageProductDependency;\n\t\t\tproductName = {NAME};\n\t\t}};\n",
    src,
)
open(path, "w", encoding="utf-8").write(src)
print("RunnerTests linked to", NAME)
