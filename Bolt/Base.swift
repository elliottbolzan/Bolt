//
//  Base.swift
//
//
//  Created by Elliott Bolzan on 3/16/16.
//
//

import UIKit

class Base: UIViewController {

    override func viewDidAppear(animated: Bool) {
        if defaults.objectForKey("viewedIntro") == nil {
            let introVC = self.storyboard?.instantiateViewControllerWithIdentifier("Intro")
            self.presentViewController(introVC!, animated: true, completion: nil)
        }
        else if defaults.objectForKey("room_id") != nil {
            let mainVC = self.storyboard?.instantiateViewControllerWithIdentifier("Main")
            self.presentViewController(mainVC!, animated: true, completion: nil)
        }
        else {
            let navigationVC = self.storyboard?.instantiateViewControllerWithIdentifier("Navigation") as! UINavigationController
            navigationVC.viewControllers = [self.storyboard!.instantiateViewControllerWithIdentifier("Setup")]
            self.presentViewController(navigationVC, animated: true, completion: nil)
        }
    }

}
