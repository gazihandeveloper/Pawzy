//
//  DeepSeekService.swift
//  Pawzy
//
//  DeepSeek V4 Flash API — Evcil hayvan uzmanı chat
//

import Foundation

enum DeepSeekError: Error, LocalizedError {
    case invalidURL
    case noResponse
    case decodingError
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "API URL'si geçersiz"
        case .noResponse: return "Sunucudan yanıt alınamadı"
        case .decodingError: return "Yanıt çözümlenemedi"
        case .apiError(let msg): return msg
        }
    }
}

struct DeepSeekService {
    private static let apiKey = "sk-7f710d53f009458b885581618f498846"
    private static let baseURL = "https://api.deepseek.com/v1/chat/completions"
    private static let model = "deepseek-v4-flash"

    /// System prompt'u + pet context'ini oluştur, dile göre Türkçe veya İngilizce
    static func buildSystemPrompt(for pet: Pet?) -> String {
        let rawLang = UserDefaults.standard.string(forKey: "appLanguage") ?? "en"
        let lang = rawLang == "auto" ? "en" : rawLang

        if lang == "tr" {
            var prompt = """
Sen evcil hayvan bakımı konusunda yardımcı olan bir yapay zeka asistanısın. \
Kullanıcıların evcil hayvanlarıyla ilgili sorularına dostane, bilgilendirici ve güvenilir yanıtlar veriyorsun.
"""
            if let pet = pet {
                prompt += """

Kullanıcının evcil hayvanı:
- Ad: Kullanıcının evcil hayvanı
- Tür / Irk: \(pet.breed)
- Yaş: \(pet.age)
- Kilo: \(pet.weight) kg
- Cinsiyet: \(pet.sex)
"""
            }
            prompt += """

Kurallar:
1. Yanıtlarını her zaman kullanıcının evcil hayvan bilgilerini temel alarak kişiselleştir.
2. Eğer bir sağlık sorunu, hastalık belirtisi veya tedaviyle ilgili bir şey sorulursa mutlaka bir veterinere danışmalarını öner.
3. Yanıtının SONUNA şu ibareyi ekle:
"Bu bilgiler tıbbi tavsiye niteliği taşımaz, öneri amaçlıdır. Kesin tanı ve tedavi için veteriner hekiminize danışınız."
4. Samimi, sıcak ve profesyonel bir dil kullan.
5. Evcil hayvanın adını kullanarak kişiselleştir.
"""
            return prompt
        } else {
            var prompt = """
You are an AI assistant that helps with pet care. \
You provide friendly, informative, and reliable answers about users' pets.
"""
            if let pet = pet {
                prompt += """

User's pet:
- Name: User's pet
- Breed: \(pet.breed)
- Age: \(pet.age)
- Weight: \(pet.weight) kg
- Gender: \(pet.sex)
"""
            }
            prompt += """

Rules:
1. Always personalize your answers based on the pet's information.
2. If a health issue or symptom is mentioned, ALWAYS recommend consulting a veterinarian.
3. At the END of your response, add this note:
"This information is not medical advice, for informational purposes only. Consult your veterinarian for diagnosis and treatment."
4. Use a warm, friendly, and professional tone.
5. Use the pet's name to personalize responses.
"""
            return prompt
        }
    }

    /// Yanıt içeriğinde reçeteli ilaç ismi, dozaj telkini veya teşhis benzeri ifadeler var mı kontrol et
    private static func containsFlaggedMedicalContent(_ text: String) -> Bool {
        let lowercased = text.lowercased()
        let flaggedTerms = [
            // Turkish
            "teşhis", "tanısı", "tanı koy", "reçete", "dozaj", "doz ",
            "mg ", " ml ", "tablet", "kapsül", "hap", "şurup",
            "antibiyotik", "kortizon", "prednol", "prednisone",
            "ağrı kesici", "iltihap giderici",
            // English
            "diagnosis", "prescription", "dosage", "dose ",
            "tablet", "capsule", "pill", "syrup",
            "antibiotic", "prednisone", "cortisone", "ibuprofen",
            "painkiller", "anti-inflammatory"
        ]
        return flaggedTerms.contains(where: { lowercased.contains($0) })
    }

    static func sendMessage(messages: [[String: String]], pet: Pet?) async throws -> String {
        guard let url = URL(string: baseURL) else {
            throw DeepSeekError.invalidURL
        }

        var allMessages: [[String: String]] = []
        // System prompt'u en başa ekle
        allMessages.append(["role": "system", "content": buildSystemPrompt(for: pet)])
        // Kullanıcı mesajlarını ekle
        allMessages.append(contentsOf: messages)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30

        let body: [String: Any] = [
            "model": model,
            "messages": allMessages,
            "temperature": 0.7,
            "max_tokens": 1024
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw DeepSeekError.noResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            if let errorBody = String(data: data, encoding: .utf8) {
                throw DeepSeekError.apiError("API hatası (\(httpResponse.statusCode)): \(errorBody)")
            }
            throw DeepSeekError.apiError("API hatası (\(httpResponse.statusCode))")
        }

        struct APIResponse: Codable {
            struct Choice: Codable {
                struct Message: Codable {
                    let content: String
                }
                let message: Message
            }
            let choices: [Choice]
        }

        do {
            let decoded = try JSONDecoder().decode(APIResponse.self, from: data)
            guard let firstChoice = decoded.choices.first else {
                throw DeepSeekError.noResponse
            }
            var content = firstChoice.message.content
            // R23: Yanıt içeriğinde flag'li tıbbi ifade varsa disclaimer notu ekle
            if containsFlaggedMedicalContent(content) {
                content += "\n\n---\n⚠️ Bu yanıt tıbbi tavsiye niteliği taşımaz. Lütfen veteriner hekiminize danışınız."
            }
            return content
        } catch {
            throw DeepSeekError.decodingError
        }
    }
}
