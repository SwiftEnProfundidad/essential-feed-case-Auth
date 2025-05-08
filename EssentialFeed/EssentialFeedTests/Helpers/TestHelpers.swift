
import Foundation
import XCTest

func anyURL() -> URL {
    return URL(string: "https://any-test-url.com")!
}

extension XCTestCase {
    func trackForMemoryLeaks(_ instance: AnyObject, file: StaticString = #filePath, line: UInt = #line) {
        addTeardownBlock { [weak instance] in
            XCTAssertNil(instance, "Instance should have been deallocated. Potential memory leak.", file: file, line: line)
        }
    }
}
```
*   **IMPORTANTE:** Elimina cualquier otra definición de `anyURL()` o `trackForMemoryLeaks` de tus archivos de test individuales (`UserRegistrationUseCaseTests.swift`, etc.) para evitar conflictos.

2.  **`HTTPClientStub.swift`**
*   **Acción:** **COPIA** el archivo `HTTPClientStub.swift` desde `EssentialApp/EssentialAppTests/Helpers/HTTPClientStub.swift` a esta nueva ubicación: `/Users/juancarlosmerlosalbarracin/Developer/Essential_Developer/essential-feed-case-study/EssentialFeed/EssentialFeedTests/Helpers/HTTPClientStub.swift`.
*   Asegúrate de que este archivo copiado esté añadido al target `EssentialFeedTests`.

**Paso 5: Limpiar los Archivos de Test Unitario**

*   Abre `UserRegistrationUseCaseTests.swift` y `UserRegistrationServerUseCaseTests.swift`.
*   Elimina cualquier definición de clase `OfflineRegistrationStoreSpy`, `UserRegistrationNotifierSpy`, `RegistrationValidatorStub`, o `RegistrationValidatorAlwaysValid` que esté al final de estos archivos. Ahora usarán las versiones centralizadas.

**Paso 6: Archivo de Test de Integración (Versión Final)**

*   **Archivo:** `/Users/juancarlosmerlosalbarracin/Developer/Essential_Developer/essential-feed-case-study/EssentialFeed/EssentialFeedTests/FeaturesTest/RegistrationTest/DomainTest/IntegrationTest/UserRegistrationUseCaseIntegrationTests.swift`
*   Asegúrate de que este archivo esté añadido al target `EssentialFeedTests`.
*   **Contenido:**

