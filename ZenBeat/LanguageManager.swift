//
//  LanguageManager.swift
//  ZenBeat
//
//  Manages app language selection
//

import Foundation
import SwiftUI
import Combine

enum AppLanguage: String, CaseIterable, Identifiable {
    case system = "system"
    case english = "en"
    case chinese = "zh-Hans"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .system: return "System"
        case .english: return "English"
        case .chinese: return "中文"
        }
    }
    
    var bundle: Bundle {
        if self == .system {
            return .main
        }
        guard let path = Bundle.main.path(forResource: rawValue, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return .main
        }
        return bundle
    }
}

class LanguageManager: ObservableObject {
    static let shared = LanguageManager()
    
    private let defaults = UserDefaults.standard
    private let languageKey = "appLanguage"
    
    @Published var currentLanguage: AppLanguage {
        didSet {
            defaults.set(currentLanguage.rawValue, forKey: languageKey)
        }
    }
    
    var bundle: Bundle {
        if currentLanguage == .system {
            // Use system preferred language
            if let preferred = Locale.preferredLanguages.first {
                if preferred.starts(with: "zh") {
                    return AppLanguage.chinese.bundle
                }
            }
            return AppLanguage.english.bundle
        }
        return currentLanguage.bundle
    }
    
    private init() {
        let savedRawValue = UserDefaults.standard.string(forKey: "appLanguage") ?? "system"
        self.currentLanguage = AppLanguage(rawValue: savedRawValue) ?? .system
    }
    
    func localizedString(_ key: String) -> String {
        return NSLocalizedString(key, bundle: bundle, comment: "")
    }
}
