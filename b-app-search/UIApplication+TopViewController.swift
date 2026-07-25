//
//  UIApplication+TopViewController.swift
//  b-app-search
//

import UIKit

extension UIApplication {
    @MainActor
    var topViewController: UIViewController? {
        connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }?
            .rootViewController?
            .topMostPresented
    }
}

private extension UIViewController {
    @MainActor
    var topMostPresented: UIViewController {
        presentedViewController?.topMostPresented ?? self
    }
}
