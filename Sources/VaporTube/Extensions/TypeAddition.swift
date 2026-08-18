import Vapor
import Cryptos

extension Data: @retroactive AsyncResponseEncodable {}
extension Data: @retroactive AsyncRequestDecodable {}
extension Data: @retroactive ResponseEncodable {}
extension Data: @retroactive RequestDecodable {}
extension Data: @retroactive Content {}


extension SendableSymmKey: @retroactive AsyncRequestDecodable {}
extension SendableSymmKey: @retroactive AsyncResponseEncodable {}
extension SendableSymmKey: @retroactive ResponseEncodable {}
extension SendableSymmKey: @retroactive RequestDecodable {}
extension SendableSymmKey: @retroactive Content {}


extension SendableAsymCPrivateKey: @retroactive AsyncResponseEncodable {}
extension SendableAsymCPrivateKey: @retroactive AsyncRequestDecodable {}
extension SendableAsymCPrivateKey: @retroactive ResponseEncodable {}
extension SendableAsymCPrivateKey: @retroactive RequestDecodable {}
extension SendableAsymCPrivateKey: @retroactive Content {}


extension SendableAsymCPublicKey: @retroactive AsyncResponseEncodable {}
extension SendableAsymCPublicKey: @retroactive AsyncRequestDecodable {}
extension SendableAsymCPublicKey: @retroactive ResponseEncodable {}
extension SendableAsymCPublicKey: @retroactive RequestDecodable {}
extension SendableAsymCPublicKey: @retroactive Content {}


extension SendableAsymSPrivateKey: @retroactive AsyncResponseEncodable {}
extension SendableAsymSPrivateKey: @retroactive AsyncRequestDecodable {}
extension SendableAsymSPrivateKey: @retroactive ResponseEncodable {}
extension SendableAsymSPrivateKey: @retroactive RequestDecodable {}
extension SendableAsymSPrivateKey: @retroactive Content {}


extension SendableAsymSPublicKey: @retroactive AsyncResponseEncodable {}
extension SendableAsymSPublicKey: @retroactive AsyncRequestDecodable {}
extension SendableAsymSPublicKey: @retroactive ResponseEncodable {}
extension SendableAsymSPublicKey: @retroactive RequestDecodable {}
extension SendableAsymSPublicKey: @retroactive Content {}

