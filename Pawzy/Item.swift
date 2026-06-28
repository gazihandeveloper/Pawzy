//
//  Item.swift
//  Pawzy
//
//  Created by Mahmut Gazihan Arslan on 28.06.2026.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
