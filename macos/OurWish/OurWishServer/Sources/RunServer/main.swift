import Foundation
import OurWishCore
import OurWishServer

let arguments = CommandLine.arguments

// `swift run RunServer reset-password <email> <newPassword>` stands in for a "forgot
// password" flow — this app has no email infrastructure, so recovery is "ask whoever
// runs the server to reset it for you" via this command instead of a token-based email
// reset. See `UserRepository.resetPassword`.
if arguments.count >= 4, arguments[1] == "reset-password" {
    let email = arguments[2]
    let newPassword = arguments[3]
    do {
        let repository = UserRepository(dbWriter: DatabaseManager.shared)
        try repository.resetPassword(email: email, newPassword: newPassword)
        print("Password reset for \(email)")
    } catch {
        print("Failed to reset password: \(error)")
        exit(1)
    }
    exit(0)
}

let environment = ProcessInfo.processInfo.environment
let port = Int(environment["OURWISH_PORT"] ?? "") ?? WishServer.defaultPort
print("Starting OurWish server on http://0.0.0.0:\(port) ...")
try await WishServer().run(port: port)
