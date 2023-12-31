import Foundation
/**
 The class with some file operation, which are needs in the app.
 */
class FileOperations {

    /**
     Create the given directory if it not exists
     
     - Parameter directoryName: The Name of the directory
     */
    class func createDirectory(_ folderName: String) throws {
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: folderName) {
            try fileManager.createDirectory(atPath: folderName, withIntermediateDirectories: true, attributes: nil)
        }
    }
}
