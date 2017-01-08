//
//  ViewController.swift
//  Automatic Parking Bar
//
//  Created by Yhondri on 10/12/16.
//  Copyright © 2016 Yhondri. All rights reserved.
//

import UIKit
import MobileCoreServices

class ViewController: UIViewController, UINavigationControllerDelegate {
    
    @IBOutlet weak var loadingContentView: UIView!
    @IBOutlet weak var activityIndicatorView: UIActivityIndicatorView!
    @IBOutlet weak var analizeResultLabel: UILabel!
    @IBOutlet weak var counterTitleLabel: UILabel!
    @IBOutlet weak var counterLabel: UILabel!
    @IBOutlet weak var analizeContentView: UIView!
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var analizeButtonContentView: UIView!
    
    var newMedia: Bool?
    var timerTXDelay: Timer?
    var allowTX = true
    var lastPosition: UInt8 = 255
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Watch Bluetooth connection
        NotificationCenter.default.addObserver(self, selector: #selector(ViewController.connectionChanged(_:)), name: NSNotification.Name(rawValue: BLEServiceChangedStatusNotification), object: nil)
        // Start the Bluetooth discovery process
        _ = btDiscoverySharedInstance
        activityIndicatorView.startAnimating()
        analizeButtonContentView.layer.cornerRadius = 20
        analizeButtonContentView.layer.masksToBounds = true
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(ViewController.checkVehicle))
        tapGesture.numberOfTapsRequired = 1
        analizeButtonContentView.addGestureRecognizer(tapGesture)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: BLEServiceChangedStatusNotification), object: nil)
    }
    
    func connectionChanged(_ notification: Notification) {
        // Connection status changed. Indicate on GUI.
        let userInfo = (notification as NSNotification).userInfo as! [String: Bool]
        DispatchQueue.main.async(execute: {
            // Set image based on connection status
            if let isConnected: Bool = userInfo["isConnected"] {
                if isConnected {
                    UIView.animate(withDuration: 0.25, animations: {
                        self.loadingContentView.alpha = 0
                        self.activityIndicatorView.stopAnimating()
                        self.analizeContentView.alpha = 1
                    })
                } else {
                    UIView.animate(withDuration: 0.25, animations: {
                        self.analizeContentView.alpha = 0
                        self.loadingContentView.alpha = 1
                        self.activityIndicatorView.startAnimating()
                    })
                }
            }
        })
    }
    
    @IBAction func checkVehicle() {
        if UIImagePickerController.isSourceTypeAvailable(UIImagePickerControllerSourceType.camera) {
            let imagePicker = UIImagePickerController()
            imagePicker.delegate = self
            imagePicker.sourceType =
                UIImagePickerControllerSourceType.camera
            imagePicker.mediaTypes = [kUTTypeImage as String]
            imagePicker.allowsEditing = false
            self.present(imagePicker, animated: true, completion: nil)
            newMedia = true
        }
    }
    
    func analizePhoto() {
        analizeButtonContentView.isHidden = true
        analizeResultLabel.isHidden = false
        let color = areaAverage()
        if UIColor.red.isEqualToColor(color: color, withTolerance: 0.5) {
            analizeResultLabel.text = "Vehículo autorizado"
            counterTitleLabel.isHidden = false
            counterTitleLabel.text = "La barrera se cerrará en:"
            counterLabel.isHidden = false
            sendPosition(90)
            incrementLabel(to: 10)
        }else {
            analizeButtonContentView.isHidden = false
            analizeResultLabel.text = "Vehículo no autorizado"
        }
    }
    
    func incrementLabel(to endValue: Int) {
        let animationPeriod: Double = 10.0 //seconds
        let sleepTime = UInt32(animationPeriod * 100000.0)
        DispatchQueue.global().async {
            for i in 0 ..< (endValue + 1) {
                usleep(sleepTime)
                DispatchQueue.main.async {
                    self.counterLabel.text = "\(10-i)"
                    if i == 10 {
                        self.closeParkingBar()
                    }
                }
            }
        }
    }
    
    func closeParkingBar() {
        sendPosition(180)
        analizeResultLabel.isHidden = true
        counterLabel.isHidden = true
        counterLabel.text = "0"
        counterTitleLabel.isHidden = true
        analizeButtonContentView.isHidden = false
        imageView.isHidden = true
        imageView.image = nil
    }
    
    func areaAverage() -> UIColor {
        if let cgImage = imageView.image?.cgImage {
            var bitmap = [UInt8](repeating: 0, count: 4)
            let context = CIContext(options: nil)
            let cgImg = context.createCGImage(CoreImage.CIImage(cgImage: cgImage), from: CoreImage.CIImage(cgImage: cgImage).extent)
            let inputImage = CIImage(cgImage: cgImg!)
            let extent = inputImage.extent
            let inputExtent = CIVector(x: extent.origin.x, y: extent.origin.y, z: extent.size.width, w: extent.size.height)
            let filter = CIFilter(name: "CIAreaAverage", withInputParameters: [kCIInputImageKey: inputImage, kCIInputExtentKey: inputExtent])!
            let outputImage = filter.outputImage!
            let outputExtent = outputImage.extent
            assert(outputExtent.size.width == 1 && outputExtent.size.height == 1)
            // Render to bitmap.
            context.render(outputImage, toBitmap: &bitmap, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: kCIFormatRGBA8, colorSpace: CGColorSpaceCreateDeviceRGB())
            // Compute result.
            let result = UIColor(red: CGFloat(bitmap[0]) / 255.0, green: CGFloat(bitmap[1]) / 255.0, blue: CGFloat(bitmap[2]) / 255.0, alpha: CGFloat(bitmap[3]) / 255.0)
            return result
        }else {
            return UIColor.black
        }
    }
    
    func sendPosition(_ position: UInt8) {
        // Valid position range: 0 to 180
        if !allowTX {
            return
        }
        
        // Validate value
        if position == lastPosition {
            return
        }
        else if ((position < 0) || (position > 180)) {
            return
        }
        
        // Send position to BLE Shield (if service exists and is connected)
        if let bleService = btDiscoverySharedInstance.bleService {
            bleService.writePosition(position)
            lastPosition = position;
        }
    }
}

