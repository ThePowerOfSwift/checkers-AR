//
//  ViewController.swift
//  Checkers-AR
//
//  Created by Nikolas Chaconas on 10/21/16.
//  Copyright © 2016 Nikolas Chaconas. All rights reserved.
//

import UIKit
import AVFoundation
import OpenGLES

class ViewController: UIViewController, UINavigationControllerDelegate, AVCaptureVideoDataOutputSampleBufferDelegate, GLKViewDelegate {
    var calibrator : OpenCVWrapper = OpenCVWrapper()
    var openGL : OpenGLWrapper = OpenGLWrapper()
    @IBOutlet weak var calibrationInstructionsLabel: UILabel!
    var totalCalibrated = 0
    @IBOutlet weak var leftToCalibrateLabel: UILabel!
    let ud = UserDefaults.standard
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var previewView: UIImageView!
    @IBOutlet weak var calibrateImageButton: UIButton!
    @IBOutlet weak var beginGameButton: UIButton!
    @IBOutlet weak var beginCalibrationButton: UIButton!
    @IBOutlet weak var playAgainButton: UIButton!
    var calibratePressed : Bool = false
    var session = AVCaptureSession()
    var playing = false
    var rotation = ""
    var openGLInitialized = false
    var previewLayer = AVCaptureVideoPreviewLayer()
    var playingLayer = CALayer()
    @IBOutlet weak var successLabel: UILabel!
    @IBOutlet weak var gameOverLabel: UILabel!
    @IBOutlet weak var glkView: GLKView!
    @IBOutlet weak var scoreLabel: UILabel!
    var context : EAGLContext = EAGLContext.init(api: EAGLRenderingAPI.openGLES1)
    var effect = GLKBaseEffect()
    var currentImage : UIImage = UIImage()
    var imageSize : CGSize = CGSize()
    var frameBuffer : GLuint = GLuint()
    var gameOver : Int = 0
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
            beginGameButton.layer.cornerRadius = 5
            calibrateImageButton.layer.cornerRadius = 5
            beginCalibrationButton.layer.cornerRadius = 5
            playAgainButton.isHidden = true
            gameOverLabel.isHidden = true
            glkView.delegate = self
        
            if let data = ud.object(forKey: "calibrator") as? NSData {
                print("retrieving calibrator data")
                let sync = ud.synchronize()
                
                if(sync == true) {
                    print("CALIBRATION can be LOADED")
                }
                calibrator = NSKeyedUnarchiver.unarchiveObject(with: data as Data) as! OpenCVWrapper
                
                print("saving calibration data")
                
                
                removeCalibrationPrompts()
            } else {
                print("calibrator not saved")
            }
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func removeCalibrationPrompts() {
        beginCalibrationButton.setTitle("Redo Checkerboard Calibration", for: .normal)
        beginCalibrationButton.alpha = 0.2;
        beginGameButton.alpha = 1.0;
        calibrateImageButton.alpha = 0.0
    }
    
    func finishCalibration() {
        print("done calibrating")
        
        //compute intrinsic camera values
        calibrator.finishCalibration()
        
        //remove all calibration buttons/labels
        removeCalibrationPrompts()

        //save calibration data so we don't have to calibrate next time user uses the app
        ud.set(NSKeyedArchiver.archivedData(withRootObject: calibrator), forKey: "calibrator")
        let sync = ud.synchronize()
        
        if(sync == true) {
            print("CALIBRATION DATA SAVED")
        }
        
        
        //will want to shut off camera and stuff here
        leftToCalibrateLabel.alpha = 0.0
        calibrationInstructionsLabel.alpha = 0.0
        session.stopRunning()
        
        successLabel.alpha = 1.0
        UIView.animate(withDuration: 2.70, animations: {
            self.successLabel.alpha = 0.0
        })
        beginGameButton.isHidden = false
        clearLayers()
    }
    
    func calibrateImage(pickedImage: UIImage) {
        print("calibrating Image...")
        //disable button while calibrating
        calibrateImageButton.isEnabled = false;
        var img: UIImage
        img = calibrator.findChessboardCorners(pickedImage)
        
        //display calibrated image over camera view
        previewView.alpha = 1.0
        previewView.contentMode = .scaleAspectFill
        previewView.image = img
        
        //fade away calibrated image so user can take another image
        UIView.animate(withDuration: 2.70, animations: {
            self.previewView.alpha = 0.0
        })
        
        //increment calibrated count
        totalCalibrated += 1
        let leftToCalibrate = 10 - totalCalibrated
        leftToCalibrateLabel.text = "\(leftToCalibrate) Images Left To Calibrate"
        
        //only need 10 images to calibrate
        if(totalCalibrated == 10) {
            finishCalibration()
        } else {
            calibrateImageButton.isEnabled = true;
        }
    }

    func setPreviewLayer() {
        clearLayers()
        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.frame = imageView.bounds;
        previewLayer.videoGravity = AVLayerVideoGravityResizeAspect;

        imageView.layer.addSublayer(previewLayer)
    }
    
