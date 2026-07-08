import Foundation
import OurWishServer

let environment = ProcessInfo.processInfo.environment
let port = Int(environment["OURWISH_PORT"] ?? "") ?? WishServer.defaultPort
print("Starting OurWish server on http://0.0.0.0:\(port) ...")
try await WishServer().run(port: port)
