import COnig

/**
 Get the oniguruma library version string.
 */
func version() -> String {
    return String(cString: onig_version())
}

/**
 Get the oniguruma library copyright string.
 */
func copyright() -> String {
    return String(cString: onig_copyright())
}

/**
 Call oniguruma functions.
 - Parameters:
    - body: The closure calling oniguruma library functions
 - Throws:
    `OnigError` if `body` returns code not in following normal return codes:
    [`ONIG_NORMAL`, `ONIG_MISMATCH`, ``ONIG_NO_SUPPORT_CONFIG`, `ONIG_ABORT`]
 */
internal func callOnigFunction(_ body: () throws -> Int32) throws -> Int32 {
    let result = try body()
    switch result {
    case ONIG_NORMAL, ONIG_MISMATCH, ONIG_NO_SUPPORT_CONFIG, ONIG_ABORT:
        return result
    default:
        throw OnigError(result)
    }
}
