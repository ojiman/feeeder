import Foundation

/// The product's name where it is written into requests, files and prompts (decision 0023).
/// The names have no spaces so they are safe in file names and in the User-Agent header.
public enum AppIdentity {
    public static let productName = "Unagi Reader"
    public static let userAgentToken = "UnagiReader"
    public static let dataFolderName = "UnagiReader"
    public static let reviewFileName = "UnagiReader-review.txt"
    public static let reviewPartPrefix = "UnagiReader-review-part-"
}
