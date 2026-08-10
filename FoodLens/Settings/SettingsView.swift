import SwiftUI


struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var backend: VisionBackend = VisionSettings.backend

    @State private var anthropicKey = ""
    @State private var anthropicModel = VisionSettings.anthropicModel

    @State private var geminiKey = ""
    @State private var geminiModel = VisionSettings.geminiModel

    @State private var ollamaBaseURL = VisionSettings.ollamaBaseURL.absoluteString
    @State private var ollamaModel = VisionSettings.ollamaModel

    @State private var usdaKey = ""

    @State private var statusMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Motor de visão", selection: $backend) {
                        ForEach(VisionBackend.allCases, id: \.self) { backend in
                            Text(backend.displayName).tag(backend)
                        }
                    }
                } footer: {
                    Text("Qual API é chamada para reconhecer os alimentos na fotografia.")
                }

                Section("Anthropic") {
                    SecureField("Chave da API", text: $anthropicKey)
                    TextField("Modelo", text: $anthropicModel)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }

                Section("Gemini") {
                    SecureField("Chave da API", text: $geminiKey)
                    TextField("Modelo", text: $geminiModel)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }

                Section {
                    TextField("URL", text: $ollamaBaseURL)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    TextField("Modelo", text: $ollamaModel)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                } header: {
                    Text("Ollama (local)")
                } footer: {
                    Text("Sem chave — corre num servidor Ollama na tua rede local.")
                }

                Section {
                    SecureField("Chave da API", text: $usdaKey)
                } header: {
                    Text("USDA FoodData Central")
                } footer: {
                    Text("Usado como último recurso quando um alimento não existe na tabela INSA.")
                }

                if let statusMessage {
                    Section {
                        Text(statusMessage).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Definições")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fechar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar", action: save)
                        .fontWeight(.semibold)
                }
            }
            .onAppear(perform: loadKeys)
        }
    }

    private func loadKeys() {
        do {
            anthropicKey = try KeychainStore.get(.anthropicAPIKey) ?? ""
            geminiKey = try KeychainStore.get(.geminiAPIKey) ?? ""
            usdaKey = try KeychainStore.get(.usdaAPIKey) ?? ""
        } catch {
            statusMessage = "Não foi possível ler o Keychain: \(error.localizedDescription)"
        }
    }

    private func save() {
        do {
            try saveOrDelete(anthropicKey, for: .anthropicAPIKey)
            try saveOrDelete(geminiKey, for: .geminiAPIKey)
            try saveOrDelete(usdaKey, for: .usdaAPIKey)

            VisionSettings.backend = backend
            VisionSettings.anthropicModel = anthropicModel
            VisionSettings.geminiModel = geminiModel
            VisionSettings.ollamaModel = ollamaModel
            if let url = URL(string: ollamaBaseURL) {
                VisionSettings.ollamaBaseURL = url
            }
            dismiss()
        } catch {
            statusMessage = "Não foi possível guardar no Keychain: \(error.localizedDescription)"
        }
    }

    /// Uma chave vazia apaga a entrada em vez de gravar "" — sem isto,
    /// `KeychainStore.get` devolveria uma string vazia (não nil) e o
    /// resto do código ia achar que havia uma chave configurada.
    private func saveOrDelete(_ value: String, for key: KeychainKey) throws {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            try KeychainStore.delete(key)
        } else {
            try KeychainStore.set(trimmed, for: key)
        }
    }
}

#Preview {
    SettingsView()
}
