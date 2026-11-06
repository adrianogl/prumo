import Foundation

public enum UpdateInstallError: Error, Equatable {
    case notInstallable
    case notWritable
    case downloadFailed
    case checksumMismatch
    case mountFailed
    case copyFailed
    case packageMismatch
    case replaceFailed
    case relaunchFailed
}
