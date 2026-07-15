//
//  MainTabView.swift
//  Pawzy
//
//  Ana Tab Bar yapısı — 4 sekme, Apple HIG standart
//

import SwiftUI
import SwiftData
import UserNotifications

struct MainTabView: View {
    @State private var selectedTab: Tab = .bugun

    enum Tab: String, CaseIterable {
        case bugun
        case patilerim
        case dolap
        case ai
        case ayarlar

        var title: String {
            switch self {
            case .bugun: return L.string("Bugün")
            case .patilerim: return L.string("Patilerim")
            case .dolap: return L.string("Dolap")
            case .ai: return L.string("Pawzy AI")
            case .ayarlar: return L.string("Ayarlar")
            }
        }

        var icon: String {
            switch self {
            case .bugun: return "house"
            case .patilerim: return "pawprint"
            case .dolap: return "pill"
            case .ai: return "sparkles"
            case .ayarlar: return "gearshape"
            }
        }

        var selectedIcon: String {
            switch self {
            case .bugun: return "house.fill"
            case .patilerim: return "pawprint.fill"
            case .dolap: return "pill.fill"
            case .ai: return "sparkles"
            case .ayarlar: return "gearshape.fill"
            }
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Label(Tab.bugun.title, systemImage: selectedTab == .bugun ? Tab.bugun.selectedIcon : Tab.bugun.icon)
                }
                .tag(Tab.bugun)

            PetsListView()
                .tabItem {
                    Label(Tab.patilerim.title, systemImage: selectedTab == .patilerim ? Tab.patilerim.selectedIcon : Tab.patilerim.icon)
                }
                .tag(Tab.patilerim)

            CabinetView()
                .tabItem {
                    Label(Tab.dolap.title, systemImage: selectedTab == .dolap ? Tab.dolap.selectedIcon : Tab.dolap.icon)
                }
                .tag(Tab.dolap)

            AIView()
                .tabItem {
                    Label(Tab.ai.title, systemImage: selectedTab == .ai ? Tab.ai.selectedIcon : Tab.ai.icon)
                }
                .tag(Tab.ai)

            SettingsView()
                .tabItem {
                    Label(Tab.ayarlar.title, systemImage: selectedTab == .ayarlar ? Tab.ayarlar.selectedIcon : Tab.ayarlar.icon)
                }
                .tag(Tab.ayarlar)
        }
        .tint(.pzBlue)
        .onAppear {
            UNUserNotificationCenter.current().setBadgeCount(0)
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Pet.self, configurations: config)
    return MainTabView()
        .modelContainer(container)
}
