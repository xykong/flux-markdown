import Foundation

extension Notification.Name {
    static let toggleSearch = Notification.Name("toggleSearch")
    static let exportHTML   = Notification.Name("exportHTML")
    static let exportPDF    = Notification.Name("exportPDF")
    static let toggleHelp   = Notification.Name("toggleHelp")
    static let zoomIn       = Notification.Name("zoomIn")
    static let zoomOut      = Notification.Name("zoomOut")
    static let resetZoom    = Notification.Name("resetZoom")
    static let reloadFile   = Notification.Name("reloadFile")
    static let reloadFileSucceeded = Notification.Name("reloadFileSucceeded")
    static let reloadFileFailed    = Notification.Name("reloadFileFailed")
    static let resetZoomCompleted  = Notification.Name("resetZoomCompleted")
    static let openInExternalEditor = Notification.Name("openInExternalEditor")
}
