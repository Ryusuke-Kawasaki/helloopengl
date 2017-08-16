//
//  ViewController.swift
//  HelloOpenGL
//
//  Created by 川崎隆介 on 2017/08/16.
//  Copyright © 2017年 codable. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        let frame = UIScreen.main.bounds
        let _glView = OpenGLView(frame: frame)
        
        self.view.addSubview(_glView)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

