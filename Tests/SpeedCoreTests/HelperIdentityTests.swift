import Foundation
import HelperIPC
import Security
import Testing

struct HelperIdentityTests {
    @Test func productionRequirementsCompileWithTheSystemParser() {
        for text in [HelperIdentity.serviceRequirement, HelperIdentity.clientRequirement] {
            var requirement: SecRequirement?
            #expect(SecRequirementCreateWithString(text as CFString, [], &requirement) == errSecSuccess)
            #expect(requirement != nil)
        }
    }

    @Test func rejectsAnUnrelatedSignedApplication() throws {
        var code: SecStaticCode?
        let url = URL(fileURLWithPath: "/usr/bin/true")
        #expect(SecStaticCodeCreateWithPath(url as CFURL, [], &code) == errSecSuccess)
        let executable = try #require(code)
        for text in [HelperIdentity.serviceRequirement, HelperIdentity.clientRequirement] {
            var requirement: SecRequirement?
            #expect(SecRequirementCreateWithString(text as CFString, [], &requirement) == errSecSuccess)
            #expect(SecStaticCodeCheckValidity(executable, [], try #require(requirement)) != errSecSuccess)
        }
    }
}
