 //
//  AIView.swift
//  Pawzy
//
//  Pawzy AI — Chat arayüzü + Premium Gate
//

import SwiftUI
import SwiftData

// MARK: - AIView

struct AIView: View {

    // MARK: - SwiftData

    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \ChatMessage.timestamp, order: .forward) private var allMessages: [ChatMessage]
    @Query(sort: \Pet.name) private var pets: [Pet]

    // MARK: - State

    @State private var selectedPetName: String?
    @State private var inputText: String = ""
    @State private var isLoading: Bool = false
    @State private var showPaywall: Bool = false
    @State private var showHistorySheet: Bool = false
    @State private var errorMessage: String? = nil
    @State private var showError: Bool = false
    @State private var safariURL: URL? = nil
    @State private var showSafari: Bool = false

    @FocusState private var isInputFocused: Bool

    private let preselectedPetName: String?

    init(preselectedPetName: String? = nil) {
        self.preselectedPetName = preselectedPetName
    }

    // MARK: - Store Manager
    private let storeManager = IAPManager.shared

    // MARK: - Filtered Messages (cached @State)

    @State private var filteredMessages: [ChatMessage] = []
    @State private var lastMessageForPet: [String?: ChatMessage] = [:]

    private func updateFilteredMessages() {
        if let selectedPetName {
            filteredMessages = allMessages.filter { $0.petName == selectedPetName || $0.petName == nil }
        } else {
            filteredMessages = allMessages
        }
    }

    private func computeLastMessages() {
        // Genel sohbet (petName nil veya boş)
        let generalMessages = allMessages
            .filter { $0.petName == nil || $0.petName == "" }
            .sorted { $0.timestamp > $1.timestamp }
        lastMessageForPet[nil] = generalMessages.first

        // Her pet için son mesaj
        for pet in pets {
            let petMessages = allMessages
                .filter { $0.petName == pet.name }
                .sorted { $0.timestamp > $1.timestamp }
            lastMessageForPet[pet.name] = petMessages.first
        }
    }

    // MARK: - Body

    var body: some View {
        Group {
            if storeManager.isPremium {
                chatView
            } else {
                lockedView
            }
        }
        .onAppear {
            if let preselected = preselectedPetName {
                selectedPetName = preselected
            }
        }
    }

    // MARK: - Chat View

    private var chatView: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Mesaj listesi + arka plan pati deseni
                ZStack {
                    // Gradient glow
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.pzBlue.opacity(0.04),
                            Color.pzPurple.opacity(0.02),
                            Color.clear
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .ignoresSafeArea()

                    Color.pzBackground
                    messageList
                }

                // Disclaimer
                disclaimerView

                // Input alanı
                inputArea
            }
            .background(Color.pzBackground)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showHistorySheet = true
                    } label: {
                        Image(systemName: "line.3.horizontal")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.pzBlue)
                    }
                    .accessibilityLabel(L.string("Konuşma geçmişi"))
                }
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.pzBlue)
                        Text(L.string("Pawzy AI"))
                            .font(.pzHeadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.pzTextPrimary)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !pets.isEmpty {
                        Picker("", selection: $selectedPetName) {
                            Text(L.string("Genel")).tag(nil as String?)
                            ForEach(pets) { pet in
                                Text(pet.name).tag(pet.name as String?)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                    }
                }
            }
            .alert(L.string("Hata"), isPresented: $showError) {
                Button(L.string("Tamam"), role: .cancel) { }
            } message: {
                Text(errorMessage ?? L.string("Bilinmeyen bir hata oluştu."))
            }
            .sheet(isPresented: $showHistorySheet) {
                conversationHistorySheet
            }
            .onAppear {
                updateFilteredMessages()
                computeLastMessages()
            }
            .onChange(of: selectedPetName) { _, _ in
                updateFilteredMessages()
            }
            .onChange(of: allMessages.count) { _, _ in
                updateFilteredMessages()
                computeLastMessages()
            }
        }
    }

    // MARK: - Message List

    private var messageList: some View {
        ScrollViewReader { scrollProxy in
            ScrollView {
                LazyVStack(spacing: 6) {
                    if filteredMessages.isEmpty && !isLoading {
                        emptyChatView
                    }

                    ForEach(filteredMessages) { message in
                        MessageBubbleView(message: message)
                            .id(message.id)
                    }

                    // Loading indicator
                    if isLoading {
                        HStack {
                            AssistantBubblePlaceholder()
                            Spacer()
                        }
                        .padding(.horizontal, .pzSpaceLG)
                        .id("loadingBubble")
                    }

                    // Scroll anchor (en alt)
                    Color.clear
                        .frame(height: 1)
                        .id("bottomAnchor")
                }
                .padding(.vertical, .pzSpaceMD)
            }
            .onChange(of: filteredMessages.count) { _, _ in
                scrollToBottom(scrollProxy)
            }
            .onChange(of: isLoading) { _, _ in
                scrollToBottom(scrollProxy)
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    scrollToBottom(scrollProxy)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                isInputFocused = false
            }
        }
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        withAnimation(reduceMotion ? .easeInOut(duration: 0.25) : .easeOut(duration: 0.2)) {
            if isLoading {
                proxy.scrollTo("loadingBubble", anchor: .bottom)
            } else {
                proxy.scrollTo("bottomAnchor", anchor: .bottom)
            }
        }
    }

    // MARK: - Empty Chat

    private var emptyChatView: some View {
        VStack(spacing: .pzSpaceLG) {
            Spacer()
                .frame(height: 80)

            Image(systemName: "sparkles")
                .font(.system(size: 48))
                .foregroundColor(.pzBlue)
                .shadow(color: .pzBlue.opacity(0.4), radius: 20, x: 0, y: 0)
                .accessibilityHidden(true)

            Text(L.string("Pawzy AI'ya hoş geldin!"))
                .font(.pzTitleSmall)
                .foregroundColor(.pzTextPrimary)
                .multilineTextAlignment(.center)

            Text(L.string("Aklına takılan her şeyi sorabilirsin."))
                .font(.pzCallout)
                .foregroundColor(.pzTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, .pzSpaceXXL)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(L.string("Pawzy AI'ya hoş geldin! Aklına takılan her şeyi sorabilirsin."))
    }

    // MARK: - Disclaimer

    private var disclaimerView: some View {
        Text(L.string("Bu bilgiler tıbbi tavsiye niteliği taşımaz, öneri amaçlıdır. Veterinerinize danışın."))
            .font(.pzCaption)
            .foregroundColor(.pzTextTertiary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, .pzSpaceLG)
            .padding(.vertical, .pzSpaceXS)
            .frame(maxWidth: .infinity)
            .background(Color.pzBackground)
    }

    // MARK: - Input Area

    private var inputArea: some View {
        HStack(spacing: .pzSpaceSM) {
            TextField(L.string("Bir şey sor..."), text: $inputText, axis: .vertical)
                .font(.pzBody)
                .foregroundColor(.pzTextPrimary)
                .padding(.horizontal, .pzSpaceMD)
                .padding(.vertical, .pzSpaceSM)
                .background(
                    RoundedRectangle(cornerRadius: .pzRadiusLG)
                        .fill(Color.pzSurface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: .pzRadiusLG)
                        .strokeBorder(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.pzBlue.opacity(0.5), Color.pzPurple.opacity(0.3)]),
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 1
                        )
                )
                .focused($isInputFocused)
                .disabled(isLoading)
                .submitLabel(.send)
                .onSubmit {
                    sendMessage()
                }
                .lineLimit(1...5)

            Button {
                sendMessage()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(
                        canSend
                        ? AnyShapeStyle(LinearGradient(
                            gradient: Gradient(colors: [Color.pzBlue, Color.pzPurple]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        : AnyShapeStyle(Color.pzTextQuaternary)
                    )
            }
            .disabled(!canSend)
            .buttonStyle(.plain)
            .accessibilityLabel(L.string("Gönder"))
        }
        .padding(.horizontal, .pzSpaceMD)
        .padding(.vertical, .pzSpaceSM)
        .background(Color.pzBackground)
        .overlay(
            Rectangle()
                .fill(Color.pzSeparator)
                .frame(height: 0.5),
            alignment: .top
        )
    }

    private var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespaces).isEmpty && !isLoading
    }

    // MARK: - Last Message Helper (cached dictionary)

    private func lastMessage(for petName: String?) -> ChatMessage? {
        lastMessageForPet[petName]
    }

    // MARK: - Conversation History Sheet

    private var conversationHistorySheet: some View {
        NavigationStack {
            List {
                // "Genel" satırı
                Button {
                    selectedPetName = nil
                    showHistorySheet = false
                } label: {
                    HStack {
                        Image(systemName: "sparkles")
                            .font(.system(size: 20))
                            .foregroundColor(.pzBlue)
                            .frame(width: 32, height: 32)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(L.string("Genel Sohbet"))
                                .font(.pzBody)
                                .foregroundColor(.pzTextPrimary)

                            if let lastMsg = lastMessage(for: nil) {
                                Text(lastMsg.content.prefix(60) + (lastMsg.content.count > 60 ? "…" : ""))
                                    .font(.pzCaption)
                                    .foregroundColor(.pzTextTertiary)
                                    .lineLimit(1)
                                Text(lastMsg.timestamp, style: .relative)
                                    .font(.system(size: 10))
                                    .foregroundColor(.pzTextQuaternary)
                            }
                        }

                        Spacer()

                        if selectedPetName == nil {
                            Image(systemName: "checkmark")
                                .foregroundColor(.pzBlue)
                        }
                    }
                }
                .buttonStyle(.plain)

                // Her bir pet için satır
                ForEach(pets) { pet in
                    Button {
                        selectedPetName = pet.name
                        showHistorySheet = false
                    } label: {
                        HStack {
                            Circle()
                                .fill(Color(hex: pet.tintColor))
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Image(systemName: pet.iconName)
                                        .font(.system(size: 16))
                                        .foregroundColor(.white)
                                )

                            VStack(alignment: .leading, spacing: 2) {
                                Text(pet.name)
                                    .font(.pzBody)
                                    .foregroundColor(.pzTextPrimary)

                                if let lastMsg = lastMessage(for: pet.name) {
                                    Text(lastMsg.content.prefix(60) + (lastMsg.content.count > 60 ? "…" : ""))
                                        .font(.pzCaption)
                                        .foregroundColor(.pzTextTertiary)
                                        .lineLimit(1)
                                    Text(lastMsg.timestamp, style: .relative)
                                        .font(.system(size: 10))
                                        .foregroundColor(.pzTextQuaternary)
                                } else {
                                    Text(L.string("Henüz mesaj yok"))
                                        .font(.pzCaption)
                                        .foregroundColor(.pzTextTertiary)
                                }
                            }

                            Spacer()

                            if selectedPetName == pet.name {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.pzBlue)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .listStyle(.plain)
            .navigationTitle(L.string("Konuşmalar"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L.string("Kapat")) {
                        showHistorySheet = false
                    }
                }
            }
        }
        .presentationDetents([.large])
    }

    // MARK: - Send Message

    private func sendMessage() {
        guard !inputText.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        let text = inputText.trimmingCharacters(in: .whitespaces)
        inputText = ""
        isLoading = true

        // Kullanıcı mesajını kaydet
        let userMessage = ChatMessage(role: "user", content: text, petName: selectedPetName)
        modelContext.insert(userMessage)
        try? modelContext.save()
        updateFilteredMessages()

        // API'ye hazır mesaj listesi (sadece user/assistant rolleri)
        var apiMessages: [[String: String]] = filteredMessages.map {
            ["role": $0.role, "content": $0.content]
        }
        // Emniyet: son mesaj kullanıcı mesajı değilse ekle
        if apiMessages.last?["role"] != "user" || apiMessages.last?["content"] != text {
            apiMessages.append(["role": "user", "content": text])
        }

        // Seçili pet
        let selectedPet = pets.first(where: { $0.name == selectedPetName })

        Task {
            do {
                let response = try await DeepSeekService.sendMessage(
                    messages: apiMessages,
                    pet: selectedPet
                )
                await MainActor.run {
                    let assistantMessage = ChatMessage(
                        role: "assistant",
                        content: response,
                        petName: selectedPetName
                    )
                    modelContext.insert(assistantMessage)
                    try? modelContext.save()
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                    isLoading = false
                }
            }
        }
    }

    // MARK: - Locked View (Premium Gate) — Arda'nın Cialdini 6 prensibi + Apple Fitness+ stili

    private var lockedView: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {

                    // MARK: Hero Alanı
                    VStack(spacing: .pzSpaceLG) {
                        pawSparkleHero
                            .padding(.top, .pzSpaceXXL)

                        Text(L.string("ai_locked_title"))
                            .font(.pzTitleSmall)
                            .foregroundColor(.pzTextPrimary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, .pzSpaceXL)
                    }
                    .padding(.bottom, .pzSpaceXL)

                    // MARK: Benefit Kartları
                    VStack(spacing: .pzSpaceMD) {
                        benefitCard(
                            icon: "brain.head.profile.fill",
                            iconColor: .pzBlue,
                            title: L.string("ai_benefit_nutrition_title"),
                            subtitle: L.string("ai_benefit_nutrition_body")
                        )
                        benefitCard(
                            icon: "pawprint.fill",
                            iconColor: .pzCoral,
                            title: L.string("ai_benefit_personalized_title"),
                            subtitle: L.string("ai_benefit_personalized_body")
                        )
                        benefitCard(
                            icon: "chart.bar.fill",
                            iconColor: .pzGreen,
                            title: L.string("ai_benefit_health_title"),
                            subtitle: L.string("ai_benefit_health_body")
                        )
                    }
                    .padding(.horizontal, .pzSpaceXL)

                    // MARK: Sosyal Kanıt
                    VStack(spacing: .pzSpaceSM) {
                        HStack(spacing: 4) {
                            ForEach(0..<5) { i in
                                Image(systemName: "star.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.pzCoral)
                            }
                            Text(L.string("ai_social_proof"))
                                .font(.pzCaption)
                                .foregroundColor(.pzTextTertiary)
                        }
                    }
                    .padding(.top, .pzSpaceXL)

                    // MARK: Primary CTA
                    Button {
                        showPaywall = true
                    } label: {
                        HStack(spacing: .pzSpaceSM) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 16, weight: .medium))
                            Text(L.string("ai_cta_free_trial"))
                                .font(.pzBodyBold)
                            Image(systemName: "arrow.right")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            RoundedRectangle(cornerRadius: .pzRadiusLG)
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color.pzBlueGradientStart, Color.pzBlueGradientEnd]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        )
                        .pzShadowPremium()
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, .pzSpaceXL)
                    .padding(.top, .pzSpaceXXL)
                    .accessibilityLabel(L.string("ai_cta_free_trial"))

                    // Fiyat alt metni
                    Text(IAPPriceInfo.postTrialText(for: .monthly, storeManager: storeManager))
                        .font(.pzCaption)
                        .foregroundColor(.pzTextTertiary)
                        .padding(.top, .pzSpaceSM)

                    // MARK: Footer Linkler
                    HStack(spacing: 0) {
                        Button {
                            storeManager.restorePurchases()
                        } label: {
                            Text(L.string("Geri Yükle"))
                                .font(.pzCaption)
                                .foregroundColor(.pzTextTertiary)
                        }
                        .buttonStyle(.plain)

                        Text(" · ")
                            .font(.pzCaption)
                            .foregroundColor(.pzTextQuaternary)

                        Button {
                            safariURL = URL(string: "https://mahmutgazihanarslan.com.tr/pawzy/termsofuse.html")
                            showSafari = true
                        } label: {
                            Text(L.string("Kullanım Koşulları"))
                                .font(.pzCaption)
                                .foregroundColor(.pzTextTertiary)
                        }
                        .buttonStyle(.plain)

                        Text(" · ")
                            .font(.pzCaption)
                            .foregroundColor(.pzTextQuaternary)

                        Button {
                            safariURL = URL(string: "https://mahmutgazihanarslan.com.tr/pawzy/privacy.html")
                            showSafari = true
                        } label: {
                            Text(L.string("Gizlilik Politikası"))
                                .font(.pzCaption)
                                .foregroundColor(.pzTextTertiary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, .pzSpaceLG)
                    .padding(.bottom, .pzSpaceXXL)

                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }
            .background(Color.pzBackground)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(L.string("Pawzy AI"))
                        .font(.pzHeadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.pzTextPrimary)
                }
            }
            .fullScreenCover(isPresented: $showPaywall) {
                PaywallView(isPresented: $showPaywall, storeManager: storeManager)
            }
            .sheet(isPresented: $showSafari) {
                if let url = safariURL {
                    SafariView(url: url)
                }
            }
        }
    }

    // MARK: - Paw Sparkle Hero

    private var pawSparkleHero: some View {
        ZStack {
            // Glow
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            Color.pzBlue.opacity(0.15),
                            Color.pzBlue.opacity(0.05),
                            Color.clear
                        ]),
                        center: .center,
                        startRadius: 30,
                        endRadius: 80
                    )
                )
                .frame(width: 160, height: 160)

            // Ana ikon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.pzBlue, Color.pzPurple]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 90, height: 90)
                    .pzShadowProgress()

                PhaseAnimator([false, true]) { isSparkle in
                    Group {
                        if !isSparkle {
                            Image(systemName: "pawprint.fill")
                                .font(.system(size: 42))
                                .foregroundColor(.white)
                        } else {
                            Image(systemName: "sparkles")
                                .font(.system(size: 40))
                                .foregroundColor(.white)
                        }
                    }
                } animation: { _ in
                    .easeInOut(duration: 1.5)
                }
            }
            .frame(width: 140, height: 140)
        }
        .frame(width: 140, height: 140)
        .accessibilityHidden(true)
    }

    // MARK: - Benefit Card

    private func benefitCard(icon: String, iconColor: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: .pzSpaceMD) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(iconColor)
                .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.pzBodyBold)
                    .foregroundColor(.pzTextPrimary)
                Text(subtitle)
                    .font(.pzCaption)
                    .foregroundColor(.pzTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(.pzSpaceLG)
        .background(
            RoundedRectangle(cornerRadius: .pzRadiusLG)
                .fill(Color.pzSurface)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(subtitle)")
    }

}

