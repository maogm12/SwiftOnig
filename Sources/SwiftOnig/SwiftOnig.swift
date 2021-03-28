import COnig

func Version() -> String {
    return String(cString: onig_version())
}

func Copyright() -> String {
    return String(cString: onig_copyright())
}
