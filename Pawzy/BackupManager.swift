//
//  BackupManager.swift
//  Pawzy
//
//  iCloud yedekleme / geri yükleme servisi
//

import Foundation
import SwiftData
import CryptoKit
import Security

// MARK: - Backup Structs

struct BackupData: Codable {
    let version: Int
    let exportDate: Date
    let pets: [PetBackup]
    let medications: [MedicationBackup]
    let cabinetItems: [CabinetItemBackup]
    let chatMessages: [ChatMessageBackup]
}

struct PetBackup: Codable {
    let name: String
    let breed: String
    let age: Int
    let weight: Double
    let sex: String
    let tintColor: String
    let iconName: String
    let activityLevel: String
}

struct MedicationBackup: Codable {
    let name: String
    let dose: String
    let time: Date
    let category: String
    let iconName: String
    let colorHex: String
    let isDone: Bool
    let petName: String
    let frequency: String
}

struct CabinetItemBackup: Codable {
    let name: String
    let category: String
    let iconName: String
    let colorHex: String
    let stock: Int
    let stockLabel: String
    let isLowStock: Bool
}

struct ChatMessageBackup: Codable {
    let id: UUID
    let role: String
    let content: String
    let timestamp: Date
    let petName: String?
}

// MARK: - Backup Error

enum BackupError: Error, LocalizedError {
    case encodingFailed
    case noData
    case decodingFailed
    case cloudNotAvailable
    case saveFailed(String)
    case loadFailed(String)
    case encryptionFailed
    case decryptionFailed

    var errorDescription: String? {
        switch self {
        case .encodingFailed: return L.string("Veri kodlanamadı")
        case .noData: return L.string("Yedek verisi boş")
        case .decodingFailed: return L.string("Yedek dosyası okunamadı")
        case .cloudNotAvailable: return L.string("iCloud Drive kullanılamıyor")
        case .saveFailed(let msg): return L.string("Kaydetme hatası:") + " \(msg)"
        case .loadFailed(let msg): return L.string("Yükleme hatası:") + " \(msg)"
        case .encryptionFailed: return L.string("Yedekleme şifreleme hatası")
        case .decryptionFailed: return L.string("Yedek çözme hatası")
        }
    }
}

// MARK: - BackupManager

class BackupManager {

    static let shared = BackupManager()

    // MARK: - Encryption Key
    private let encryptionKey: SymmetricKey

    private init() {
        self.encryptionKey = Self.getOrCreateKey()
    }
    
    deinit {
        #if DEBUG
        print("🗑️ BackupManager deinit")
        #endif
    }

    // MARK: - Keychain Key Management

    private static func getOrCreateKey() -> SymmetricKey {
        let tag = "com.mahmutgazihan.Pawzy.backupEncryptionKey".data(using: .utf8)!

        // Keychain'den var olan anahtarı al
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: tag,
            kSecReturnData as String: true
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        if status == errSecSuccess, let data = item as? Data {
            return SymmetricKey(data: data)
        }

        // Anahtar yok, yeni oluştur
        let newKey = SymmetricKey(size: .bits256)
        let keyData = newKey.withUnsafeBytes { Data($0) }

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: tag,
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        // Eski anahtar varsa sil
        SecItemDelete(query as CFDictionary)
        SecItemAdd(addQuery as CFDictionary, nil)

        return newKey
    }

    private let backupFileName = "Pawzy_Backup.json"

    private var cloudURL: URL? {
        FileManager.default.url(forUbiquityContainerIdentifier: nil)?.appendingPathComponent(backupFileName)
    }

    // MARK: - Export

