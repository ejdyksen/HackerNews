//
//  ActivityView.swift
//  HackerNews (iOS)
//
//  Created by E.J. Dyksen on 6/22/21.
//

import SwiftUI

struct ActivityView: UIViewControllerRepresentable {

    var activityItems: [Any]
    
    var applicationActivities: [UIActivity]? = nil

    @Environment(\.presentationMode) var presentationMode

    func makeUIViewController(context: UIViewControllerRepresentableContext<ActivityView>) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
        controller.completionWithItemsHandler = { (activityType, completed, returnedItems, error) in
            self.presentationMode.wrappedValue.dismiss()
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: UIViewControllerRepresentableContext<ActivityView>) {}

}
