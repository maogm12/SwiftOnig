import Foundation
import OnigurumaC

public enum OnigurumaCalloutPhase: Sendable {
    case progress
    case retraction
}

public struct OnigurumaCalloutPhaseSet: OptionSet, Sendable {
    public let rawValue: Int32

    public init(rawValue: Int32) {
        self.rawValue = rawValue
    }

    public static let progress = OnigurumaCalloutPhaseSet(rawValue: Int32(ONIG_CALLOUT_IN_PROGRESS.rawValue))
    public static let retraction = OnigurumaCalloutPhaseSet(rawValue: Int32(ONIG_CALLOUT_IN_RETRACTION.rawValue))
    public static let both: OnigurumaCalloutPhaseSet = [.progress, .retraction]
}

public enum OnigurumaCalloutArgument: Sendable, Equatable {
    case long(Int)
    case codePoint(OnigCodePoint)
    case string(String)
    case pointer(UInt)
    case tag(Int)
}

public enum OnigurumaCalloutAction: Int32, Sendable {
    case `continue` = 0
    case fail = 1
}

public struct OnigurumaCalloutContext: Sendable {
    public let phase: OnigurumaCalloutPhase
    public let name: String?
    public let contents: String?
    public let currentOffset: Int
    public let startOffset: Int
    public let searchRangeUpperBound: Int
    public let retryCount: UInt
    public let captureRanges: [Range<Int>?]
    public let arguments: [OnigurumaCalloutArgument]
}

public typealias OnigurumaCalloutHandler = @Sendable (OnigurumaCalloutContext) -> OnigurumaCalloutAction

internal enum OnigurumaCalloutRegistry {
    private final class State: @unchecked Sendable {
        let lock = NSLock()
        var namedHandlers = [String: OnigurumaCalloutHandler]()
    }

    private static let state = State()

    static func handler(named name: String) -> OnigurumaCalloutHandler? {
        state.lock.lock()
        defer { state.lock.unlock() }
        return state.namedHandlers[name]
    }

    static func setHandler(_ handler: @escaping OnigurumaCalloutHandler, for name: String) {
        state.lock.lock()
        state.namedHandlers[name] = handler
        state.lock.unlock()
    }

    static func removeAll() {
        state.lock.lock()
        state.namedHandlers.removeAll(keepingCapacity: false)
        state.lock.unlock()
    }
}

private func decodeCalloutBytes(start: UnsafePointer<OnigUChar>?, end: UnsafePointer<OnigUChar>?, encoding: Encoding) -> String? {
    guard let start, let end, end >= start else {
        return nil
    }

    let count = start.distance(to: end)
    let buffer = UnsafeBufferPointer(start: start, count: count)
    let data = Data(buffer: buffer)
    return String(data: data, encoding: encoding.stringEncoding) ?? String(decoding: buffer, as: UTF8.self)
}

private func decodeCalloutCString(_ pointer: UnsafeMutablePointer<OnigUChar>?, encoding: Encoding) -> String? {
    guard let pointer else {
        return nil
    }

    let cString = UnsafePointer(pointer).withMemoryRebound(to: CChar.self, capacity: 1) { $0 }
    let end = pointer.advanced(by: Int(strlen(cString)))
    return decodeCalloutBytes(start: UnsafePointer(pointer), end: UnsafePointer(end), encoding: encoding)
}

private func buildCalloutArguments(_ args: OpaquePointer) -> [OnigurumaCalloutArgument] {
    let count = Int(onig_get_args_num_by_callout_args(args))
    guard count > 0 else {
        return []
    }

    return (0..<count).compactMap { index in
        var type = OnigType(rawValue: 0)
        var value = OnigValue()
        guard onig_get_arg_by_callout_args(args, Int32(index), &type, &value) == ONIG_NORMAL else {
            return nil
        }

        switch type.rawValue {
        case ONIG_TYPE_LONG.rawValue:
            return .long(Int(value.l))
        case ONIG_TYPE_CHAR.rawValue:
            return .codePoint(value.c)
        case ONIG_TYPE_STRING.rawValue:
            return .string(decodeCalloutBytes(start: value.s.start, end: value.s.end, encoding: Encoding(rawValue: get_onig_utf8())) ?? "")
        case ONIG_TYPE_POINTER.rawValue:
            return .pointer(UInt(bitPattern: value.p))
        case ONIG_TYPE_TAG.rawValue:
            return .tag(Int(value.tag))
        default:
            return nil
        }
    }
}

private func buildCalloutContext(args: OpaquePointer) -> OnigurumaCalloutContext {
    let regex = onig_get_regex_by_callout_args(args)
    let encoding = Encoding(rawValue: onig_get_encoding(regex))
    let stringStart = onig_get_string_by_callout_args(args)!
    let start = onig_get_start_by_callout_args(args)!
    let current = onig_get_current_by_callout_args(args)!
    let rightRange = onig_get_right_range_by_callout_args(args)!

    let calloutName: String? = {
        let nameID = onig_get_name_id_by_callout_args(args)
        guard nameID != ONIG_NON_NAME_ID else {
            return nil
        }
        return decodeCalloutCString(onig_get_callout_name_by_name_id(nameID), encoding: encoding)
    }()

    let captures = (0...Int(onig_number_of_captures(regex))).map { group -> Range<Int>? in
        var begin = Int32()
        var end = Int32()
        guard onig_get_capture_range_in_callout(args, Int32(group), &begin, &end) == ONIG_NORMAL,
              begin >= 0,
              end >= 0 else {
            return nil
        }
        return Int(begin)..<Int(end)
    }

    let phase: OnigurumaCalloutPhase = onig_get_callout_in_by_callout_args(args) == ONIG_CALLOUT_IN_RETRACTION ? .retraction : .progress
    return OnigurumaCalloutContext(
        phase: phase,
        name: calloutName,
        contents: decodeCalloutBytes(start: onig_get_contents_by_callout_args(args), end: onig_get_contents_end_by_callout_args(args), encoding: encoding),
        currentOffset: stringStart.distance(to: current),
        startOffset: stringStart.distance(to: start),
        searchRangeUpperBound: stringStart.distance(to: rightRange),
        retryCount: UInt(onig_get_retry_counter_by_callout_args(args)),
        captureRanges: captures,
        arguments: buildCalloutArguments(args)
    )
}

private func resolveCalloutHandler(for context: OnigurumaCalloutContext, state: MatchConfigurationCalloutState?) -> OnigurumaCalloutHandler? {
    if let name = context.name, let handler = OnigurumaCalloutRegistry.handler(named: name) {
        return handler
    }

    switch context.phase {
    case .progress:
        return state?.progressHandler
    case .retraction:
        return state?.retractionHandler
    }
}

internal func onigurumaCalloutCallback(_ args: OpaquePointer?, _ userData: UnsafeMutableRawPointer?) -> Int32 {
    guard let args else {
        return OnigurumaCalloutAction.fail.rawValue
    }

    let state = userData.map { Unmanaged<MatchConfigurationCalloutState>.fromOpaque($0).takeUnretainedValue() }
    let context = buildCalloutContext(args: args)
    let action = resolveCalloutHandler(for: context, state: state)?(context) ?? .continue
    return action.rawValue
}