// MARK: - Message Bubble View

private struct MessageBubbleView: View {
    let message: ChatMessage

    private var isUser: Bool {
        message.role == "user"
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // User spacer'ı solda → balon sağa yaslanır
            if isUser { Spacer() }

            // Assistant avatar (solda)
            if !isUser {
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.pzBlue, Color.pzPurple]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 28, height: 28)
                    .overlay(
                        Image(systemName: "sparkles")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    )
                    .accessibilityHidden(true)
                    .padding(.trailing, 8)
                    .padding(.top, 4)
            }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .font(.pzBody)
                    .foregroundColor(isUser ? .white : .pzTextPrimary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        Group {
                            if isUser {
                                UnevenRoundedRectangle(
                                    topLeadingRadius: 20,
                                    bottomLeadingRadius: 20,
                                    bottomTrailingRadius: 4,
                                    topTrailingRadius: 20
                                )
                                .fill(Color.pzBlue)
                            } else {
                                UnevenRoundedRectangle(
                                    topLeadingRadius: 20,
                                    bottomLeadingRadius: 4,
                                    bottomTrailingRadius: 20,
                                    topTrailingRadius: 20
                                )
                                .fill(Color.pzSurface)
                                .overlay(
                                    UnevenRoundedRectangle(
                                        topLeadingRadius: 20,
                                        bottomLeadingRadius: 4,
                                        bottomTrailingRadius: 20,
                                        topTrailingRadius: 20
                                    )
                                    .strokeBorder(Color.pzBorderLight, lineWidth: 0.5)
                                )
                            }
                        }
                    )
                    .shadow(color: isUser ? .clear : .black.opacity(0.04), radius: 4, x: 0, y: 2)
                    .fixedSize(horizontal: false, vertical: true)

                // Pet name badge (sadece asistan mesajlarında pet seçiliyse)
                if !isUser, let petName = message.petName {
                    Text(petName)
                        .font(.pzCaption)
                        .foregroundColor(.pzTextTertiary)
                        .padding(.leading, 4)
                }
            }
            .frame(maxWidth: 310, alignment: isUser ? .trailing : .leading)

            // Assistant spacer'ı sağda → balon sola yaslanır
            if !isUser { Spacer() }
        }
        .padding(.horizontal, .pzSpaceLG)
        .padding(.vertical, 4)
        .transition(.opacity.combined(with: .slide))
    }
}

