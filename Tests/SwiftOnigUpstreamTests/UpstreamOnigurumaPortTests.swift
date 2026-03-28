@_spi(Experimental) import Testing
import SwiftOnig

@Suite("Full Upstream Oniguruma Ports", .serialized)
struct UpstreamOnigurumaPortTests {
    @Test("test_utf8.c")
    func utf8() async throws {
        let cases = try UpstreamOnigurumaSupport.loadUTF8Suite()
        UpstreamOnigurumaSupport.verifyRegexSuite(cases)
    }

    @Test("test_options.c")
    func options() async throws {
        let cases = try UpstreamOnigurumaSupport.loadOptionsSuite()
        UpstreamOnigurumaSupport.verifyRegexSuite(cases)
    }

    @Test("test_back.c")
    func back() async throws {
        let cases = try UpstreamOnigurumaSupport.loadBackSuite()
        UpstreamOnigurumaSupport.verifyRegexSuite(cases)
    }

    @Test("testc.c")
    func nativeC() async throws {
        let cases = try UpstreamOnigurumaSupport.loadCTestSuite()
        UpstreamOnigurumaSupport.verifyRegexSuite(cases)
    }

    @Test("testu.c")
    func utf16() async throws {
        let cases = try UpstreamOnigurumaSupport.loadUTF16Suite()
        UpstreamOnigurumaSupport.verifyRegexSuite(cases)
    }

    @Test("test_syntax.c")
    func syntax() async throws {
        let cases = try UpstreamOnigurumaSupport.loadSyntaxSuite()
        UpstreamOnigurumaSupport.verifyRegexSuite(cases)
    }

    @Test("test_regset.c")
    func regset() async throws {
        let cases = try UpstreamOnigurumaSupport.loadRegsetSuite()
        UpstreamOnigurumaSupport.verifyRegsetSuite(cases)
    }
}
