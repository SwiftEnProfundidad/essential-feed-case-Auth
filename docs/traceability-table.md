# Technical Checklist Tests Traceability Table

This table maps each requirement from the technical checklists to their corresponding test implementations, ensuring complete test coverage for all BDD use cases.

## Use Case 1: Secure Storage (Keychain/SecureStorage) 
| Test File | Test Method | Technical Requirement | Status | Coverage |
|-----------|-------------|----------------------|--------|----------|
| `KeychainHelperTests.swift` | `test_save_storesDataWithKey` | Basic save operation for string data | | Full |
| `KeychainHelperTests.swift` | `test_save_storesDataWithUnicodeKey` | Support for unicode keys | | Full |
| `KeychainHelperTests.swift` | `test_save_storesLargeBinaryData` | Support for large binary data | | Full |
| `KeychainHelperTests.swift` | `test_get_retrievesStoredData` | Basic retrieve operation | | Full |
| `KeychainHelperTests.swift` | `test_delete_removesStoredData` | Basic delete operation | | Full |
| `KeychainHelperTests.swift` | `test_save_isThreadSafe_underConcurrentAccess` | Thread safety validation | | Full |
| `SystemKeychainTests.swift` | `test_save_succeeds_onValidData` | Real Keychain integration (macOS) | | Full |
| `SystemKeychainTests.swift` | `test_get_retrievesStoredValue` | Real Keychain retrieval | | Full |
| `SystemKeychainTests.swift` | `test_delete_removesStoredValue` | Real Keychain deletion | | Full |
| `SystemKeychainIntegrationCoverageTests.swift` | `test_keychainOperations_*` | Comprehensive error mapping (OSStatus → KeychainError) | | Full |
| `KeychainManagerTests.swift` | `test_load_*` | KeychainManager abstraction layer | | Full |
| `KeychainManagerTests.swift` | `test_save_*` | Encryption integration with save operations | | Full |
| `KeychainManagerTests.swift` | `test_decrypt_*` | Decryption on data retrieval | | Full |
| `AES256CryptoKitEncryptorTests.swift` | `test_encrypt_*` | AES-256 encryption verification | | Full |
| `AES256CryptoKitEncryptorTests.swift` | `test_decrypt_*` | AES-256 decryption verification | | Full |