// MARK: - Assistant Bubble Placeholder (Loading)

private struct AssistantBubblePlaceholder: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // Assistant avatar (solda)
            Circle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.pzBlue, Color.pzPurple]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 28, height: 28)
                .overlay(
                    Image(systemName: "sparkles")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                )
                .accessibilityHidden(true)
                .padding(.trailing, 8)
                .padding(.top, 4)

            VStack(alignment: .leading) {
                TimelineView(.periodic(from: .now, by: 0.4)) { timeline in
                    let phase = Int(timeline.date.timeIntervalSince1970 * 2.5) % 3
                    HStack(spacing: 4) {
                        ForEach(0..<3) { i in
                            Circle()
                                .fill(Color.pzTextQuaternary)
                                .frame(width: 6, height: 6)
                                .opacity(phase == i ? 1.0 : 0.3)
                                .animation(reduceMotion ? .easeInOut(duration: 0.25) : .easeInOut(duration: 0.2), value: phase)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        UnevenRoundedRectangle(
                            topLeadingRadius: 20,
                            bottomLeadingRadius: 4,
                            bottomTrailingRadius: 20,
                            topTrailingRadius: 20
                        )
                        .fill(Color.pzSurface)
                        .overlay(
                            UnevenRoundedRectangle(
                                topLeadingRadius: 20,
                                bottomLeadingRadius: 4,
                                bottomTrailingRadius: 20,
                                topTrailingRadius: 20
                            )
                            .strokeBorder(Color.pzBorderLight, lineWidth: 0.5)
                        )
                    )
                    .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
                }
            }

            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(L.string("Yanıt bekleniyor"))
    }
}

