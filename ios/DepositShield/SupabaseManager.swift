import Foundation
import Supabase

enum SupabaseConfig {
    /// Values come from `Secrets.plist` (gitignored). Copy
    /// `Secrets.example.plist` to `Secrets.plist` and fill in your Supabase
    /// project URL, anon key and the web app's base URL.
    private static let secrets: [String: String] = {
        guard let path = Bundle.main.path(forResource: "Secrets", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path) as? [String: String] else { return [:] }
        return dict
    }()

    static let url = URL(string: secrets["SUPABASE_URL"] ?? "") ?? URL(string: "https://placeholder.supabase.co")!
    static let anonKey = secrets["SUPABASE_ANON_KEY"] ?? ""

    /// The web app this native shell is a companion to. Used only for the
    /// bearer-token account-deletion endpoint (Settings) — never for a webview.
    static let webAppURL = URL(string: secrets["WEB_APP_URL"] ?? "") ?? URL(string: "http://localhost:3000")!
}

let supabase = SupabaseClient(supabaseURL: SupabaseConfig.url, supabaseKey: SupabaseConfig.anonKey)

enum FreeTier {
    static let photoLimit = 10
}
