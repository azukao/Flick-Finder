//
//  GCDBlackBox.swift
//  FlickFinder
//
//  Created by Azuka Omesiete on 07/5/16.
//  Copyright © 2016 Azuka Omesiete. All rights reserved.
//

import Foundation

func performUIUpdatesOnMain(updates: () -> Void) {
    dispatch_async(dispatch_get_main_queue()) {
        updates()
    }
}