// MARK: - Preview

#Preview("AI View — Premium Aktif") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: ChatMessage.self, Pet.self,
        configurations: config
    )
    let context = container.mainContext

    // Mock pet
    let pamuk = Pet(
        name: "Pamuk",
        breed: "British Shorthair",
        age: 3,
        weight: 4.2,
        sex: "Dişi",
        tintColor: "#E05A67",
        iconName: "cat.fill"
    )
    context.insert(pamuk)

    // Mock messages
    let msg1 = ChatMessage(
        role: "user",
        content: "Pamuk için hangi mamayı önerirsin?",
        petName: "Pamuk"
    )
    let msg2 = ChatMessage(
        role: "assistant",
        content: "Pamuk (British Shorthair, 3 yaş) için yüksek proteinli, tahılsız kuru mamalar öneririm. Royal Canin British Shorthair veya Hills Science Diet iyi seçenekler. Bu bilgiler tıbbi tavsiye niteliği taşımaz.",
        petName: "Pamuk"
    )
    context.insert(msg1)
    context.insert(msg2)

    // Simulate premium for preview
    IAPManager.shared.isPremium = true

    return AIView()
        .modelContainer(container)
}

#Preview("AI View — Premium Yok") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: ChatMessage.self, Pet.self,
        configurations: config
    )
    // Simulate no premium for preview
    IAPManager.shared.isPremium = false

    return AIView()
        .modelContainer(container)
}
