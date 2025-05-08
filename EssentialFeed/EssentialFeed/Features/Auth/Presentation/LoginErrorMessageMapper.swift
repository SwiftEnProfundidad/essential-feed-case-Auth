// LoginErrorMessageMapper.swift
// Presentation layer utility for mapping LoginError to user-facing messages

import Foundation

public enum LoginErrorMessageMapper {
    public static func message(for error: LoginError) -> String {
        switch error {
        case .invalidEmailFormat:
            return "Email format is invalid."
        case .invalidPasswordFormat:
            return "Password cannot be empty."
        case .invalidCredentials:
            return "Invalid credentials."
        case .network:
            return "Could not connect. Please try again."
        case .unknown:
            return "Something went wrong. Please try again."
        case .tokenStorageFailed:
            return "Token storage failed. Please try again."
        case .noConnectivity:
            return "No connectivity. Please check your internet connection."
        case .offlineStoreFailed:
            return "Offline store failed. Please try again."
        }
    }
}
