import Foundation
import WebKit

/// Files the page saves: a movie's Download link (/api/media/:id?download=1, which answers with
/// Content-Disposition: attachment), a photo, a zip of an album. WebKit hands the transfer to us
/// (WKDownload) and the file lands in the app's Documents folder, which the Files app shows as
/// "On My iPhone → Cinewave" (UIFileSharingEnabled + LSSupportsOpeningDocumentsInPlace in
/// Info.plist). The page's own Downloads sheet still works: the server counts the bytes it
/// sends for each ?dl= token, whoever receives them.
final class Downloads: NSObject, WKDownloadDelegate {

    private var files: [ObjectIdentifier: URL] = [:]

    static var folder: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    func download(_ download: WKDownload, decideDestinationUsing response: URLResponse, suggestedFilename: String,
                  completionHandler: @escaping (URL?) -> Void) {
        let dir = Self.folder
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        // A second copy of the same file gets " 2", " 3"… because WebKit refuses to overwrite.
        let name = suggestedFilename.isEmpty ? "download" : suggestedFilename
        let base = (name as NSString).deletingPathExtension
        let ext = (name as NSString).pathExtension
        var url = dir.appendingPathComponent(name)
        var n = 2
        while FileManager.default.fileExists(atPath: url.path) {
            url = dir.appendingPathComponent(ext.isEmpty ? "\(base) \(n)" : "\(base) \(n).\(ext)")
            n += 1
        }
        files[ObjectIdentifier(download)] = url
        completionHandler(url)
    }

    func downloadDidFinish(_ download: WKDownload) {
        files.removeValue(forKey: ObjectIdentifier(download))
    }

    func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
        if let url = files.removeValue(forKey: ObjectIdentifier(download)) {
            try? FileManager.default.removeItem(at: url) // a half file would look like a movie
        }
        print("download failed: \(error.localizedDescription)")
    }
}
