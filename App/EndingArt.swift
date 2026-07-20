import MyBossCore

/// One illustration per ending family, shared by the end screen, the share
/// card, and the notebook.
enum EndingArt {
    static func image(for ending: Ending) -> String {
        switch ending.id {
        case "employee_of_the_century", "burnout_speedrun": "ending_human"
        case "corporate_singularity", "robots_with_feelings": "ending_ai"
        default: "ending_hybrid"
        }
    }
}
