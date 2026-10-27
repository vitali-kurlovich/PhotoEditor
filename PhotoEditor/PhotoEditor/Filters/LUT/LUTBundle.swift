//
//  Created by Kurlovich Vitali on 9/19/26.
//

import Foundation

nonisolated enum LUTBundle {
    private static var fileNames: [String] {
        [
            "PGS _ Neon City _ 01",
            "PGS _ Neon City _ 02",
            "PGS _ Neon City _ 03",
            "PGS _ Neon City _ 04",
            "PGS _ Neon City _ 05",

            "Film Color Grading LUTs Pack V2#001",
            "Film Color Grading LUTs Pack V2#002",
            "Film Color Grading LUTs Pack V2#003",
            "Film Color Grading LUTs Pack V2#004",
            "Film Color Grading LUTs Pack V2#005",
        ]
    }

    static var fileURLs: [URL] {
        fileNames.compactMap {
            Bundle.main.url(
                forResource: $0,
                withExtension: "cube"
            )
        }
    }
}
