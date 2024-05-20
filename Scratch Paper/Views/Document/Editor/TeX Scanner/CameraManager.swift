import Cocoa
import Combine
import AVKit

// References: https://stackoverflow.com/questions/10318260/cvpixelbufferref-to-nsimage
//             https://developer.apple.com/documentation/avfoundation/capture_setup/supporting_continuity_camera_in_your_macos_app
class CameraManager: NSObject, ObservableObject {
    
    struct Device: Hashable, Identifiable {
        static let invalid = Device(id: "-1", name: "No camera available")
        
        let id: String
        let name: String
        
        static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.id == rhs.id
        }
    }
    
    @Published private(set) var devices: [Device] = []
    
    @Published var selectedDevice: Device = .invalid
    
    lazy var cameraFeedView: CameraFeedView = {
        return CameraFeedView(from: captureSession)
    }()
    
    private static let discoverySession: AVCaptureDevice.DiscoverySession = {
        var deviceTypes: [AVCaptureDevice.DeviceType] = [.builtInWideAngleCamera]
        if #available(macOS 14.0, *) {
            deviceTypes.append(.external)
        }
        return .init(deviceTypes: deviceTypes, mediaType: .video, position: .unspecified)
    }()
    
    static var isSupported: Bool {
        return !discoverySession.devices.isEmpty
    }
    
    let captureSession: AVCaptureSession = {
        let session = AVCaptureSession()
        session.sessionPreset = .medium
        return session
    }()
    
    private var defaultDevice: AVCaptureDevice? {
        return AVCaptureDevice.systemPreferredCamera
    }
    
    private var currentCaptureInput: AVCaptureDeviceInput?
    
    private let cameraOutput = AVCapturePhotoOutput()
    
    private var cameraSettings: AVCapturePhotoSettings {
        return AVCapturePhotoSettings()
    }
    
    private var handler: (NSImage?) -> Void = { _ in }
    
    private var subscriptions = Set<AnyCancellable>()
    
    func registerSelectedDevice() {
        $selectedDevice.dropFirst().removeDuplicates().sink { [weak self] newSelection in
            self?.selectDevice(newSelection, isUserSelection: true)
        } .store(in: &subscriptions)
    }
    
    private func initialize() {
        CameraManager.discoverySession.publisher(for: \.devices).sink { newDevices in
            DispatchQueue.main.async {
                self.devices = newDevices.map { device in
                    return Device(id: device.uniqueID, name: device.localizedName)
                }
            }
        } .store(in: &subscriptions)
        
        if let captureDevice = defaultDevice {
            let device = Device(id: captureDevice.uniqueID, name: captureDevice.localizedName)
            DispatchQueue.main.async {
                self.selectedDevice = device
                
                self.registerSelectedDevice()
            }
            selectDevice(device)
        } else {
            registerSelectedDevice()
        }
        
        if (captureSession.canAddOutput(cameraOutput)) {
            captureSession.addOutput(cameraOutput)
        }
    }
    
    private func authorize() async -> Bool {
        let authorizeStatus = AVCaptureDevice.authorizationStatus(for: .video)
        if authorizeStatus == .notDetermined {
            return await AVCaptureDevice.requestAccess(for: .video)
        }
        return authorizeStatus == .authorized
    }
    
    func beginSession() async {
        guard await authorize() else {
            return
        }
        initialize()
        await MainActor.run {
            captureSession.startRunning()
        }
    }
    
    func endSession() {
        captureSession.stopRunning()
    }
    
    private func selectDevice(_ device: Device, isUserSelection: Bool = false) {
        guard (selectedDevice != device) else { return }
        
        if let captureDevice = CameraManager.discoverySession.devices
            .first(where: { $0.uniqueID == device.id }),
           let newDeviceInput = try? AVCaptureDeviceInput(device: captureDevice) {
            captureSession.beginConfiguration()
            // remove the current input device from the capture session
            if let currentInput = currentCaptureInput {
                captureSession.removeInput(currentInput)
            }
            // add the newly-selected device to the capture session as an input
            captureSession.addInput(newDeviceInput)
            currentCaptureInput = newDeviceInput
            // update the state of the system-preferred camera
            if (isUserSelection) {
                AVCaptureDevice.userPreferredCamera = captureDevice
            }
            captureSession.commitConfiguration()
        }
    }
    
    func capture(_ handler: @escaping (NSImage?) -> Void) {
        self.handler = handler
        cameraOutput.capturePhoto(with: cameraSettings, delegate: self)
    }
    
}

extension CameraManager: AVCapturePhotoCaptureDelegate {
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: (any Error)?) {
        var capturedImage: NSImage?
        if let data = photo.fileDataRepresentation(),
           let image = NSImage(data: data) {
            capturedImage = image
        }
        handler(capturedImage)
        captureSession.beginConfiguration()
        captureSession.removeOutput(cameraOutput)
        captureSession.commitConfiguration()
    }
    
}