    @IBAction func beginCalibrationButtonPressed(_ sender: AnyObject) {
        //reset class
        openGL.destroyFrameBuffer()
        self.scoreLabel.isHidden = true;
        playAgainButton.isHidden = true
        self.imageView.isHidden = false
        self.previewView.isHidden = false
        gameOverLabel.isHidden = true
        calibrator = OpenCVWrapper()
        session.stopRunning()
        playing = false
        imageView.image = nil
        beginGameButton.alpha = 0.0
        beginCalibrationButton.alpha = 0.0
        calibrateImageButton.isEnabled = true
        totalCalibrated = 0
        leftToCalibrateLabel.text = "10 Images Left To Calibrate"
        print("setting bloop")
        calibrator.setBloop(5000)
        
        //don't need to reinitialize camera if we've already used it
        if(session.inputs.isEmpty) {
            startCameraSession()
        } else {
            setPreviewLayer()
            session.startRunning()
        }
        
        //show calibration labels/buttons
        calibrationInstructionsLabel.alpha = 1.0
        leftToCalibrateLabel.alpha = 1.0
        calibrateImageButton.alpha = 1.0
    }
    
    func startCameraSession() {
        if session.canSetSessionPreset(AVCaptureSessionPresetMedium) {
            session.sessionPreset = AVCaptureSessionPresetMedium
        }
        
        let backCamera = AVCaptureDevice.defaultDevice(withMediaType:AVMediaTypeVideo)
        do
        {
            let input = try AVCaptureDeviceInput(device: backCamera)
            session.addInput(input)
        }
        catch
        {
            print("can't access camera")
            return
        }
        
        if(!playing && (imageView.layer.sublayers) == nil) {
            setPreviewLayer()
        }

        
        let output = AVCaptureVideoDataOutput()
        let queue = DispatchQueue(label: "queue")
        output.setSampleBufferDelegate(self, queue: queue)
        output.alwaysDiscardsLateVideoFrames = true
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as NSString: NSNumber(value: kCVPixelFormatType_32BGRA)]

        session.addOutput(output)

