//
//  VideoParkingViewController.swift
//  Automatic Parking Bar
//
//  Created by Yhondri on 8/1/17.
//  Copyright © 2017 Yhondri. All rights reserved.
//

import UIKit
import AVFoundation
import MobileCoreServices

class VideoParkingViewController: UIViewController {
    
    @IBOutlet weak var cameraView: UIView!
    @IBOutlet weak var messageLabel: UILabel!
    
    // MARK: - Private Properties
    fileprivate var stillImageOutput: AVCapturePhotoOutput!
    fileprivate let captureSession = AVCaptureSession()
    fileprivate let device = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeVideo)
    var allowTX = true
    var lastPosition: UInt8 = 255
    
    init() {
        super.init(nibName: "VideoParkingViewController", bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(self, selector: #selector(ViewController.connectionChanged(_:)), name: NSNotification.Name(rawValue: BLEServiceChangedStatusNotification), object: nil)
        _ = btDiscoverySharedInstance
        
        
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
                        // start camera init
                        DispatchQueue.global(qos: .userInitiated).async {
                            if self.device != nil {
                                self.configureCameraForUse()
                            }
                        }
                        self.messageLabel.text = "Conexión establecida, el dispositivo está listo para procesar imágenes"
                    })
                } else {
                    self.messageLabel.text = "CHa ocurrido un error, no se ha podido establecer conexión con el dispositivo mediante bluetooth"
                }
            }
        })
    }
    
    @IBAction func takePhoto(_ sender: Any) {
        DispatchQueue.global(qos: .userInitiated).async {
            let settings = AVCapturePhotoSettings()
            let previewPixelType = settings.availablePreviewPhotoPixelFormatTypes.first!
            let previewFormat = [kCVPixelBufferPixelFormatTypeKey as String: previewPixelType,
                                 kCVPixelBufferWidthKey as String: 160,
                                 kCVPixelBufferHeightKey as String: 160,
                                 ]
            settings.previewPhotoFormat = previewFormat
            self.stillImageOutput.capturePhoto(with: settings, delegate: self)
        }
    }
    
    
    // MARK: AVFoundation
    fileprivate func configureCameraForUse () {
        self.stillImageOutput = AVCapturePhotoOutput()
        let fullResolution = UIDevice.current.userInterfaceIdiom == .phone && max(UIScreen.main.bounds.size.width, UIScreen.main.bounds.size.height) < 568.0
        
        if fullResolution {
            self.captureSession.sessionPreset = AVCaptureSessionPresetPhoto
        } else {
            self.captureSession.sessionPreset = AVCaptureSessionPreset1280x720
        }
        
        self.captureSession.addOutput(self.stillImageOutput)
        
        DispatchQueue.global(qos: .userInitiated).async {
            self.prepareCaptureSession()
        }
    }
    
    private func prepareCaptureSession () {
        do {
            self.captureSession.addInput(try AVCaptureDeviceInput(device: self.device))
        } catch {
            print("AVCaptureDeviceInput Error")
        }
        
        //        // layer customization
        let previewLayer = AVCaptureVideoPreviewLayer(session: self.captureSession)
        previewLayer?.frame.size = cameraView.frame.size
        previewLayer?.frame.origin = CGPoint.zero
        previewLayer?.videoGravity = AVLayerVideoGravityResizeAspectFill
        
        // device lock is important to grab data correctly from image
        do {
            try self.device?.lockForConfiguration()
            self.device?.focusPointOfInterest = CGPoint(x: 0.5, y: 0.5)
            self.device?.focusMode = .continuousAutoFocus
            self.device?.unlockForConfiguration()
        } catch {
            print("captureDevice?.lockForConfiguration() denied")
        }
        
        //Set initial Zoom scale
        do {
            let device = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeVideo)
            try device?.lockForConfiguration()
            
            let zoomScale: CGFloat = 2.5
            
            if zoomScale <= (device?.activeFormat.videoMaxZoomFactor)! {
                device?.videoZoomFactor = zoomScale
            }
            
            device?.unlockForConfiguration()
        } catch {
            print("captureDevice?.lockForConfiguration() denied")
        }
        
        DispatchQueue.main.async(execute: {
            self.cameraView.layer.addSublayer(previewLayer!)
            self.captureSession.startRunning()
        })
    }
    func analizeImage(_ image: UIImage) {
        
        let color = averageColor(from: image)
        if UIColor.red.isEqualToColor(color: color, withTolerance: 0.5) {
            self.messageLabel.text = "Vehículo autorizado, tienes 10 segundos para pasar"
            //            analizeResultLabel.text = "Vehículo autorizado"
            //            counterTitleLabel.isHidden = false
            //            counterTitleLabel.text = "La barrera se cerrará en:"
            //            counterLabel.isHidden = false
            sendPosition(90)
            closeBarAfter(10)
            //            incrementLabel(to: 10)
        }else if lastPosition != 180 {
            self.messageLabel.text = "Vehículo no autorizado"
            sendPosition(180)
            //            analizeButtonContentView.isHidden = false
            //            analizeResultLabel.text = "Vehículo no autorizado"
        }
    }
    
    func averageColor(from image: UIImage) -> UIColor {
        if let cgImage = image.cgImage {
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
    
    func closeBarAfter(_ seconds: Int) {
        let animationPeriod: Double = Double(seconds) //seconds
        let sleepTime = UInt32(animationPeriod * 100000.0)
        DispatchQueue.global().async {
            for i in 0 ..< (seconds + 1) {
                usleep(sleepTime)
                DispatchQueue.main.async {
                    self.messageLabel.text = "Vehículo autorizado, tienes \(seconds-i) segundos para pasar"
                    if i == 10 {
                        self.messageLabel.text = "Esperando..."
                        self.sendPosition(180)
                    }
                }
            }
        }
    }
}

extension VideoParkingViewController: AVCapturePhotoCaptureDelegate {
    func capture(_ captureOutput: AVCapturePhotoOutput, didFinishProcessingPhotoSampleBuffer photoSampleBuffer: CMSampleBuffer?, previewPhotoSampleBuffer: CMSampleBuffer?, resolvedSettings: AVCaptureResolvedPhotoSettings, bracketSettings: AVCaptureBracketedStillImageSettings?, error: Error?) {
        if let error = error {
            print(error.localizedDescription)
        }
        
        if let sampleBuffer = photoSampleBuffer, let previewBuffer = previewPhotoSampleBuffer, let dataImage = AVCapturePhotoOutput.jpegPhotoDataRepresentation(forJPEGSampleBuffer: sampleBuffer, previewPhotoSampleBuffer: previewBuffer) {
            debugPrint("image: \(UIImage(data: dataImage)?.size)")
            if let image = UIImage(data: dataImage){
                analizeImage(image)
            }
        } else {
            debugPrint("Error taking image")
        }
    }
}
