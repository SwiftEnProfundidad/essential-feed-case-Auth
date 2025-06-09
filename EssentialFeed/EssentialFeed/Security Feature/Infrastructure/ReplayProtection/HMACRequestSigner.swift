import CryptoKit
import Foundation

public final class HMACRequestSigner: RequestSigner {
    private let secretKey: SymmetricKey

    public init(secretKey: Data) {
        self.secretKey = SymmetricKey(data: secretKey)
    }

    public func signRequest(_ request: URLRequest, with nonce: String, timestamp: Int64) async throws -> URLRequest {
        guard let url = request.url,
              let httpMethod = request.httpMethod
        else {
            throw SigningError.invalidRequest
        }

        let bodyData = request.httpBody ?? Data()
        let message = "\(httpMethod)|\(url.path)|\(nonce)|\(timestamp)|\(bodyData.base64EncodedString())"

        let signature = HMAC<SHA256>.authenticationCode(for: Data(message.utf8), using: secretKey)
        let signatureString = Data(signature).base64EncodedString()

        var signedRequest = request
        signedRequest.setValue(nonce, forHTTPHeaderField: "X-Nonce")
        signedRequest.setValue(String(timestamp), forHTTPHeaderField: "X-Timestamp")
        signedRequest.setValue(signatureString, forHTTPHeaderField: "X-Signature")

        return signedRequest
    }

    public enum SigningError: Error, Equatable {
        case invalidRequest
    }
}
