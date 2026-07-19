import Foundation

/// The school of hard knocks: every provocation that ever beat you is
/// remembered, and from then on the right comeback is marked with a ★.
/// Monkey Island taught us that losing duels is how you learn to win them.
enum ComebackSchool {
    private static let key = "learnedProvocations"

    static func learn(_ provocation: String) {
        var learned = Set(UserDefaults.standard.stringArray(forKey: key) ?? [])
        learned.insert(provocation)
        UserDefaults.standard.set(Array(learned).sorted(), forKey: key)
    }

    static func hasLearned(_ provocation: String) -> Bool {
        (UserDefaults.standard.stringArray(forKey: key) ?? []).contains(provocation)
    }
}
