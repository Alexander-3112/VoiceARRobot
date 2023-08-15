//
//  ViewController.swift
//  VoiceARRobot
//
//  Created by Alexander Jason W on 04/08/23.
//

import UIKit
import RealityKit
import ARKit
import Speech

class ViewController: UIViewController {
    
    @IBOutlet var arView: ARView!
    var robotEntity: Entity?
    var moveToLocation : Transform = Transform()
    var moveDuration:Double = 5   //seconds
    
    //Speech Recognition
    let speechRecognozer: SFSpeechRecognizer? = SFSpeechRecognizer()
    let speechRequest = SFSpeechAudioBufferRecognitionRequest()
    var speechTask = SFSpeechRecognitionTask()
    
    //Audio
    let audioEngine = AVAudioEngine()
    let audioSession = AVAudioSession.sharedInstance()
    
    //MARK : -Functions
    override func viewDidLoad() {
        super.viewDidLoad()
    
        //Start and initialize
        startARSession()
        
        //Load 3 Model
        robotEntity = try! Entity.load(named: "03")
        
        //Tap Detector
        arView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleTap(recognizer:))))

        //Start speech Recognition
        startSpeechRecognition()
    }
    //MARK : -Object placement methods
    @objc
    func handleTap(recognizer: UITapGestureRecognizer){
        
        //Tap Location
        let tapLocation = recognizer.location(in: arView)
        
        //Raycasting (2D->3D)
        let results = arView.raycast(from: tapLocation, allowing: .estimatedPlane, alignment: .horizontal)
        
        //If Plane Detected
        if let firstResult = results.first{
            
            //3D position(x,y,z)
            let worldPos = simd_make_float3(firstResult.worldTransform.columns.3)
            
            //Place Object
            placeObject(object: robotEntity!, position: worldPos)
        }
    }
    
    func startARSession() {
        
        arView.automaticallyConfigureSession = true
        
        //Plane Detection
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal]
        configuration.environmentTexturing = .automatic
        
        arView.debugOptions = .showAnchorGeometry
        arView.session.run(configuration)
    }
 
    func placeObject(object: Entity,position: SIMD3<Float>){
        
        //1. Create anchor at 3D pos
        let objectAnchor = AnchorEntity(world: position)
        
        //2. Tie Model To Anchor
        objectAnchor.addChild(object)
        
        //3. Anchor to scene
        arView.scene.addAnchor(objectAnchor)
    }
    
    //MARK : -Object Movement
    
    func move (direction: String){
        switch direction {
            case "forward":
                //Move
                moveToLocation.translation = (robotEntity?.transform.translation)! + simd_float3(x:0, y:0, z:20)
                robotEntity?.move(to:moveToLocation,relativeTo: robotEntity,duration: moveDuration)
            
                //Walking Animation
            walkAnimation(moveDuration: moveDuration)
            
            
            case "back":
            //Move
            moveToLocation.translation = (robotEntity?.transform.translation)! + simd_float3(x:0, y:0, z:-20)
            robotEntity?.move(to:moveToLocation,relativeTo: robotEntity,duration: moveDuration)
        
            //Walking Animation
        walkAnimation(moveDuration: moveDuration)
        
            
            case "left":
            let rotateToAngle = simd_quatf(angle: GLKMathDegreesToRadians(90), axis: SIMD3(x:0,y:1,z:0))
            robotEntity?.setOrientation(rotateToAngle, relativeTo: robotEntity)
            
            case "right":
            let rotateToAngle = simd_quatf(angle: GLKMathDegreesToRadians(-90), axis: SIMD3(x:0,y:1,z:0))
            robotEntity?.setOrientation(rotateToAngle, relativeTo: robotEntity)
            
        default:
            print("No movement commands")
            
        }
    }
    func walkAnimation (moveDuration: Double){
        
        //USDZ Animation
        
        if let robotAnimation = robotEntity?.availableAnimations.first{
            
            //Play the animation
            robotEntity?.playAnimation(robotAnimation.repeat(duration: moveDuration), transitionDuration: 0.5, startsPaused: false)
        }else{
            print("No animation present in USDZ animation")
        }
    }
    
    //MARK: -Speech Recognition
    
    func startSpeechRecognition(){
        
        //1. Permission
        requestPermission()
        
        //2. Audio Record
        startAudioRecording()
        
        //3. Speech Recognition
        speechRecognize()
    }
    
    func requestPermission() {
         
        SFSpeechRecognizer.requestAuthorization { (autorizationStatus)in
            
            if(autorizationStatus == .authorized){
                print("Authorized")
            }else if ( autorizationStatus == .denied){
                print("Denied")
            }else if (autorizationStatus == .notDetermined){
                print("Waiting")
            }else if (autorizationStatus == .restricted){
                print("Speech Recognition not available")
            }
        }
    }
    
    func startAudioRecording() {
        
        //Input node
        let node = audioEngine.inputNode
        let recordingFormat = node.outputFormat(forBus: 0)
        
        node.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) {(buffer, _)in
            
            //Pass the audio samples to Speech Recognition
            self.speechRequest.append(buffer)
        }
        
        //Audio Engine Start
        do{
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            
            audioEngine.prepare()
            try audioEngine.start()
        }
        catch{
            
        }
    }
    
    func speechRecognize(){
        
        //Availability?
        guard let speechRecognizer = SFSpeechRecognizer() else {
            print("Speech recognizer not available in region")
            return
        }
        if (speechRecognizer.isAvailable == false){
            print("Temporarily not working")
        }
        
        var count = 0
           speechTask = speechRecognizer.recognitionTask(with: speechRequest, resultHandler: { (result, error) in
               count = count + 1
               if count == 1 {
                   guard let result = result else { return }
                   let recognizedText = result.bestTranscription.segments.last
                   
                   if recognizedText?.substring == "call" {
                       // Panggil fungsi untuk memanggil entity ke-2
                       print("DEBUG: call")
                       self.callEntity2()
                   } else {
                       // Panggil fungsi untuk perintah gerakan seperti sebelumnya
                       self.move(direction: recognizedText!.substring)
                       print("DEBUG: move")
                   }
               } else if count >= 3 {
                   count = 0
               }
           })
        }
    
    func callEntity2() {
        // Load entity ke-2
        let entity2 = try! Entity.load(named: "07")
        
        // Raycasting to find a suitable position on a detected plane
        let screenCenter = CGPoint(x: arView.bounds.midX, y: arView.bounds.midY)
        let results = arView.raycast(from: screenCenter, allowing: .estimatedPlane, alignment: .horizontal)
        
        // If Plane Detected
        if let firstResult = results.first {
            // Get the world position of the hit point
            let worldPos = simd_make_float3(firstResult.worldTransform.columns.3)
            
            // Place entity2 slightly above the detected plane
            let yOffset: Float = 0.1 // You can adjust this offset based on your preference
            let spawnPosition = worldPos + SIMD3<Float>(0, yOffset, 0)
            
            // Place entity2
            placeObject(object: entity2, position: spawnPosition)
        }
    }
    
    

}
