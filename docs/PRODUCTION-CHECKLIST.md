# 🚨 Production Checklist - Security & Authentication

## Critical Changes Before Production

### 1. **Token Storage Security** ⚠️
**Current:** Using `InMemoryTokenStorage` (INSECURE for production)
**Required:** Switch back to `KeychainDependencyFactory.makeTokenStorage()`

**File:** `/EssentialApp/Features/Auth/Composition/Factories/NetworkDependencyFactory.swift`