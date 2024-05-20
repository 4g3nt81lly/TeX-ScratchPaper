import Cocoa

@MainActor
final class Image2TexEngine {
    
    enum ConversionError: Error {
        case networkError(String)
        case dataError(String)
    }
    
    static let shared = Image2TexEngine()
    
    private static let serverURL = URL(string: "http://35.209.254.36:80")!
    
    private var request: URLRequest = {
        var request = URLRequest(url: serverURL)
        request.httpMethod = "POST"
        return request
    }()
    
    private init() {}
    
    private func convertFileData(fieldName: String, fileName: String, mimeType: String, fileData: Data,
                                 boundary: String) -> Data {
        let data = NSMutableData()
        data.append("--\(boundary)\r\n")
        data.append("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(fileName)\"\r\n")
        data.append("Content-Type: \(mimeType)\r\n\r\n")
        data.append(fileData)
        data.append("\r\n")
        return data as Data
    }
    
    func getTexString(from image: NSImage) async throws -> String {
        let uuid = UUID().uuidString
        let boundary = "Boundary-\(uuid)"
        
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let httpBody = NSMutableData()
        let imageData = convertFileData(
            fieldName: "image", fileName: "tex.png", mimeType: "image/png",
            fileData: image.tiffRepresentation!.base64EncodedData(), boundary: boundary
        )
        httpBody.append(imageData)
        httpBody.append("--\(boundary)--")
        request.httpBody = httpBody as Data
        
        let (data, response) = try await URLSession.shared.data(for: request)
        let httpResponse = response as! HTTPURLResponse
        guard (httpResponse.statusCode == 200) else {
            throw ConversionError.networkError("The server responded with status code: \(httpResponse.statusCode).")
        }
        guard let texString = String(data: data, encoding: .utf8) else {
            throw ConversionError.dataError("Invalid data: corrupted or incorrect encoding.")
        }
        return texString
    }
    
}

fileprivate extension NSMutableData {
    
    func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
    
}
