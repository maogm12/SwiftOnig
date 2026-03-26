import OnigurumaC
import Foundation

internal typealias ForeachNameCallback = @Sendable (_ name: String, _ numbers: [Int]) -> Bool

internal final class ForeachNameContext: @unchecked Sendable {
    let encoding: Encoding
    let callback: ForeachNameCallback

    init(encoding: Encoding, callback: @escaping ForeachNameCallback) {
        self.encoding = encoding
        self.callback = callback
    }
}

internal func onigForeachNameCallback(namePtr: UnsafePointer<OnigUChar>?,
                                      nameEndPtr: UnsafePointer<OnigUChar>?,
                                      groupCount: OnigInt,
                                      groupsPtr: UnsafeMutablePointer<OnigInt>?,
                                      regex: OnigRegex?,
                                      contextPtr: UnsafeMutableRawPointer?) -> OnigInt {
    guard let namePtr = namePtr,
          let nameEndPtr = nameEndPtr,
          let groupsPtr = groupsPtr,
          let contextPtr = contextPtr
    else {
        return ONIG_ABORT
    }

    let context = Unmanaged<ForeachNameContext>.fromOpaque(contextPtr).takeUnretainedValue()
    let buffer = UnsafeBufferPointer(start: namePtr, count: namePtr.distance(to: nameEndPtr))

    guard let name = String(bytes: buffer, encoding: context.encoding.stringEncoding) else {
        return ONIG_ABORT
    }

    var groupNumbers = [Int]()
    groupNumbers.reserveCapacity(Int(groupCount))

    for index in 0..<Int(groupCount) {
        groupNumbers.append(Int(groupsPtr[index]))
    }

    return context.callback(name, groupNumbers) ? ONIG_NORMAL : ONIG_ABORT
}
