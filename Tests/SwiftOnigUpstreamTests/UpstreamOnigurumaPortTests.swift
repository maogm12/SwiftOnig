@_spi(Experimental) import Testing
import SwiftOnig

@Suite("Full Upstream Oniguruma Ports", .serialized)
struct UpstreamOnigurumaPortTests {
    @Test("test_utf8.c")
    func utf8() async throws {
        let cases = try await UpstreamOnigurumaSupport.loadUTF8Suite()
        await UpstreamOnigurumaSupport.verifyRegexSuite(cases)
    }

    @Test("test_options.c")
    func options() async throws {
        let cases = try await UpstreamOnigurumaSupport.loadOptionsSuite()
        await UpstreamOnigurumaSupport.verifyRegexSuite(cases)
    }

    @Test("test_back.c")
    func back() async throws {
        let cases = try await UpstreamOnigurumaSupport.loadBackSuite()
        await UpstreamOnigurumaSupport.verifyRegexSuite(cases)
    }

    @Test("testc.c")
    func nativeC() async throws {
        let cases = try await UpstreamOnigurumaSupport.loadCTestSuite()
        await UpstreamOnigurumaSupport.verifyRegexSuite(cases)
    }

    @Test("testu.c")
    func utf16() async throws {
        let cases = try await UpstreamOnigurumaSupport.loadUTF16Suite()
        await UpstreamOnigurumaSupport.verifyRegexSuite(cases)
    }

    @Test("test_syntax.c")
    func syntax() async throws {
        let cases = try await UpstreamOnigurumaSupport.loadSyntaxSuite()
        await UpstreamOnigurumaSupport.verifyRegexSuite(cases)
    }

    @Test("test_regset.c")
    func regset() async throws {
        let cases = try await UpstreamOnigurumaSupport.loadRegsetSuite()
        await UpstreamOnigurumaSupport.verifyRegsetSuite(cases)
    }
}
