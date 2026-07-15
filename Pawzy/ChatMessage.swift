//
//  ChatMessage.swift
//  Pawzy
//
//  SwiftData Model — Pawzy AI sohbet mesajı
//

import Foundation
import SwiftData

@Model
final class ChatMessage {
    var id: UUID = UUID()
    var role: String = ""    // "user", "assistant", "system"
    var content: String = ""
    var timestamp: Date = Date()
    var petName: String? // Hangi pet için konuşuldu (nil = genel)

    init(id: UUID = UUID(), role: String, content: String, timestamp: Date = Date(), petName: String? = nil) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.petName = petName
    }
}
