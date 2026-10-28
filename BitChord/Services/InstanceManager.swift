import Foundation

/// Manages active and fallback Invidious API server endpoints.
/// Evaluates node availability and saves the user-selected instance in UserDefaults.
@MainActor
final class InstanceManager: ObservableObject {
    static let shared = InstanceManager()
    
    /// The primary instance currently used for search and audio extraction.
    @Published var activeInstance: String
    
    /// Cached list of public HTTPS instances supporting API calls.
    @Published var availableInstances: [String] = AppConstants.defaultInstances
    
    /// True while querying the remote instances directory.
    @Published var isCheckingHealth: Bool = false
    
    private init() {
        let saved = UserDefaults.standard.string(forKey: AppConstants.StorageKey.selectedInstance)
        self.activeInstance = saved ?? AppConstants.defaultInstances[0]
    }
    
    /// Updates the active instance and strips any trailing slashes.
    func setInstance(_ urlString: String) {
        var cleanURL = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanURL.hasSuffix("/") {
            cleanURL.removeLast()
        }
        self.activeInstance = cleanURL
        UserDefaults.standard.set(cleanURL, forKey: AppConstants.StorageKey.selectedInstance)
    }
    
    /// Fetches the live Invidious instance directory, filters for operational HTTPS endpoints,
    /// and populates the available instances list.
    func refreshInstances() async {
        self.isCheckingHealth = true
        
        guard let url = URL(string: AppConstants.instancesListURL) else {
            self.isCheckingHealth = false
            return
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                self.isCheckingHealth = false
                return
            }
            
            if let json = try JSONSerialization.jsonObject(with: data) as? [[Any]] {
                var valid: [String] = []
                for entry in json {
                    if entry.count >= 2,
                       let host = entry[0] as? String,
                       let meta = entry[1] as? [String: Any],
                       let api = meta["api"] as? Bool, api == true,
                       let type = meta["type"] as? String, type == "https" {
                        valid.append("https://\(host)")
                    }
                }
                
                if !valid.isEmpty {
                    self.availableInstances = valid
                    if !valid.contains(self.activeInstance) {
                        self.setInstance(valid[0])
                    }
                    self.isCheckingHealth = false
                    return
                }
            }
        } catch {
            // Keep default instances on failure
        }
        
        self.isCheckingHealth = false
    }
}
