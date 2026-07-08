import OurWishServer

let port = WishServer.defaultPort
print("Starting OurWish server on http://0.0.0.0:\(port) ...")
try await WishServer().run(port: port)
