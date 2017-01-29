//
//  State.swift
//  Bolt
//
//  Created by Elliott Bolzan on 2/27/16.
//  Copyright © 2016 Elliott Bolzan. All rights reserved.
//

import UIKit

class State: UITableViewCell {

    // MARK: Properties

    @IBOutlet weak var stateImageView: UIImageView!
    @IBOutlet weak var settingsButton: UIButton!
    @IBOutlet weak var requestedView: UIView!

    var state = 0

    func setType(type: Int) {
        if type == 0 {
            let swipeUp = UISwipeGestureRecognizer(target: self, action: #selector(State.respondToGesture(_:)))
            swipeUp.direction = .Up
            self.addGestureRecognizer(swipeUp)
        }
        else {
            let swipeDown = UISwipeGestureRecognizer(target: self, action: #selector(State.respondToGesture(_:)))
            swipeDown.direction = .Down
            self.addGestureRecognizer(swipeDown)
        }
        let tap = UITapGestureRecognizer(target: self, action: #selector(State.respondToGesture(_:)))
        self.addGestureRecognizer(tap)
        state = type
    }

    func respondToGesture(gesture: UIGestureRecognizer) {
        NSNotificationCenter.defaultCenter().postNotificationName("interacted", object: state);
    }

}