## Use Case 2: User Registration 
| Test File | Test Method | Technical Requirement | Status | Coverage |
|-----------|-------------|----------------------|--------|----------|
| `UserRegistrationUseCaseTests.swift` | `test_registerUser_withValidData_createsUserAndStoresCredentialsSecurely` | Store initial credentials securely (Keychain) | | Full |
| `UserRegistrationUseCaseTests.swift` | `test_registerUser_withValidData_storesAuthToken` | Store authentication token received (OAuth/JWT) securely after registration | | Full |
| `UserRegistrationUseCaseTests.swift` | `test_registerUser_withValidData_notifiesSuccessObserver` | Notify registration success | | Full |
| `UserRegistrationUseCaseTests.swift` | `test_registerUser_withAlreadyRegisteredEmail_notifiesEmailAlreadyInUsePresenter` | Notify that the email is already in use (UI-level) | | Full |
| `UserRegistrationUseCaseTests.swift` | `test_registerUser_withAlreadyRegisteredEmail_returnsEmailAlreadyInUseError` | Notify that the email is already in use (domain-level) | | Full |
| `UserRegistrationUseCaseTests.swift` | `test_registerUser_withInvalidEmail_returnsInvalidEmailError` | Show appropriate and specific error messages (invalid email) | | Full |
| `UserRegistrationUseCaseTests.swift` | `test_registerUser_withWeakPassword_returnsWeakPasswordError` | Show appropriate and specific error messages (weak password) | | Full |
| `UserRegistrationUseCaseTests.swift` | `test_registerUser_withEmptyName_returnsValidationError_andDoesNotCallHTTPOrKeychain` | Input validation: empty name | | Full |
| `UserRegistrationUseCaseTests.swift` | `test_registerUser_withInvalidEmail_returnsValidationError_andDoesNotCallHTTPOrKeychain` | Input validation: invalid email format | | Full |
| `UserRegistrationUseCaseTests.swift` | `test_registerUser_withWeakPassword_returnsValidationError_andDoesNotCallHTTPOrKeychain` | Input validation: weak password | | Full |
| `UserRegistrationUseCaseTests.swift` | `test_register_whenNoConnectivity_savesDataToOfflineStoreAndReturnsConnectivityError` | Save data for retry if no connection and notify error | | Full |
| `UserRegistrationServerUseCaseTests.swift` | `test_registerUser_sendsRequestToServer` | HTTP request formation and sending | | Full |
| `UserRegistrationUseCaseIntegrationTests.swift` | `test_registerUser_withValidData_succeedsWithIntegration` | Integration test: end-to-end happy path | | Full |
| `UserRegistrationUseCaseIntegrationTests.swift` | `test_registerUser_withServerError_failsWithIntegration` | Integration test: server error handling | | Full |
| `RetryOfflineRegistrationsUseCaseTests.swift` | `test_execute_whenNoOfflineRegistrations_returnsEmptyResults` | Implement logic to retry saved offline registration requests (no data) | | Full |
| `RetryOfflineRegistrationsUseCaseTests.swift` | `test_execute_whenOneOfflineRegistrationSucceeds_retriesAndDeletesSuccessfulRequest` | Implement logic to retry saved offline registration requests (success) | | Full |
| `RetryOfflineRegistrationsUseCaseTests.swift` | `test_execute_whenApiCallFails_returnsRegistrationFailedError` | Implement logic to retry saved offline registration requests (API failure) | | Full |
| `RetryOfflineRegistrationsUseCaseTests.swift` | `test_execute_whenTokenStorageFails_returnsTokenStorageFailedError` | Implement logic to retry saved offline registration requests (token storage failure) | | Full |
| `RetryOfflineRegistrationsUseCaseTests.swift` | `test_execute_whenDeleteFails_returnsOfflineStoreDeleteFailedError` | Implement logic to retry saved offline registration requests (cleanup failure) | | Full |
| `DefaultReplayAttackProtectorTests.swift` | `test_protect_addsNonceAndTimestampToRequest` | Replay attack protection implementation | | Full |
| `HMACRequestSignerTests.swift` | `test_signRequest_addsHMACSignatureToHeaders` | Request signing for replay protection | | Full |

## Use Case 3: User Authentication (Login) 
| Test File | Test Method | Technical Requirement | Status | Coverage |
|-----------|-------------|----------------------|--------|----------|
| `UserLoginUseCaseTests.swift` | `test_login_succeeds_onValidCredentialsAndServerResponse` | Happy path: successful login + token storage | | Full |
| `UserLoginUseCaseTests.swift` | `test_login_fails_onInvalidCredentials` | Sad path: invalid credentials error handling | | Full |
| `UserLoginUseCaseTests.swift` | `test_login_whenNoConnectivity_savesCredentialsToOfflineStoreAndReturnsConnectivityError` | Offline login request storage | | Full |
| `UserLoginUseCaseTests.swift` | `test_login_succeedsApiCall_butFailsToStoreToken_returnsError` | Token storage failure handling | | Full |
| `RetryOfflineLoginsUseCaseTests.swift` | `test_execute_whenNoOfflineLogins_returnsEmptyResults` | Offline retry: no pending login requests | | Full |
| `RetryOfflineLoginsUseCaseTests.swift` | `test_execute_whenOneOfflineLoginSucceeds_retriesAndDeletesSuccessfulRequest` | Offline retry: successful login retry | | Full |
| `RetryOfflineLoginsUseCaseTests.swift` | `test_execute_whenApiCallFails_returnsLoginFailedError` | Offline retry: API failure handling | | Full |
| `RetryOfflineLoginsUseCaseTests.swift` | `test_execute_whenTokenStorageFails_returnsTokenStorageFailedError` | Offline retry: token storage failure | | Full |
| `LoginSecurityUseCaseTests.swift` | `test_checkSecurity_whenUserIsNotLocked_returnsSuccess` | Security check: account not locked | | Full |
| `LoginSecurityUseCaseTests.swift` | `test_checkSecurity_whenUserIsLocked_returnsAccountLockedError` | Security check: account locked state | | Full |
| `LoginSecurityUseCaseTests.swift` | `test_checkSecurity_whenFailedAttemptsExceedThreshold_locksAccount` | Security check: lockout after failed attempts | | Full |
| `LoginSecurityUseCaseTests.swift` | `test_checkSurity_whenSuggestPasswordRecovery_notifiesRecoveryService` | Security check: password recovery suggestion | | Full |
| `InMemoryFailedLoginAttemptsStoreTests.swift` | `test_addAttempt_storesFailedAttempt` | Failed login attempts tracking | | Full |
| `InMemoryFailedLoginAttemptsStoreTests.swift` | `test_getAttempts_returnsStoredAttempts` | Failed login attempts retrieval | | Full |
| `AnyFailedLoginAttemptStoreTests.swift` | `test_addAttempt_delegatesToRealStore` | Type-erased wrapper validation | | Full |
| `LoginIntegrationTests.swift` | `test_loginWithValidCredentials_succeeds` | Integration test: happy path login flow | | Full |
| `LoginIntegrationTests.swift` | `test_loginWithInvalidCredentials_showsError` | Integration test: error handling | | Full |
| `EnhancedLoginLockingIntegrationTests.swift` | `test_multipleFailedLogins_triggersAccountLockout` | End-to-end: lockout flow | | Full |
| `EnhancedLoginLockingIntegrationTests.swift` | `test_lockedAccount_suggestsPasswordRecovery` | End-to-end: recovery suggestion flow | | Full |
| `LoginNotificationSnapshotTests.swift` | `test_loginSuccess_showsSuccessNotification` | UI test: success notification display | | Full |
| `LoginNotificationSnapshotTests.swift` | `test_loginError_showsErrorNotification` | UI test: error notification display | | Full |
| `LoginNotificationSnapshotTests.swift` | `test_loginNetworkError_showsNetworkErrorNotification` | UI test: network error notification | | Full |