extension ViewController: UIImagePickerControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        
        let mediaType = info[UIImagePickerControllerMediaType] as! NSString
        self.dismiss(animated: true, completion: nil)
        
        if mediaType.isEqual(to: kUTTypeImage as String) {
            let image = info[UIImagePickerControllerOriginalImage] as! UIImage
            
            imageView.image = image
            imageView.isHidden = false
            self.analizePhoto()
            
            if (newMedia == true) {
                UIImageWriteToSavedPhotosAlbum(image, self, #selector(ViewController.image(image:didFinishSavingWithError:contextInfo:)), nil)
            } else if mediaType.isEqual(to: kUTTypeMovie as String) {
                // Code to support video here
            }
        }
    }
    
    func image(image: UIImage, didFinishSavingWithError error: NSErrorPointer, contextInfo:UnsafeRawPointer) {
        if error != nil {
            let alert = UIAlertController(title: "Save Failed",
                                          message: "Failed to save image",
                                          preferredStyle: UIAlertControllerStyle.alert)
            
            let cancelAction = UIAlertAction(title: "OK",
                                             style: .cancel, handler: nil)
            
            alert.addAction(cancelAction)
            self.present(alert, animated: true,
                         completion: nil)
        }
    }
}

extension UIColor{
    func isEqualToColor(color: UIColor, withTolerance tolerance: CGFloat = 0.0) -> Bool{
        var r1 : CGFloat = 0
        var g1 : CGFloat = 0
        var b1 : CGFloat = 0
        var a1 : CGFloat = 0
        var r2 : CGFloat = 0
        var g2 : CGFloat = 0
        var b2 : CGFloat = 0
        var a2 : CGFloat = 0
        
        self.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        color.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        
        return
            fabs(r1 - r2) <= tolerance &&
                fabs(g1 - g2) <= tolerance &&
                fabs(b1 - b2) <= tolerance &&
                fabs(a1 - a2) <= tolerance
    }
}


