// REMOVE-OLD-PATH: /Users/juancarlosmerlosalbarracin/Developer/Essential_Developer/essential-feed-case-study/EssentialFeed/EssentialFeed/Features/Registration/RegistrationValidatorStub.swift
// ADD-NEW-PATH: /Users/juancarlosmerlosalbarracin/Developer/Essential_Developer/essential-feed-case-study/EssentialFeed/EssentialFeed/Features/Registration/RegistrationValidator.swift
// Copyright © 2025 Essential Developer. All rights reserved.
// (El copyright puede variar, lo mantengo como estaba en tu captura)

import Foundation
// import EssentialFeed // No es necesario importar el propio módulo aquí

// CHANGE: Renombrar la clase a RegistrationValidator y hacerla public si es necesario
public final class RegistrationValidator: RegistrationValidatorProtocol {
    public init() {} // Hacer public el init si la clase es public

    public func validate(name: String, email: String, password: String) -> RegistrationValidationError? {
        if name.trimmingCharacters(in: .whitespaces).isEmpty {
            return .emptyName
        }

        // Considera una validación de email más robusta si es necesario
        if !email.contains("@") || !email.contains(".") {
            return .invalidEmail
        }

        // Ajusta la longitud mínima de la contraseña según tus requisitos
        if password.count < 8 {
            return .weakPassword
        }

        return nil
    }
}
