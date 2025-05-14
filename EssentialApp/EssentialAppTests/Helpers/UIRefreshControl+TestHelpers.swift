//
//  Copyright 2019 Essential Developer. All rights reserved.
//

import UIKit

extension UIRefreshControl {
    func simulatePullToRefresh() {
        // ADD: If it's a FakeRefreshControl, directly call beginRefreshing
        // This ensures its internal state _isRefreshing becomes true
        // and then send the action.
        if let fakeControl = self as? FakeRefreshControl {
            fakeControl.beginRefreshing()
        }
        simulate(event: .valueChanged) // This will send the action to any targets
    }
}
