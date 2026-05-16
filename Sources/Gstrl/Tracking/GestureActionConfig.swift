import Foundation

final class GestureActionConfig {
    static let shared = GestureActionConfig()

    private let storageKey = "gestureBindings"
    private var bindings: [GestureSlot: KeyBinding] = [:]

    init() {
        load()
    }

    func binding(for slot: GestureSlot) -> KeyBinding {
        bindings[slot] ?? slot.defaultBinding
    }

    func setBinding(_ binding: KeyBinding, for slot: GestureSlot) {
        if binding == slot.defaultBinding {
            bindings.removeValue(forKey: slot)
        } else {
            bindings[slot] = binding
        }
        save()
    }

    func resetAll() {
        bindings.removeAll()
        UserDefaults.standard.removeObject(forKey: storageKey)
    }

    func resetSlot(_ slot: GestureSlot) {
        bindings.removeValue(forKey: slot)
        save()
    }

    func isDefault(for slot: GestureSlot) -> Bool {
        bindings[slot] == nil
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(bindings) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([GestureSlot: KeyBinding].self, from: data) else { return }
        bindings = decoded
    }
}
