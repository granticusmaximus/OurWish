import Testing
@testable import OurWishCore

struct PasswordHasherTests {
    @Test func verifySucceedsForCorrectPassword() {
        let hash = PasswordHasher.hash("Wats#0529")
        #expect(PasswordHasher.verify("Wats#0529", against: hash))
    }

    @Test func verifyFailsForWrongPassword() {
        let hash = PasswordHasher.hash("Wats#0529")
        #expect(!PasswordHasher.verify("wrong-password", against: hash))
    }

    @Test func hashesAreSaltedDifferently() {
        let first = PasswordHasher.hash("same-password")
        let second = PasswordHasher.hash("same-password")
        #expect(first != second, "each hash call should use a fresh random salt")
        #expect(PasswordHasher.verify("same-password", against: first))
        #expect(PasswordHasher.verify("same-password", against: second))
    }

    @Test func verifyFailsForMalformedStoredValue() {
        #expect(!PasswordHasher.verify("anything", against: "not-a-real-hash"))
    }
}
