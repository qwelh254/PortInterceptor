//
//  KeepAlive.swift
//  后台保活：
//   1) 无声音频循环播放（需在 Info.plist 开启 UIBackgroundModes: audio），
//      使 App 进入后台后仍可运行本地代理；
//   2) 进入后台时申请额外的后台执行时间。
//
//  说明：音频保活属于 App Store 审核会拒绝的用法，仅适用于企业证书 / 自签
//  自用场景。最正规的后台保活方案仍是 Network Extension（系统级独立进程）。
//

import Foundation
import AVFoundation
import UIKit

public final class KeepAlive {
    public static let shared = KeepAlive()

    private var player: AVAudioPlayer?
    private var bgTask: UIBackgroundTaskIdentifier = .invalid

    private init() {}

    // MARK: - 启动无声播放
    public func start() {
        #if canImport(AVFoundation)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default,
                                    options: [.mixWithOthers])
            try session.setActive(true)

            if player == nil {
                let url = try SilentWAV.write()
                let p = try AVAudioPlayer(contentsOf: url)
                p.numberOfLoops = -1   // 无限循环
                p.volume = 0
                player = p
            }
            player?.prepareToPlay()
            player?.play()
        } catch {
            // 音频启动失败不影响主流程
        }
        #endif
        beginBackgroundTask()
    }

    public func stop() {
        player?.stop()
        endBackgroundTask()
    }

    // MARK: - 后台执行时间
    public func beginBackgroundTask() {
        endBackgroundTask()
        bgTask = UIApplication.shared.beginBackgroundTask(withName: "ProxyKeepAlive") { [weak self] in
            self?.endBackgroundTask()
        }
    }

    private func endBackgroundTask() {
        if bgTask != .invalid {
            UIApplication.shared.endBackgroundTask(bgTask)
            bgTask = .invalid
        }
    }
}

// MARK: - 生成 1 秒静音 WAV
enum SilentWAV {
    static func write() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("silence.wav")
        if FileManager.default.fileExists(atPath: url.path) { return url }

        let sampleRate: UInt32 = 8000
        let duration = 1
        let numSamples = sampleRate * UInt32(duration)
        let dataSize = numSamples * 1   // 8-bit mono
        let chunkSize = 36 + dataSize

        var data = Data()
        func append(_ s: String) { data.append(contentsOf: Array(s.utf8)) }
        func append32(_ v: UInt32) { var x = v.littleEndian; data.append(Data(bytes: &x, count: 4)) }
        func append16(_ v: UInt16) { var x = v.littleEndian; data.append(Data(bytes: &x, count: 2)) }

        append("RIFF"); append32(chunkSize); append("WAVE")
        append("fmt "); append32(16); append16(1)       // PCM
        append16(1); append32(sampleRate)
        append32(sampleRate); append16(1); append16(8) // block align, bits
        append("data"); append32(dataSize)
        data.append(contentsOf: [UInt8](repeating: 128, count: Int(dataSize))) // 8-bit 静音 = 128

        try data.write(to: url, options: .atomic)
        return url
    }
}
