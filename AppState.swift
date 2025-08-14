import Foundation
import WebKit
import SwiftUI

enum GoogleService: String, CaseIterable, Identifiable {
    case gmail
    case docs
    case sheets
    case slides
    case forms
    case drive

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .gmail: return "Gmail"
        case .docs: return "Docs"
        case .sheets: return "Sheets"
        case .slides: return "Slides"
        case .forms: return "Forms"
        case .drive: return "Drive"
        }
    }

    var symbolName: String {
        switch self {
        case .gmail: return "envelope.fill"
        case .docs: return "doc.text.fill"
        case .sheets: return "tablecells.fill"
        case .slides: return "rectangle.fill"
        case .forms: return "checkmark.square.fill"
        case .drive: return "externaldrive.fill"
        }
    }

    var tintColor: Color {
        switch self {
        case .gmail: return .red
        case .docs: return .blue
        case .sheets: return .green
        case .slides: return .yellow
        case .forms: return .purple
        case .drive: return .teal
        }
    }

    var url: URL {
        switch self {
        case .gmail: return URL(string: "https://mail.google.com/")!
        case .docs: return URL(string: "https://docs.google.com/document/u/0/")!
        case .sheets: return URL(string: "https://docs.google.com/spreadsheets/u/0/")!
        case .slides: return URL(string: "https://docs.google.com/presentation/u/0/")!
        case .forms: return URL(string: "https://docs.google.com/forms/u/0/")!
        case .drive: return URL(string: "https://drive.google.com/drive/u/0/")!
        }
    }
}

final class AppState: ObservableObject {
    @Published var selectedService: GoogleService = .gmail
    @Published var isLoggedIn: Bool = false
    @Published var showingMenu: Bool = true

    func refreshLoginStatus(completion: (() -> Void)? = nil) {
        WKWebsiteDataStore.default().httpCookieStore.getAllCookies { cookies in
            let loggedIn = cookies.contains { $0.domain.contains("google.com") && ($0.expiresDate ?? Date.distantFuture) > Date() }
            DispatchQueue.main.async {
                self.isLoggedIn = loggedIn
                completion?()
            }
        }
    }
}


