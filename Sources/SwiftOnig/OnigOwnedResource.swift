internal protocol OnigOwnedResource: AnyObject {
    associatedtype RawResource

    var rawValue: RawResource! { get set }

    func releaseRawValue(_ rawValue: RawResource)
}

extension OnigOwnedResource {
    internal func cleanUpRawValue() {
        if let rawValue {
            releaseRawValue(rawValue)
            self.rawValue = nil
        }
    }
}
