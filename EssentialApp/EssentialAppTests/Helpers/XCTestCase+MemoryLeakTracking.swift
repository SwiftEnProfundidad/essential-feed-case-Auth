//
//  Copyright 2019 Essential Developer. All rights reserved.
//

import XCTest

extension XCTestCase {
    func trackForMemoryLeaks(_ instance: AnyObject, file: StaticString = #filePath, line: UInt = #line) {
        addTeardownBlock { [weak instance] in
            // --- INICIO DEL CAMBIO ---
            // Añadimos un breve giro del RunLoop para dar tiempo a que las deallocaciones pendientes ocurran,
            // especialmente para objetos de UI que pueden tener ciclos de vida más complejos
            // o depender de autorelease pools que se vacían al final del ciclo del RunLoop.

            // Usamos un delay un poco mayor para UIViewController e UIView, ya que suelen ser
            // los que presentan estas deallocaciones ligeramente demoradas en tests.
            // Si esto no es suficiente, se podría aumentar un poco más, pero con cautela
            // para no ralentizar innecesariamente los tests.

            // if instance is UIViewController || instance is UIView {
            //      RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
            // } else {
            //      RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.01))
            // }
            // --- FIN DEL CAMBIO ---

            XCTAssertNil(instance, "Instance should have been deallocated. Potential memory leak.", file: file, line: line)
        }
    }
}