        session.startRunning()
    }

    func clearLayers() {
        imageView.layer.sublayers = nil
    }
    
    func setPlayingLayer() {
        clearLayers()
//        playingLayer.transform = CATransform3DMakeRotation(90.0 * 3.14 / 180.0, 0.0, 0.0, 1.0);
        playingLayer.frame = self.imageView.bounds
        playingLayer.contentsGravity = kCAGravityCenter
        self.imageView.layer.addSublayer(playingLayer)
    }
    
    @IBAction func beginGameButtonPressed(_ sender: AnyObject) {
        //don't need to reinitialize camera if we've already used it
        openGL.newGame()
        self.scoreLabel.isHidden = false
        self.scoreLabel.text = "Gray: \(openGL.getTeam0Score()) Red: \(openGL.getTeam1Score())"
        openGL.createFramebuffer()
        initializeOpenGL()
        beginGameButton.isHidden = true
        glkView.isHidden = false
        playing = !playing;
        if(playing) {
            setPlayingLayer()
            if(session.inputs.isEmpty) {
                startCameraSession()
            } else {
                session.startRunning()
            }
        } else {
            clearLayers()
            session.stopRunning()
        }
    }
    
    func tapOnGLKView(_ touch:UITapGestureRecognizer) {
        let point = touch.location(in: self.glkView)
        var winningTeam : Int
        gameOver = Int(openGL.tap(onScreen: Float(point.x), Float(point.y)))
        self.scoreLabel.text = "Gray: \(openGL.getTeam0Score()) Red: \(openGL.getTeam1Score())"
        if (gameOver == 1) {
            print("GAME OVER AGAIN")
            winningTeam = Int(openGL.teamWon())
            UIView.animate(withDuration: 5.70, animations: {
                self.imageView.isHidden = true
                self.previewView.isHidden = true
                self.glkView.isHidden = true
                self.playAgainButton.layer.cornerRadius = 5
                self.beginGameButton.isHidden = true
                if (winningTeam == 0) {
                    self.gameOverLabel.numberOfLines = 2
                    self.gameOverLabel.text = "Game Over!\n Gray Team Wins!"
                } else {
                    self.gameOverLabel.numberOfLines = 2
                    self.gameOverLabel.text = "Game Over!\n Red Team Wins!"
                }
                self.playAgainButton.isHidden = false
                self.gameOverLabel.isHidden = false
            })
        }
//        print("x: \(point.x) y: \(point.y)")
    }
    @IBAction func playAgainButtonPressed(_ sender: Any) {
        self.scoreLabel.isHidden = false
        playAgainButton.isHidden = true
        gameOverLabel.isHidden = true
        glkView.isHidden = false
        imageView.isHidden = false
        previewView.isHidden = false
        openGL.newGame()
    }
    
    func initializeOpenGL() {
        let x = (playingLayer.bounds.width - imageSize.width) / 2.0
        let y = (playingLayer.bounds.height - imageSize.height) / 2.0
        
        print(x);
        print(y)
        
        glkView.frame = CGRect(x: x, y: y, width: imageSize.width, height: imageSize.height)
        
        openGL = calibrator.initializeOpenGL()
        openGL.setView(self.glkView)
        
        
        print("setting context")
        EAGLContext.setCurrent(context)
        glkView.context = context
        glkView.enableSetNeedsDisplay = true;
        glkView.drawableColorFormat = GLKViewDrawableColorFormat.RGBA8888
        glkView.drawableDepthFormat = GLKViewDrawableDepthFormat.formatNone
        glkView.drawableStencilFormat = GLKViewDrawableStencilFormat.formatNone
        glkView.drawableMultisample = GLKViewDrawableMultisample.multisampleNone
        glkView.bindDrawable()
        glkView.isOpaque = false
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(self.tapOnGLKView(_:)))
        tap.numberOfTapsRequired = 1
        glkView.addGestureRecognizer(tap)
        
        openGL.setParams(effect, cont: glkView.context, width: Double(imageSize.width), height: Double(imageSize.height))
    }
    
    func glkView(_ view: GLKView, drawIn rect: CGRect) {
        var found : Int32 = 0
        
        let newImage = openGL.drawObjects(self.currentImage, &found)
        
        self.playingLayer.contents = newImage?.cgImage;
    }
    
    @IBAction func calibrateImageButtonPressed(_ sender: AnyObject) {
        calibratePressed = true
    }
    
    //flip the image
    func flipImage(oldImage: UIImage) -> UIImage {
        //Calculate the size of the rotated view's containing box for our drawing space
        let rotatedViewBox: UIView = UIView(frame: CGRect(x: 0, y: 0, width: oldImage.size.width, height: oldImage.size.height))
        let t: CGAffineTransform = CGAffineTransform(rotationAngle: 90 * CGFloat(M_PI / 180))
        rotatedViewBox.transform = t
        let rotatedSize: CGSize = rotatedViewBox.frame.size
        //Create the bitmap context
        UIGraphicsBeginImageContext(rotatedSize)
        let bitmap: CGContext = UIGraphicsGetCurrentContext()!
        //Move the origin to the middle of the image so we will rotate and scale around the center.
        bitmap.translateBy(x: rotatedSize.width / 2, y: rotatedSize.height / 2)
        //Rotate the image context
        bitmap.rotate(by: (90 * CGFloat(M_PI / 180)))
        //Now, draw the rotated/scaled image into the context
        bitmap.scaleBy(x: 1.0, y: -1.0)
        
        bitmap.draw(oldImage.cgImage!, in: CGRect(x: -oldImage.size.width/2, y: -oldImage.size.height / 2, width: oldImage.size.width, height: oldImage.size.height))
        
        let newImage: UIImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return newImage
        
    }
    
    //delegate for when frame is captured
    //override
    func captureOutput(_ captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, from connection: AVCaptureConnection!) {
        if(calibratePressed) {
            playAgainButton.isHidden = true
            calibratePressed = false
            var img : UIImage = imageFromSampleBuffer(sampleBuffer: sampleBuffer);
            img = flipImage(oldImage: img)
            DispatchQueue.main.async {
                self.calibrateImage(pickedImage: img)
            }
        }
        if(playing) {
            var img : UIImage = imageFromSampleBuffer(sampleBuffer: sampleBuffer);
            img = flipImage(oldImage: img)
            DispatchQueue.main.async {
                
                if(self.openGLInitialized == false) {
                    self.openGLInitialized = true
                    self.imageSize = img.size
                    self.initializeOpenGL()
                }
                
                self.currentImage = img;
                self.glkView.display()
            }
        }
    }
    
    //courtesy of apple documentation
    //https://developer.apple.com/library/content/qa/qa1702/_index.html
    func imageFromSampleBuffer(sampleBuffer: CMSampleBuffer) -> UIImage {
        // Get a CMSampleBuffer's Core Video image buffer for the media data
        let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
        // Lock the base address of the pixel buffer
        CVPixelBufferLockBaseAddress(imageBuffer!, CVPixelBufferLockFlags(rawValue: CVOptionFlags(0)))
        
        // Get the number of bytes per row for the pixel buffer
        let baseAddress = CVPixelBufferGetBaseAddress(imageBuffer!)
        
        // Get the number of bytes per row for the pixel buffer
        let bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer!)
        // Get the pixel buffer width and height
        let width = CVPixelBufferGetWidth(imageBuffer!)
        let height = CVPixelBufferGetHeight(imageBuffer!)
        
        // Create a device-dependent RGB color space
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        // Create a bitmap graphics context with the sample buffer data
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
        let context = CGContext(data: baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: bitmapInfo.rawValue)
        // Create a Quartz image from the pixel data in the bitmap graphics context
        let quartzImage = context!.makeImage();
        // Unlock the pixel buffer
        CVPixelBufferUnlockBaseAddress(imageBuffer!,CVPixelBufferLockFlags(rawValue: CVOptionFlags(0)));
        
        // Create an image object from the Quartz image
        let image = UIImage(cgImage: quartzImage!, scale: 1.0, orientation: UIImageOrientation.up)
        
        return image
    }

}

