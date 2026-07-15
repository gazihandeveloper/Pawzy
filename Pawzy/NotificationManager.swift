//
//  NotificationManager.swift
//  Pawzy
//
//  UserNotifications yöneticisi — ilaç hatırlatıcıları
//

import UserNotifications
import SwiftData
import SwiftUI
import os

// MARK: - Logger

private let logger = Logger(subsystem: "com.pawzy.app", category: "NotificationManager")

// MARK: - NotificationManager

final class NotificationManager: Observable {

    static let shared = NotificationManager()

    private init() {}
    
    deinit {
        logger.debug("NotificationManager deinit")
    }

    // MARK: Permission

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                logger.error("Bildirim izni hatası: \(error.localizedDescription)")
            }
            if granted {
                logger.info("Bildirim izni verildi")
            } else {
                logger.info("Bildirim izni reddedildi")
            }
        }
    }

    /// Bildirim izninin mevcut durumunu kontrol eder, reddedildiyse Settings'e yönlendirme URL'i döndürür
    func checkNotificationStatus(completion: @escaping (UNAuthorizationStatus) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                completion(settings.authorizationStatus)
            }
        }
    }

    /// Kullanıcı bildirimleri reddettiyse, iOS Settings'e yönlendir
    func openAppNotificationSettings() {
        guard let url = URL(string: UIApplication.openNotificationSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    // MARK: Schedule

    /// İlaç için yerel bildirim(ler) planla
    func schedule(for medication: Medication) {
        let identifierBase = medication.persistentModelID.hashValue

        // Bekleyen bildirim sayısını hesapla
        getPendingCount { pendingCount in
            let content = UNMutableNotificationContent()
            content.title = "💊 \(medication.name)"
            content.body = "\(medication.dose) · \(medication.petName) – \(L.string("İlaç zamanı geldi"))!"
            content.sound = .default
            content.badge = NSNumber(value: pendingCount + 1)
            content.interruptionLevel = .timeSensitive

            let calendar = Calendar.current
            let components = calendar.dateComponents([.hour, .minute], from: medication.time)

            switch medication.frequency {
            case "daily":
                // Her gün aynı saatte
                var triggerComps = DateComponents()
                triggerComps.hour = components.hour
                triggerComps.minute = components.minute
                let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComps, repeats: true)
                let request = UNNotificationRequest(
                    identifier: "\(identifierBase)-daily",
                    content: content,
                    trigger: trigger
                )
                UNUserNotificationCenter.current().add(request) { error in
                    if let error = error {
                        logger.error("Bildirim planlama hatası: \(error.localizedDescription)")
                    } else {
                        logger.info("Günlük bildirim planlandı: \(String(format: "%02d:%02d", components.hour ?? 0, components.minute ?? 0))")
                    }
                }

            case "12hours":
                // İki ayrı bildirim: belirtilen saat ve 12 saat sonrası
                var triggerComps1 = DateComponents()
                triggerComps1.hour = components.hour
                triggerComps1.minute = components.minute

                let trigger1 = UNCalendarNotificationTrigger(dateMatching: triggerComps1, repeats: true)
                let request1 = UNNotificationRequest(
                    identifier: "\(identifierBase)-12h-1",
                    content: content,
                    trigger: trigger1
                )

                // 12 saat sonrası
                var triggerComps2 = DateComponents()
                let secondHour = ((components.hour ?? 0) + 12) % 24
                triggerComps2.hour = secondHour
                triggerComps2.minute = components.minute

                let content2 = content.mutableCopy() as! UNMutableNotificationContent
                let trigger2 = UNCalendarNotificationTrigger(dateMatching: triggerComps2, repeats: true)
                let request2 = UNNotificationRequest(
                    identifier: "\(identifierBase)-12h-2",
                    content: content2,
                    trigger: trigger2
                )

                UNUserNotificationCenter.current().add(request1) { error in
                    if let error = error {
                        logger.error("Bildirim planlama hatası (12h-1): \(error.localizedDescription)")
                    }
                }
                UNUserNotificationCenter.current().add(request2) { error in
                    if let error = error {
                        logger.error("Bildirim planlama hatası (12h-2): \(error.localizedDescription)")
                    }
                }
                logger.info("12-saat bildirim planlandı: \(String(format: "%02d:%02d", components.hour ?? 0, components.minute ?? 0)) + \(String(format: "%02d:%02d", secondHour, components.minute ?? 0))")

            case "weekly":
                // Haftalık — bugünün haftanın hangi günü olduğunu bul
                var triggerComps = DateComponents()
                triggerComps.hour = components.hour
                triggerComps.minute = components.minute
                triggerComps.weekday = calendar.component(.weekday, from: medication.time)
                let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComps, repeats: true)
                let request = UNNotificationRequest(
                    identifier: "\(identifierBase)-weekly",
                    content: content,
                    trigger: trigger
                )
                UNUserNotificationCenter.current().add(request) { error in
                    if let error = error {
                        logger.error("Bildirim planlama hatası: \(error.localizedDescription)")
                    } else {
                        logger.info("Haftalık bildirim planlandı")
                    }
                }

            default:
                // Tek seferlik (fallback)
                let trigger = UNCalendarNotificationTrigger(
                    dateMatching: calendar.dateComponents([.year, .month, .day, .hour, .minute], from: medication.time),
                    repeats: false
                )
                let request = UNNotificationRequest(
                    identifier: "\(identifierBase)-once",
                    content: content,
                    trigger: trigger
                )
                UNUserNotificationCenter.current().add(request) { error in
                    if let error = error {
                        logger.error("Bildirim planlama hatası (once): \(error.localizedDescription)")
                    }
                }
            }
        }
    }

    // MARK: Cancel

    func cancel(for medication: Medication) {
        let identifierBase = medication.persistentModelID.hashValue
        let identifiers = [
            "\(identifierBase)-daily",
            "\(identifierBase)-12h-1",
            "\(identifierBase)-12h-2",
            "\(identifierBase)-weekly",
            "\(identifierBase)-once"
        ]
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
        logger.info("Bildirimler iptal edildi: \(medication.name)")
    }

    // MARK: Test Bildirimi

    /// 5 saniye sonra bir test bildirimi gönderir (Ayarlar'daki "Sesli Uyarı" testi için)
    func sendTestNotification() {
        let content = UNMutableNotificationContent()
        content.title = "🐾 Pawzy"
        content.body = L.string("Bu bir test bildirimidir. Bildirimler çalışıyor!")
        content.sound = .default
        content.badge = 1
        content.interruptionLevel = .timeSensitive

        // 5 saniye sonra tetiklenir
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)

        let request = UNNotificationRequest(
            identifier: "pawzy-test-notification",
            content: content,
            trigger: trigger
        )

        // Önce eski test bildirimini temizle
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["pawzy-test-notification"])

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                logger.error("Test bildirimi planlama hatası: \(error.localizedDescription)")
            } else {
                logger.info("Test bildirimi 5 saniye sonra gönderilecek")
            }
        }
    }

    // MARK: Pending Helpers

    private func getPendingCount(completion: @escaping (Int) -> Void) {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            completion(requests.count)
        }
    }

    // MARK: Trial Reminder

    func scheduleTrialReminder(daysAfter: Int) {
        let content = UNMutableNotificationContent()
        content.title = L.string("Pawzy Premium denemen bitiyor")
        content.body = L.string("Ücretsiz denemenin bitmesine 2 gün kaldı. İstediğin zaman Ayarlar'dan yönetebilirsin.")
        content.sound = .default
        content.interruptionLevel = .timeSensitive

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: TimeInterval(daysAfter * 86400),
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: "pawzy-trial-reminder",
            content: content,
            trigger: trigger
        )

        // Önce eski trial bildirimini temizle
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["pawzy-trial-reminder"]
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                logger.error("Trial bildirim hatası: \(error.localizedDescription)")
            } else {
                logger.info("Trial hatırlatma bildirimi \(daysAfter) gün sonra planlandı")
            }
        }
    }

    func cancelTrialReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["pawzy-trial-reminder"]
        )
        logger.info("Trial hatırlatma bildirimi iptal edildi")
    }

    // MARK: Pending Check (debug)

    func printPendingNotifications() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            logger.info("Bekleyen \(requests.count) bildirim:")
            for req in requests {
                if let trigger = req.trigger as? UNCalendarNotificationTrigger {
                    logger.info("   - \(req.identifier): \(String(describing: trigger.dateComponents))")
                }
            }
        }
    }
}