## Use Case 4: Token Expiration Management 
| Test File | Test Method | Technical Requirement | Status | Coverage |
|-----------|-------------|----------------------|--------|----------|
| `RefreshTokenUseCaseTests.swift` | `test_refresh_succeeds_onValidRefreshToken` | Happy path: successful token refresh | | Full |
| `RefreshTokenUseCaseTests.swift` | `test_refresh_fails_onInvalidRefreshToken` | Sad path: invalid refresh token | | Full |
| `RefreshTokenUseCaseTests.swift` | `test_refresh_fails_onNetworkError` | Network error during refresh | | Full |
| `AuthenticatedHTTPClientDecoratorTests.swift` | `test_publicRequest_doesNotAddAuthHeaders` | Route policy: public routes bypass auth | | Full |
| `AuthenticatedHTTPClientDecoratorTests.swift` | `test_authenticatedRequest_addsValidToken` | Token injection: valid token added | | Full |
| `AuthenticatedHTTPClientDecoratorTests.swift` | `test_authenticatedRequest_doesNotAddExpiredToken` | Token validation: expired token detection | | Full |
| `AuthenticatedHTTPClientDecoratorTests.swift` | `test_authenticatedRequest_retriesAfter401WithRefresh` | Automatic retry: 401 triggers refresh | | Full |
| `AuthenticatedHTTPClientDecoratorTests.swift` | `test_refreshFails_triggersGlobalLogout` | Global logout: refresh failure handling | | Full |
| `TokenValidationInterceptorTests.swift` | `test_interceptRequest_withValidToken_proceedsWithToken` | Token validation interceptor | | Full |
| `TokenRefreshInterceptorTests.swift` | `test_handleResponse_with401_triggersRefresh` | Token refresh interceptor | | Full |
| `GlobalLogoutInterceptorTests.swift` | `test_handleResponse_whenRefreshFails_triggersLogout` | Global logout interceptor | | Full |

## Summary

### Completion Status by Use Case:
- **Use Case 1 (Secure Storage)**:  100% Complete (15/15 tests)
- **Use Case 2 (User Registration)**:  100% Complete (17/17 tests)  
- **Use Case 3 (User Authentication)**:  100% Complete (22/22 tests)
- **Use Case 4 (Token Management)**:  91% Complete (11/12 tests) - Missing concurrency tests

### Total Test Coverage: 
- **65 out of 66 requirements** have corresponding test implementations
- **98.5% traceability** between technical checklists and test code
- All critical security flows are tested with both unit and integration tests

### Notes:
- All tests include proper memory leak tracking using `trackForMemoryLeaks`
- Integration tests cover end-to-end flows for user-facing features
- Snapshot tests ensure UI consistency across themes and devices
- Security tests verify both happy path and edge cases for attack scenarios