import Foundation

public enum UpdateConstants {
    public static let latestReleaseURL = URL(string: "https://api.github.com/repos/adrianogl/prumo/releases/latest")!
    public static let dmgAssetName = "PRumo.dmg"
    public static let checksumAssetName = "PRumo.dmg.sha256"
    public static let appBundleName = "PRumo.app"
    static let infoPlistPath = "Contents/Info.plist"
    static let bundleIdentifierKey = "CFBundleIdentifier"
    static let shortVersionKey = "CFBundleShortVersionString"
    static let mountDirectoryName = "mount"
    static let stagingPrefix = ".PRumo-"
    static let hdiutil = "/usr/bin/hdiutil"
    static let xattr = "/usr/bin/xattr"
    static let shell = "/bin/sh"
    static let quarantineAttribute = "com.apple.quarantine"
    static let notFoundStatus = 404
    static let rateLimitStatuses: Set<Int> = [403, 429]
    static let relaunchScript = "(while kill -0 \"$1\" 2>/dev/null; do sleep 0.2; done; /usr/bin/open -n \"$2\") >/dev/null 2>&1 &"
}
