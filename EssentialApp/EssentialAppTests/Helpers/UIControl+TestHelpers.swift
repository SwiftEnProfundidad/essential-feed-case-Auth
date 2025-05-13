//
//  Copyright © 2019 Essential Developer. All rights reserved.
//

import UIKit

extension UIControl {
    func simulate(event: UIControl.Event) {
        for target in allTargets {
            actions(forTarget: target, forControlEvent: event)?.forEach {
                (target as NSObject).perform(Selector($0))
            }
        }
    }
}
