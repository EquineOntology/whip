//
//  Item.swift
//  whip
//
//  Created by Christian Fratta on 23.08.24.
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