    func exportBackup(
        pets: [Pet],
        medications: [Medication],
        cabinetItems: [MedicationCabinetItem],
        chatMessages: [ChatMessage]
    ) throws -> Data {
        let backup = BackupData(
            version: 1,
            exportDate: Date(),
            pets: pets.map {
                PetBackup(
                    name: $0.name,
                    breed: $0.breed,
                    age: $0.age,
                    weight: $0.weight,
                    sex: $0.sex,
                    tintColor: $0.tintColor,
                    iconName: $0.iconName,
                    activityLevel: $0.activityLevel
                )
            },
            medications: medications.map {
                MedicationBackup(
                    name: $0.name,
                    dose: $0.dose,
                    time: $0.time,
                    category: $0.category,
                    iconName: $0.iconName,
                    colorHex: $0.colorHex,
                    isDone: $0.isDone,
                    petName: $0.petName,
                    frequency: $0.frequency
                )
            },
            cabinetItems: cabinetItems.map {
                CabinetItemBackup(
                    name: $0.name,
                    category: $0.category,
                    iconName: $0.iconName,
                    colorHex: $0.colorHex,
                    stock: $0.stock,
                    stockLabel: $0.stockLabel,
                    isLowStock: $0.isLowStock
                )
            },
            chatMessages: chatMessages.map {
                ChatMessageBackup(
                    id: $0.id,
                    role: $0.role,
                    content: $0.content,
                    timestamp: $0.timestamp,
                    petName: $0.petName
                )
            }
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted

        guard let data = try? encoder.encode(backup) else {
            throw BackupError.encodingFailed
        }
        return data
    }

    // MARK: - iCloud Save

    func saveToCloud(data: Data) async throws {
        guard let cloudURL = cloudURL else {
            throw BackupError.cloudNotAvailable
        }

        // Veriyi AES-GCM ile şifrele
        let sealedBox: AES.GCM.SealedBox
        do {
            sealedBox = try AES.GCM.seal(data, using: encryptionKey)
        } catch {
            throw BackupError.encryptionFailed
        }

        guard let encryptedData = sealedBox.combined else {
            throw BackupError.encryptionFailed
        }

        let containerDir = cloudURL.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: containerDir.path) {
            try FileManager.default.createDirectory(at: containerDir, withIntermediateDirectories: true)
        }

        do {
            try encryptedData.write(to: cloudURL, options: [.atomic])
        } catch {
            throw BackupError.saveFailed(error.localizedDescription)
        }
    }

    // MARK: - iCloud Load

    func loadFromCloud() async throws -> Data {
        guard let cloudURL = cloudURL else {
            throw BackupError.cloudNotAvailable
        }

        guard FileManager.default.fileExists(atPath: cloudURL.path) else {
            throw BackupError.loadFailed(L.string("iCloud'da yedek bulunamadı"))
        }

        let encryptedData: Data
        do {
            encryptedData = try Data(contentsOf: cloudURL)
        } catch {
            throw BackupError.loadFailed(error.localizedDescription)
        }

        // AES-GCM ile şifreyi çöz
        do {
            let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
            return try AES.GCM.open(sealedBox, using: encryptionKey)
        } catch {
            throw BackupError.decryptionFailed
        }
    }

    // MARK: - Import

    func importBackup(data: Data, modelContext: ModelContext) throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        guard let backup = try? decoder.decode(BackupData.self, from: data) else {
            throw BackupError.decodingFailed
        }

        // Tüm mevcut verileri temizle
        let allPets = try modelContext.fetch(FetchDescriptor<Pet>())
        allPets.forEach { modelContext.delete($0) }

        let allMeds = try modelContext.fetch(FetchDescriptor<Medication>())
        allMeds.forEach { modelContext.delete($0) }

        let allCabinet = try modelContext.fetch(FetchDescriptor<MedicationCabinetItem>())
        allCabinet.forEach { modelContext.delete($0) }

        let allChat = try modelContext.fetch(FetchDescriptor<ChatMessage>())
        allChat.forEach { modelContext.delete($0) }

        // Pet'leri import et
        for petBackup in backup.pets {
            let pet = Pet(
                name: petBackup.name,
                breed: petBackup.breed,
                age: petBackup.age,
                weight: petBackup.weight,
                sex: petBackup.sex,
                tintColor: petBackup.tintColor,
                iconName: petBackup.iconName
            )
            pet.activityLevel = petBackup.activityLevel
            modelContext.insert(pet)
        }

        // Medication'ları import et
        for medBackup in backup.medications {
            let med = Medication(
                name: medBackup.name,
                dose: medBackup.dose,
                time: medBackup.time,
                category: medBackup.category,
                iconName: medBackup.iconName,
                colorHex: medBackup.colorHex,
                isDone: medBackup.isDone,
                petName: medBackup.petName,
                frequency: medBackup.frequency
            )
            modelContext.insert(med)
        }

        // CabinetItem'ları import et
        for itemBackup in backup.cabinetItems {
            let item = MedicationCabinetItem(
                name: itemBackup.name,
                category: itemBackup.category,
                iconName: itemBackup.iconName,
                colorHex: itemBackup.colorHex,
                stock: itemBackup.stock,
                stockLabel: itemBackup.stockLabel,
                isLowStock: itemBackup.isLowStock
            )
            modelContext.insert(item)
        }

        // ChatMessage'ları import et
        for msgBackup in backup.chatMessages {
            let msg = ChatMessage(
                id: msgBackup.id,
                role: msgBackup.role,
                content: msgBackup.content,
                timestamp: msgBackup.timestamp,
                petName: msgBackup.petName
            )
            modelContext.insert(msg)
        }

        try modelContext.save()
    }
}
