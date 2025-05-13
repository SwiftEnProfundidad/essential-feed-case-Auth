// LoginErrorMessageMapper.swift
// Presentation layer utility for mapping LoginError to user-facing messages

import Foundation

public enum LoginErrorMessageMapper {
    public static func message(for error: LoginError) -> String {
        switch error {
        case .invalidEmailFormat:
            "Email format is invalid."
        case .invalidPasswordFormat:
            "Password cannot be empty."
        case .invalidCredentials:
            "Invalid credentials."
        case .network:
            "Could not connect. Please try again."
        case .unknown:
            "Something went wrong. Please try again."
        case .tokenStorageFailed:
            "Token storage failed. Please try again."
        case .noConnectivity:
            "No connectivity. Please check your internet connection."
        case .offlineStoreFailed:
            "Offline store failed. Please try again."
        }
    }
}
