import Carbon.HIToolbox

/// Representa um atalho já resolvido em termos do Carbon: virtual key code + máscara
/// de modificadores. É o formato esperado por `RegisterEventHotKey`.
struct Hotkey: Hashable, Sendable {
    let keyCode: UInt32
    let modifiers: UInt32
}

/// Converte strings legíveis ("Ctrl+Option+Left", "Cmd+Shift+M") em `Hotkey`.
enum HotkeyParser {

    /// Faz o parse de uma string de atalho. Retorna `nil` se a tecla principal
    /// for desconhecida (modificadores sozinhos não formam um atalho válido).
    static func parse(_ string: String) -> Hotkey? {
        let tokens = string
            .split(separator: "+")
            .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
            .filter { !$0.isEmpty }

        var modifiers: UInt32 = 0
        var keyCode: UInt32?

        for token in tokens {
            if let mod = modifierMap[token] {
                modifiers |= mod
            } else if let code = keyMap[token] {
                keyCode = code
            }
        }

        guard let keyCode else { return nil }
        return Hotkey(keyCode: keyCode, modifiers: modifiers)
    }

    /// Faz o parse só dos modificadores (usado para o `app_modifier`).
    static func parseModifiers(_ string: String) -> UInt32 {
        string
            .split(separator: "+")
            .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
            .reduce(into: UInt32(0)) { result, token in
                if let mod = modifierMap[token] { result |= mod }
            }
    }

    // MARK: - Tabelas de tradução

    private static let modifierMap: [String: UInt32] = [
        "ctrl": UInt32(controlKey), "control": UInt32(controlKey), "⌃": UInt32(controlKey),
        "opt": UInt32(optionKey), "option": UInt32(optionKey), "alt": UInt32(optionKey), "⌥": UInt32(optionKey),
        "cmd": UInt32(cmdKey), "command": UInt32(cmdKey), "meta": UInt32(cmdKey), "⌘": UInt32(cmdKey),
        "shift": UInt32(shiftKey), "⇧": UInt32(shiftKey)
    ]

    /// Nome da tecla (minúsculo) → virtual key code do Carbon.
    private static let keyMap: [String: UInt32] = {
        var map: [String: UInt32] = [
            // Setas
            "left": UInt32(kVK_LeftArrow), "right": UInt32(kVK_RightArrow),
            "up": UInt32(kVK_UpArrow), "down": UInt32(kVK_DownArrow),
            // Teclas especiais
            "return": UInt32(kVK_Return), "enter": UInt32(kVK_Return),
            "tab": UInt32(kVK_Tab), "space": UInt32(kVK_Space),
            "delete": UInt32(kVK_Delete), "backspace": UInt32(kVK_Delete),
            "escape": UInt32(kVK_Escape), "esc": UInt32(kVK_Escape),
            // Símbolos / pontuação — aceitamos tanto o caractere quanto o nome.
            "minus": UInt32(kVK_ANSI_Minus), "-": UInt32(kVK_ANSI_Minus),
            "equal": UInt32(kVK_ANSI_Equal), "=": UInt32(kVK_ANSI_Equal),
            "period": UInt32(kVK_ANSI_Period), ".": UInt32(kVK_ANSI_Period),
            "comma": UInt32(kVK_ANSI_Comma), ",": UInt32(kVK_ANSI_Comma),
            "slash": UInt32(kVK_ANSI_Slash), "/": UInt32(kVK_ANSI_Slash),
            "semicolon": UInt32(kVK_ANSI_Semicolon), ";": UInt32(kVK_ANSI_Semicolon),
            "quote": UInt32(kVK_ANSI_Quote), "'": UInt32(kVK_ANSI_Quote),
            "backslash": UInt32(kVK_ANSI_Backslash), "\\": UInt32(kVK_ANSI_Backslash),
            "grave": UInt32(kVK_ANSI_Grave), "`": UInt32(kVK_ANSI_Grave),
            "leftbracket": UInt32(kVK_ANSI_LeftBracket), "[": UInt32(kVK_ANSI_LeftBracket),
            "rightbracket": UInt32(kVK_ANSI_RightBracket), "]": UInt32(kVK_ANSI_RightBracket),
            // Dígitos
            "0": UInt32(kVK_ANSI_0), "1": UInt32(kVK_ANSI_1), "2": UInt32(kVK_ANSI_2),
            "3": UInt32(kVK_ANSI_3), "4": UInt32(kVK_ANSI_4), "5": UInt32(kVK_ANSI_5),
            "6": UInt32(kVK_ANSI_6), "7": UInt32(kVK_ANSI_7), "8": UInt32(kVK_ANSI_8),
            "9": UInt32(kVK_ANSI_9)
        ]
        // Letras A–Z
        let letters: [String: Int] = [
            "a": kVK_ANSI_A, "b": kVK_ANSI_B, "c": kVK_ANSI_C, "d": kVK_ANSI_D,
            "e": kVK_ANSI_E, "f": kVK_ANSI_F, "g": kVK_ANSI_G, "h": kVK_ANSI_H,
            "i": kVK_ANSI_I, "j": kVK_ANSI_J, "k": kVK_ANSI_K, "l": kVK_ANSI_L,
            "m": kVK_ANSI_M, "n": kVK_ANSI_N, "o": kVK_ANSI_O, "p": kVK_ANSI_P,
            "q": kVK_ANSI_Q, "r": kVK_ANSI_R, "s": kVK_ANSI_S, "t": kVK_ANSI_T,
            "u": kVK_ANSI_U, "v": kVK_ANSI_V, "w": kVK_ANSI_W, "x": kVK_ANSI_X,
            "y": kVK_ANSI_Y, "z": kVK_ANSI_Z
        ]
        for (name, code) in letters { map[name] = UInt32(code) }
        // F1–F12
        let fkeys: [String: Int] = [
            "f1": kVK_F1, "f2": kVK_F2, "f3": kVK_F3, "f4": kVK_F4,
            "f5": kVK_F5, "f6": kVK_F6, "f7": kVK_F7, "f8": kVK_F8,
            "f9": kVK_F9, "f10": kVK_F10, "f11": kVK_F11, "f12": kVK_F12
        ]
        for (name, code) in fkeys { map[name] = UInt32(code) }
        return map
    }()
}
