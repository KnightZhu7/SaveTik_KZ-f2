//
//  APIService.swift
//  SaveTikKZ
//
//  Created by Knight Zhu on 2/8/26.
//  Refactored to 100% Pure Swift Native Engine by Antigravity on 9/4/26.
//
//  Portions of this file (specifically SM3, RC4, and ABogus algorithm implementations)
//  are derived and ported from the `f2` project (https://github.com/Johnserf-Seed/f2).
//  Copyright (c) 2023-present JohnserfSeed, licensed under the Apache License, Version 2.0.
//

import Foundation
import WebKit

// MARK: - SM3 National Standard Cryptographic Hash (GB/T 32918-2016)
nonisolated public struct SM3 {
    private static let IV: [UInt32] = [
        0x7380166f, 0x4914b2b9, 0x172442d7, 0xda8a0600,
        0xa96f30bc, 0x163138aa, 0xe38dee4d, 0xb0fb0e4e
    ]
    
    @inline(__always)
    private static func rotl(_ x: UInt32, _ n: UInt32) -> UInt32 {
        return (x << n) | (x >> (32 - n))
    }
    
    @inline(__always)
    private static func P0(_ x: UInt32) -> UInt32 {
        return x ^ rotl(x, 9) ^ rotl(x, 17)
    }
    
    @inline(__always)
    private static func P1(_ x: UInt32) -> UInt32 {
        return x ^ rotl(x, 15) ^ rotl(x, 23)
    }
    
    @inline(__always)
    private static func FF0(_ x: UInt32, _ y: UInt32, _ z: UInt32) -> UInt32 {
        return x ^ y ^ z
    }
    
    @inline(__always)
    private static func FF1(_ x: UInt32, _ y: UInt32, _ z: UInt32) -> UInt32 {
        return (x & y) | (x & z) | (y & z)
    }
    
    @inline(__always)
    private static func GG0(_ x: UInt32, _ y: UInt32, _ z: UInt32) -> UInt32 {
        return x ^ y ^ z
    }
    
    @inline(__always)
    private static func GG1(_ x: UInt32, _ y: UInt32, _ z: UInt32) -> UInt32 {
        return (x & y) | ((~x) & z)
    }
    
    public static func hash(_ data: [UInt8]) -> [UInt8] {
        let bitLen = UInt64(data.count) * 8
        var msg = data
        msg.append(0x80)
        
        while (msg.count % 64) != 56 {
            msg.append(0x00)
        }
        
        for i in (0..<8).reversed() {
            msg.append(UInt8((bitLen >> (UInt64(i) * 8)) & 0xff))
        }
        
        var V = IV
        let blockCount = msg.count / 64
        
        for b in 0..<blockCount {
            let offset = b * 64
            var W = [UInt32](repeating: 0, count: 68)
            var W1 = [UInt32](repeating: 0, count: 64)
            
            for j in 0..<16 {
                let idx = offset + j * 4
                W[j] = (UInt32(msg[idx]) << 24) |
                       (UInt32(msg[idx + 1]) << 16) |
                       (UInt32(msg[idx + 2]) << 8) |
                       UInt32(msg[idx + 3])
            }
            
            for j in 16..<68 {
                let tmp = W[j - 16] ^ W[j - 9] ^ rotl(W[j - 3], 15)
                W[j] = P1(tmp) ^ rotl(W[j - 13], 7) ^ W[j - 6]
            }
            
            for j in 0..<64 {
                W1[j] = W[j] ^ W[j + 4]
            }
            
            var A = V[0], B = V[1], C = V[2], D = V[3]
            var E = V[4], F = V[5], G = V[6], H = V[7]
            
            for j in 0..<64 {
                let Tj: UInt32 = (j < 16) ? 0x79cc4519 : 0x7a879d8a
                let SS1 = rotl(rotl(A, 12) &+ E &+ rotl(Tj, UInt32(j % 32)), 7)
                let SS2 = SS1 ^ rotl(A, 12)
                let TT1 = ((j < 16) ? FF0(A, B, C) : FF1(A, B, C)) &+ D &+ SS2 &+ W1[j]
                let TT2 = ((j < 16) ? GG0(E, F, G) : GG1(E, F, G)) &+ H &+ SS1 &+ W[j]
                
                D = C
                C = rotl(B, 9)
                B = A
                A = TT1
                H = G
                G = rotl(F, 19)
                F = E
                E = P0(TT2)
            }
            
            V[0] ^= A
            V[1] ^= B
            V[2] ^= C
            V[3] ^= D
            V[4] ^= E
            V[5] ^= F
            V[6] ^= G
            V[7] ^= H
        }
        
        var result = [UInt8]()
        result.reserveCapacity(32)
        for v in V {
            result.append(UInt8((v >> 24) & 0xff))
            result.append(UInt8((v >> 16) & 0xff))
            result.append(UInt8((v >> 8) & 0xff))
            result.append(UInt8(v & 0xff))
        }
        return result
    }
}

// MARK: - RC4 Stream Cipher
nonisolated public struct RC4 {
    public static func encrypt(key: [UInt8], data: [UInt8]) -> [UInt8] {
        var S = Array(0..<256).map { UInt8($0) }
        var j: Int = 0
        for i in 0..<256 {
            j = (j + Int(S[i]) + Int(key[i % key.count])) % 256
            S.swapAt(i, j)
        }
        var i: Int = 0
        j = 0
        var result = [UInt8]()
        result.reserveCapacity(data.count)
        for byte in data {
            i = (i + 1) % 256
            j = (j + Int(S[i])) % 256
            S.swapAt(i, j)
            let K = S[(Int(S[i]) + Int(S[j])) % 256]
            result.append(byte ^ K)
        }
        return result
    }
}

// MARK: - ABogus Algorithm
nonisolated public class ABogus {
    public static let defaultUA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36"
    
    private let aid: Int = 6383
    private let pageId: Int = 0
    private let salt: String = "cus"
    private let options: [Int] = [0, 1, 14]
    private let uaKey: [UInt8] = [0x00, 0x01, 0x0E]
    
    private let character = "Dkdpgh2ZmsQB80/MfvV36XI1R45-WUAlEixNLwoqYTOPuzKFjJnry79HbGcaStCe"
    private let character2 = "ckdp1h4ZKsUB80/Mfvw36XIgR25+WQAlEi7NLboqYTOPuzmFjJnryx9HVGDaStCe"
    private lazy var characterList: [String] = [character, character2]
    
    private let initialBigArray: [Int] = [
        121, 243,  55, 234, 103,  36,  47, 228,  30, 231, 106,   6, 115,  95,  78, 101, 250, 207, 198,  50,
        139, 227, 220, 105,  97, 143,  34,  28, 194, 215,  18, 100, 159, 160,  43,   8, 169, 217, 180, 120,
        247,  45,  90,  11,  27, 197,  46,   3,  84,  72,   5,  68,  62,  56, 221,  75, 144,  79,  73, 161,
        178,  81,  64, 187, 134, 117, 186, 118,  16, 241, 130,  71,  89, 147, 122, 129,  65,  40,  88, 150,
        110, 219, 199, 255, 181, 254,  48,   4, 195, 248, 208,  32, 116, 167,  69, 201,  17, 124, 125, 104,
         96,  83,  80, 127, 236, 108, 154, 126, 204,  15,  20, 135, 112, 158,  13,   1, 188, 164, 210, 237,
        222,  98, 212,  77, 253,  42, 170, 202,  26,  22,  29, 182, 251,  10, 173, 152,  58, 138,  54, 141,
        185,  33, 157,  31, 252, 132, 233, 235, 102, 196, 191, 223, 240, 148,  39, 123,  92,  82, 128, 109,
         57,  24,  38, 113, 209, 245,   2, 119, 153, 229, 189, 214, 230, 174, 232,  63,  52, 205,  86, 140,
         66, 175, 111, 171, 246, 133, 238, 193,  99,  60,  74,  91, 225,  51,  76,  37, 145, 211, 166, 151,
        213, 206,   0, 200, 244, 176, 218,  44, 184, 172,  49, 216,  93, 168,  53,  21, 183,  41,  67,  85,
        224, 155, 226, 242,  87, 177, 146,  70, 190,  12, 162,  19, 137, 114,  25, 165, 163, 192,  23,  59,
          9,  94, 179, 107,  35,   7, 142, 131, 239, 203, 149, 136,  61, 249,  14, 156
    ]
    
    private let sortIndex: [Int] = [
        18, 20, 52, 26, 30, 34, 58, 38, 40, 53, 42, 21, 27, 54, 55, 31, 35, 57, 39, 41, 43, 22, 28,
        32, 60, 36, 23, 29, 33, 37, 44, 45, 59, 46, 47, 48, 49, 50, 24, 25, 65, 66, 70, 71
    ]
    
    private let sortIndex2: [Int] = [
        18, 20, 26, 30, 34, 38, 40, 42, 21, 27, 31, 35, 39, 41, 43, 22, 28, 32, 36, 23, 29, 33, 37,
        44, 45, 46, 47, 48, 49, 50, 24, 25, 52, 53, 54, 55, 57, 58, 59, 60, 65, 66, 70, 71
    ]
    
    public var userAgent: String
    public var browserFp: String
    
    public init(userAgent: String = defaultUA, fp: String = "") {
        self.userAgent = userAgent
        if !fp.isEmpty {
            self.browserFp = fp
        } else {
            let innerW = Int.random(in: 1024...1920)
            let innerH = Int.random(in: 768...1080)
            let outerW = innerW + Int.random(in: 24...32)
            let outerH = innerH + Int.random(in: 75...90)
            let screenY = [0, 30].randomElement()!
            let sizeW = Int.random(in: 1024...1920)
            let sizeH = Int.random(in: 768...1080)
            let availW = Int.random(in: 1280...1920)
            let availH = Int.random(in: 800...1080)
            self.browserFp = "\(innerW)|\(innerH)|\(outerW)|\(outerH)|0|\(screenY)|0|0|\(sizeW)|\(sizeH)|\(availW)|\(availH)|\(innerW)|\(innerH)|24|24|MacIntel"
        }
    }
    
    private func paramsToArray(str: String) -> [UInt8] {
        let salted = str + salt
        return SM3.hash(Array(salted.utf8))
    }
    
    private func paramsToArray(bytes: [UInt8]) -> [UInt8] {
        return SM3.hash(bytes)
    }
    
    private func base64Encode(data: [UInt8], alphabetIndex: Int) -> String {
        let alphabet = Array(characterList[alphabetIndex])
        var binaryStr = ""
        for b in data {
            let s = String(b, radix: 2)
            let padded = String(repeating: "0", count: max(0, 8 - s.count)) + s
            binaryStr += padded
        }
        let padLen = (6 - binaryStr.count % 6) % 6
        binaryStr += String(repeating: "0", count: padLen)
        
        var output = ""
        for i in stride(from: 0, to: binaryStr.count, by: 6) {
            let start = binaryStr.index(binaryStr.startIndex, offsetBy: i)
            let end = binaryStr.index(start, offsetBy: 6)
            let val = Int(binaryStr[start..<end], radix: 2)!
            output.append(alphabet[val])
        }
        output += String(repeating: "=", count: padLen / 2)
        return output
    }
    
    private func transformBytes(bytesList: [Int]) -> [Int] {
        var bigArray = initialBigArray
        var result = [Int]()
        result.reserveCapacity(bytesList.count)
        
        var indexB = bigArray[1]
        var initialValue = 0
        var valueE = 0
        
        for (index, charVal) in bytesList.enumerated() {
            var sumInitial: Int
            if index == 0 {
                initialValue = bigArray[indexB]
                sumInitial = indexB + initialValue
                bigArray[1] = initialValue
                bigArray[indexB] = indexB
            } else {
                sumInitial = initialValue + valueE
            }
            
            sumInitial %= bigArray.count
            let valueF = bigArray[sumInitial]
            let encrypted = charVal ^ valueF
            result.append(encrypted)
            
            let nextIdx = (index + 2) % bigArray.count
            valueE = bigArray[nextIdx]
            sumInitial = (indexB + valueE) % bigArray.count
            initialValue = bigArray[sumInitial]
            bigArray[sumInitial] = bigArray[nextIdx]
            bigArray[nextIdx] = initialValue
            indexB = sumInitial
        }
        return result
    }
    
    private func abogusEncode(items: [Int], alphabetIndex: Int) -> String {
        let alphabet = Array(characterList[alphabetIndex])
        var abogus = ""
        let len = items.count
        
        for i in stride(from: 0, to: len, by: 3) {
            let n: Int
            if i + 2 < len {
                n = (items[i] << 16) | (items[i + 1] << 8) | items[i + 2]
            } else if i + 1 < len {
                n = (items[i] << 16) | (items[i + 1] << 8)
            } else {
                n = items[i] << 16
            }
            
            let shifts = [18, 12, 6, 0]
            let masks  = [0xFC0000, 0x03F000, 0x0FC0, 0x3F]
            
            for (j, k) in zip(shifts, masks) {
                if j == 6 && i + 1 >= len { break }
                if j == 0 && i + 2 >= len { break }
                let idx = (n & k) >> j
                abogus.append(alphabet[idx])
            }
        }
        let padCount = (4 - abogus.count % 4) % 4
        abogus += String(repeating: "=", count: padCount)
        return abogus
    }
    
    private func generateRandomBytes(length: Int = 3) -> [Int] {
        var res = [Int]()
        for _ in 0..<length {
            let rd = Int.random(in: 0..<10000)
            res.append((((rd & 255) & 170) | 1) & 0xff)
            res.append((((rd & 255) & 85) | 2) & 0xff)
            res.append((((rd >> 8) & 170) | 5) & 0xff)
            res.append((((rd >> 8) & 85) | 40) & 0xff)
        }
        return res
    }
    
    public func generateABogus(params: String, body: String = "") -> String {
        var abDir = [Int: Int]()
        abDir[8] = 3
        abDir[18] = 44
        abDir[66] = 0
        abDir[69] = 0
        abDir[70] = 0
        abDir[71] = 0
        
        let startEnc = Int(Date().timeIntervalSince1970 * 1000)
        
        let array1 = paramsToArray(bytes: paramsToArray(str: params))
        let array2 = paramsToArray(bytes: paramsToArray(str: body))
        
        let rc4Enc = RC4.encrypt(key: uaKey, data: Array(userAgent.utf8))
        let b64UA = base64Encode(data: rc4Enc, alphabetIndex: 1)
        let array3 = SM3.hash(Array(b64UA.utf8))
        
        let endEnc = Int(Date().timeIntervalSince1970 * 1000)
        
        abDir[20] = (startEnc >> 24) & 255
        abDir[21] = (startEnc >> 16) & 255
        abDir[22] = (startEnc >> 8) & 255
        abDir[23] = startEnc & 255
        abDir[24] = Int(Double(startEnc) / 256.0 / 256.0 / 256.0 / 256.0)
        abDir[25] = Int(Double(startEnc) / 256.0 / 256.0 / 256.0 / 256.0 / 256.0)
        
        abDir[26] = (options[0] >> 24) & 255
        abDir[27] = (options[0] >> 16) & 255
        abDir[28] = (options[0] >> 8) & 255
        abDir[29] = options[0] & 255
        
        abDir[30] = (options[1] / 256) & 255
        abDir[31] = (options[1] % 256) & 255
        abDir[32] = (options[1] >> 24) & 255
        abDir[33] = (options[1] >> 16) & 255
        
        abDir[34] = (options[2] >> 24) & 255
        abDir[35] = (options[2] >> 16) & 255
        abDir[36] = (options[2] >> 8) & 255
        abDir[37] = options[2] & 255
        
        abDir[38] = Int(array1[21])
        abDir[39] = Int(array1[22])
        abDir[40] = Int(array2[21])
        abDir[41] = Int(array2[22])
        abDir[42] = Int(array3[23])
        abDir[43] = Int(array3[24])
        
        abDir[44] = (endEnc >> 24) & 255
        abDir[45] = (endEnc >> 16) & 255
        abDir[46] = (endEnc >> 8) & 255
        abDir[47] = endEnc & 255
        abDir[48] = abDir[8]!
        abDir[49] = Int(Double(endEnc) / 256.0 / 256.0 / 256.0 / 256.0)
        abDir[50] = Int(Double(endEnc) / 256.0 / 256.0 / 256.0 / 256.0 / 256.0)
        
        abDir[51] = (pageId >> 24) & 255
        abDir[52] = (pageId >> 16) & 255
        abDir[53] = (pageId >> 8) & 255
        abDir[54] = pageId & 255
        abDir[55] = pageId
        abDir[56] = aid
        abDir[57] = aid & 255
        abDir[58] = (aid >> 8) & 255
        abDir[59] = (aid >> 16) & 255
        abDir[60] = (aid >> 24) & 255
        
        let fpBytes = browserFp.utf8.map { Int($0) }
        abDir[64] = fpBytes.count
        abDir[65] = fpBytes.count
        
        var sortedValues: [Int] = sortIndex.map { abDir[$0] ?? 0 }
        
        var abXor = abDir[sortIndex2[0]] ?? 0
        for i in 0..<(sortIndex2.count - 1) {
            abXor ^= (abDir[sortIndex2[i + 1]] ?? 0)
        }
        
        sortedValues.append(contentsOf: fpBytes)
        sortedValues.append(abXor)
        
        let randomBytes = generateRandomBytes(length: 3)
        let transformed = transformBytes(bytesList: sortedValues)
        
        var fullBytes = randomBytes
        fullBytes.append(contentsOf: transformed)
        
        return abogusEncode(items: fullBytes, alphabetIndex: 0)
    }
}

// MARK: - Douyin Service Engine
nonisolated class DouyinService: @unchecked Sendable {
    static let shared = DouyinService()
    
    func resolveAwemeId(from input: String) async throws -> String {
        let pattern = #"(https?://(?:v\.douyin\.com|www\.douyin\.com/(?:video|note))/\S+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: input, range: NSRange(input.startIndex..., in: input)),
              let range = Range(match.range(at: 1), in: input) else {
            throw NSError(domain: "DouyinService", code: -1, userInfo: [NSLocalizedDescriptionKey: "未检测到有效的抖音链接，请检查输入内容"])
        }
        
        let rawUrl = String(input[range])
        
        if let directId = matchDigitsId(in: rawUrl) {
            return directId
        }
        
        guard let url = URL(string: rawUrl) else {
            throw NSError(domain: "DouyinService", code: -1, userInfo: [NSLocalizedDescriptionKey: "无效链接地址"])
        }
        
        var request = URLRequest(url: url)
        request.setValue(ABogus.defaultUA, forHTTPHeaderField: "User-Agent")
        request.httpShouldHandleCookies = false
        request.timeoutInterval = 10
        
        // 1. 优先尝试系统默认路由解析重定向
        do {
            let (_, response) = try await performResilientData(for: request, forceDirect: false)
            if let finalURL = response.url?.absoluteString,
               let awemeId = matchDigitsId(in: finalURL) {
                return awemeId
            }
        } catch {
            print("ℹ️ [DouyinService] 短链接系统路由重定向受阻 (\(error.localizedDescription))，尝试强制直连国内节点...")
        }
        
        // 2. 容灾方案：若系统路由受阻，强制直连国内节点解析
        let (_, directResponse) = try await performResilientData(for: request, forceDirect: true)
        if let finalURL = directResponse.url?.absoluteString,
           let awemeId = matchDigitsId(in: finalURL) {
            return awemeId
        }
        
        throw NSError(domain: "DouyinService", code: -1, userInfo: [NSLocalizedDescriptionKey: "解析失败：无法获取目标作品 ID"])
    }
    
    // MARK: - 网络会话生命周期管理 (纯净隔离 + 自动保活 + 连接重置)
    private let sessionLock = NSLock()
    private var _systemSession: URLSession?
    private var _directSession: URLSession?
    
    private static func makeSessionConfiguration(direct: Bool) -> URLSessionConfiguration {
        let config = URLSessionConfiguration.ephemeral
        if direct {
            config.connectionProxyDictionary = [:]
        }
        config.httpCookieStorage = nil
        config.httpShouldSetCookies = false
        config.httpCookieAcceptPolicy = .never
        config.urlCache = nil
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 60
        return config
    }
    
    private var systemSession: URLSession {
        sessionLock.lock()
        defer { sessionLock.unlock() }
        if let s = _systemSession { return s }
        let s = URLSession(configuration: Self.makeSessionConfiguration(direct: false))
        _systemSession = s
        return s
    }
    
    private var directSession: URLSession {
        sessionLock.lock()
        defer { sessionLock.unlock() }
        if let s = _directSession { return s }
        let s = URLSession(configuration: Self.makeSessionConfiguration(direct: true))
        _directSession = s
        return s
    }
    
    /// 当遇到 403 阻断或重置用户凭据时，彻底切断已污染的 HTTP/2 传输通道并重置会话
    func resetSessions() {
        sessionLock.lock()
        let oldSys = _systemSession
        let oldDir = _directSession
        _systemSession = nil
        _directSession = nil
        sessionLock.unlock()
        
        oldSys?.invalidateAndCancel()
        oldDir?.invalidateAndCancel()
    }
    
    // MARK: - 网络请求代理容灾与自动直连降级
    func performResilientData(for request: URLRequest, forceDirect: Bool = false) async throws -> (Data, URLResponse) {
        if forceDirect {
            return try await directSession.data(for: request)
        }
        
        do {
            return try await systemSession.data(for: request)
        } catch {
            let nsErr = error as NSError
            if nsErr.domain == NSURLErrorDomain || nsErr.domain == (kCFErrorDomainCFNetwork as String) ||
               nsErr.code == 310 || nsErr.code == -1004 || nsErr.code == -1009 || nsErr.code == -1001 || nsErr.code == -1005 {
                print("ℹ️ [DouyinService] 系统路由连接受阻 (\(nsErr.code): \(error.localizedDescription))，自动降级直连国内节点...")
                return try await directSession.data(for: request)
            }
            throw error
        }
    }
    
    func performResilientDownload(for request: URLRequest, forceDirect: Bool = false) async throws -> (URL, URLResponse) {
        if forceDirect {
            return try await directSession.download(for: request)
        }
        
        do {
            return try await systemSession.download(for: request)
        } catch {
            let nsErr = error as NSError
            if nsErr.domain == NSURLErrorDomain || nsErr.domain == (kCFErrorDomainCFNetwork as String) ||
               nsErr.code == 310 || nsErr.code == -1004 || nsErr.code == -1009 || nsErr.code == -1001 || nsErr.code == -1005 {
                print("ℹ️ [DouyinService] 系统路由下载受阻 (\(nsErr.code): \(error.localizedDescription))，自动降级直连国内节点...")
                return try await directSession.download(for: request)
            }
            throw error
        }
    }
    
    private func matchDigitsId(in str: String) -> String? {
        let patterns = [#"video/([0-9]+)"#, #"note/([0-9]+)"#]
        for p in patterns {
            if let regex = try? NSRegularExpression(pattern: p),
               let match = regex.firstMatch(in: str, range: NSRange(str.startIndex..., in: str)),
               let range = Range(match.range(at: 1), in: str) {
                return String(str[range])
            }
        }
        return nil
    }
    
    private var cachedTTWID: String = ""
    private var lastTTWIDFetchTime: Date = .distantPast
    
    // MARK: - 2. Cookie 净化与凭据模式管理
    /// 严格保留长期稳定的鉴权与设备识别项，剔除临时握手与单次 Token (passport_auth_mix_state, n_mh, s_v_web_id 等)
    static func sanitizeCookieString(_ raw: String, minimal: Bool = false) -> String {
        let allowedPrefixes: Set<String>
        if minimal {
            // 核心鉴权最小集：去除可能在服务端轮换脱节的辅助 Token，仅保留核心会话与 CSRF 项
            allowedPrefixes = [
                "sessionid", "sessionid_ss", "sid_tt", "sid_guard",
                "uid_tt", "uid_tt_ss", "passport_csrf_token", "passport_csrf_token_default"
            ]
        } else {
            allowedPrefixes = [
                "sessionid", "sessionid_ss", "sid_tt", "sid_guard",
                "uid_tt", "uid_tt_ss", "passport_csrf_token", "passport_csrf_token_default",
                "odin_tt", "ttwid", "hevc_supported", "isdouyinactive", "is_dash_user"
            ]
        }
        
        let items = raw.components(separatedBy: ";")
        var resultPairs: [String] = []
        var seenNames = Set<String>()
        
        for item in items {
            let trimmed = item.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let eqIdx = trimmed.firstIndex(of: "=") else { continue }
            let name = String(trimmed[..<eqIdx]).trimmingCharacters(in: .whitespaces)
            let value = String(trimmed[trimmed.index(after: eqIdx)...]).trimmingCharacters(in: .whitespaces)
            let lowerName = name.lowercased()
            
            if allowedPrefixes.contains(lowerName) && !seenNames.contains(lowerName) {
                seenNames.insert(lowerName)
                resultPairs.append("\(name)=\(value)")
            }
        }
        return resultPairs.joined(separator: "; ")
    }
    
    /// 从服务端响应头中动态捕获轮转的 odin_tt / ttwid 并回写更新本地存储，保持 Token 永远与抖音官方实时同步
    static func updateCookiesFromResponse(_ response: URLResponse, targetUrl: URL) {
        guard let httpResponse = response as? HTTPURLResponse,
              let fields = httpResponse.allHeaderFields as? [String: String] else { return }
        
        let receivedCookies = HTTPCookie.cookies(withResponseHeaderFields: fields, for: targetUrl)
        guard !receivedCookies.isEmpty else { return }
        
        let currentCustom = UserDefaults.standard.string(forKey: "SaveTik_CustomCookie") ?? ""
        guard currentCustom.contains("sessionid=") else { return }
        
        var cookieMap: [String: String] = [:]
        for item in currentCustom.components(separatedBy: ";") {
            let trimmed = item.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let eqIdx = trimmed.firstIndex(of: "=") else { continue }
            let k = String(trimmed[..<eqIdx]).trimmingCharacters(in: .whitespaces)
            let v = String(trimmed[trimmed.index(after: eqIdx)...]).trimmingCharacters(in: .whitespaces)
            if !k.isEmpty && !v.isEmpty {
                cookieMap[k] = v
            }
        }
        
        var hasChanges = false
        for c in receivedCookies {
            let name = c.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let val = c.value.trimmingCharacters(in: .whitespacesAndNewlines)
            if (name == "odin_tt" || name == "ttwid") && !val.isEmpty {
                if cookieMap[name] != val {
                    cookieMap[name] = val
                    hasChanges = true
                    print("🔄 [DouyinService] 动态同步服务端新 Token: \(name)=\(val.prefix(16))...")
                }
            }
        }
        
        if hasChanges {
            let rawStr = cookieMap.map { "\($0.key)=\($0.value);" }.joined(separator: " ")
            let sanitized = sanitizeCookieString(rawStr, minimal: false)
            UserDefaults.standard.set(sanitized, forKey: "SaveTik_CustomCookie")
            UserDefaults.standard.synchronize()
        }
    }
    
    enum CookieMode {
        case preferCustom(minimal: Bool)
        case forceVisitor(forceRefresh: Bool)
    }
    
    func getEffectiveCookies(mode: CookieMode = .preferCustom(minimal: false)) async -> String {
        switch mode {
        case .preferCustom(let minimal):
            if let custom = UserDefaults.standard.string(forKey: "SaveTik_CustomCookie")?.trimmingCharacters(in: .whitespacesAndNewlines), !custom.isEmpty {
                let sanitized = DouyinService.sanitizeCookieString(custom, minimal: minimal)
                if !sanitized.isEmpty {
                    return sanitized
                }
            }
            return await getVisitorCookies(forceRefresh: false)
            
        case .forceVisitor(let forceRefresh):
            return await getVisitorCookies(forceRefresh: forceRefresh)
        }
    }
    
    private func getVisitorCookies(forceRefresh: Bool) async -> String {
        if forceRefresh {
            self.cachedTTWID = ""
            self.lastTTWIDFetchTime = .distantPast
        } else if !cachedTTWID.isEmpty && Date().timeIntervalSince(lastTTWIDFetchTime) < 7200 {
            return "ttwid=\(cachedTTWID);"
        }
        
        if let ttwid = await fetchCleanTTWID(forceRefresh: forceRefresh) {
            self.cachedTTWID = ttwid
            self.lastTTWIDFetchTime = Date()
            return "ttwid=\(ttwid);"
        }
        
        return ""
    }
    
    /// 清除内存中的凭证缓存并重置网络连接
    func clearCachedCredentials() {
        self.cachedTTWID = ""
        self.lastTTWIDFetchTime = .distantPast
        self.resetSessions()
    }
    
    // MARK: - 3. 验证用户登录凭证有效性（向抖音官方接口发起在线真实鉴权）
    enum SessionStatus: Equatable {
        case valid(nickname: String?)
        case invalid(reason: String)
        case networkError(String)
    }
    
    func verifySessionValidity(cookieString: String) async -> SessionStatus {
        guard !cookieString.isEmpty, cookieString.contains("sessionid=") else {
            return .invalid(reason: "本地未保存有效凭证")
        }
        
        // 直接使用抖音官方电脑 Web 端权威个人资料接口（携带 a_bogus 权威签名与完整规范参数）
        let msToken = generateFalseMsToken()
        let params = "device_platform=webapp&aid=6383&channel=channel_pc_web&pc_client_type=1&version_code=290100&version_name=29.1.0&msToken=\(msToken)"
        let ab = ABogus()
        let abogus = ab.generateABogus(params: params)
        let fullUrlStr = "https://www.douyin.com/aweme/v1/web/user/profile/self/?\(params)&a_bogus=\(abogus)"
        
        guard let url = URL(string: fullUrlStr) else {
            return .invalid(reason: "鉴权接口地址无效")
        }
        
        let cleanCookie = DouyinService.sanitizeCookieString(cookieString)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(ABogus.defaultUA, forHTTPHeaderField: "User-Agent")
        request.setValue("https://www.douyin.com/", forHTTPHeaderField: "Referer")
        request.setValue(cleanCookie, forHTTPHeaderField: "Cookie")
        request.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
        request.setValue("zh-CN,zh;q=0.9,en;q=0.8", forHTTPHeaderField: "Accept-Language")
        request.setValue("\"macOS\"", forHTTPHeaderField: "sec-ch-ua-platform")
        request.setValue("\"Chromium\";v=\"130\", \"Google Chrome\";v=\"130\", \"Not?A_Brand\";v=\"99\"", forHTTPHeaderField: "sec-ch-ua")
        request.setValue("?0", forHTTPHeaderField: "sec-ch-ua-mobile")
        request.setValue("empty", forHTTPHeaderField: "sec-fetch-dest")
        request.setValue("cors", forHTTPHeaderField: "sec-fetch-mode")
        request.setValue("same-origin", forHTTPHeaderField: "sec-fetch-site")
        request.httpShouldHandleCookies = false
        request.timeoutInterval = 15
        
        do {
            let (data, response) = try await performResilientData(for: request, forceDirect: false)
            guard let httpResponse = response as? HTTPURLResponse else {
                return .networkError("无效的网络响应")
            }
            
            // 1. 明确的授权失效 HTTP 状态码
            // 401 (Unauthorized), 403 (Forbidden), 410 (Gone), 419 (Session Expired), 423 (Locked)
            if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 || httpResponse.statusCode == 410 || httpResponse.statusCode == 419 || httpResponse.statusCode == 423 {
                return .invalid(reason: "登录凭证已失效或已被远端设备退出 (\(httpResponse.statusCode))")
            }
            
            // 2. HTTP 重定向状态码（301, 302, 303, 307, 308）或重定向离开个人资料 API
            let isRedirect = (300...399).contains(httpResponse.statusCode)
            if isRedirect {
                return .invalid(reason: "登录凭证已失效（已被重定向至登录页）")
            }
            
            if let finalUrl = httpResponse.url?.absoluteString, !finalUrl.contains("/aweme/v1/web/user/profile/self") {
                return .invalid(reason: "登录凭证已失效（已被重定向至登录页）")
            }
            
            // 3. 客户端请求错误（400 传参或凭证失效格式）
            if (400...499).contains(httpResponse.statusCode) {
                return .invalid(reason: "登录凭证已失效 (\(httpResponse.statusCode))")
            }
            
            // 4. 服务器异常（500/502/503/504 等真正的服务端网络错误）
            guard httpResponse.statusCode == 200 else {
                return .networkError("服务器响应状态码: \(httpResponse.statusCode)")
            }
            
            // 5. 解析返回 JSON 数据
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                // 若状态码为 200 但返回非 JSON（如重定向登录 HTML、滑动验证码挑战或页面源码），明确代表凭证失效需要重新鉴权
                return .invalid(reason: "登录凭证已失效或需重新验证")
            }
            
            let statusCode = json["status_code"] as? Int ?? -1
            let statusMsg = json["status_msg"] as? String ?? ""
            
            // 6. 抖音官方个人资料接口：status_code == 0 且包含 user 对象即为有效登录
            if statusCode == 0, let user = json["user"] as? [String: Any] {
                let nickname = user["nickname"] as? String
                return .valid(nickname: nickname)
            }
            
            // 7. 服务端明确返回未登录 / 已过期 / 已被远端退出（status_code == 8 或 status_msg 提示）
            if statusCode == 8 || statusMsg.contains("未登录") || statusMsg.contains("过期") || statusMsg.contains("退出") || statusMsg.contains("失效") {
                return .invalid(reason: statusMsg.isEmpty ? "会话已过期或已被远端设备退出" : statusMsg)
            }
            
            // 8. 兜底解析（若接口返回包含其他合法结构）
            let dataObj = json["data"] as? [String: Any] ?? [:]
            let errorCode = dataObj["error_code"] as? Int ?? (json["error_code"] as? Int ?? 0)
            if errorCode == 0 && (dataObj["user_id"] != nil || dataObj["sec_user_id"] != nil) {
                let nickname = dataObj["name"] as? String ?? dataObj["nickname"] as? String
                return .valid(nickname: nickname)
            }
            
            // 9. 任何非 0 的业务状态码，一律判定为登录凭证已失效
            return .invalid(reason: statusMsg.isEmpty ? "登录凭证已失效" : statusMsg)
        } catch {
            let err = error as NSError
            if err.domain == NSURLErrorDomain && (err.code == NSURLErrorTimedOut || err.code == NSURLErrorNotConnectedToInternet || err.code == NSURLErrorNetworkConnectionLost || err.code == NSURLErrorCannotConnectToHost) {
                return .networkError("网络连接超时或不可达")
            }
            return .networkError(error.localizedDescription)
        }
    }
    
    // MARK: - 4. 彻底清理用户登录会话与 WebKit 存储
    @MainActor
    static func clearAllAuthCookies() {
        UserDefaults.standard.removeObject(forKey: "SaveTik_CustomCookie")
        UserDefaults.standard.removeObject(forKey: "SaveTik_UserNickname")
        UserDefaults.standard.synchronize()
        DouyinService.shared.clearCachedCredentials()
        
        // 1. 清理系统网络请求（URLSession / HTTPCookieStorage）中的所有抖音及字节跳动凭据
        if let cookies = HTTPCookieStorage.shared.cookies {
            for c in cookies {
                let domain = c.domain.lowercased()
                if domain.contains("douyin") || domain.contains("bytedance") || domain.contains("snssdk") || domain.contains("amemv") || domain.contains("iesdouyin") {
                    HTTPCookieStorage.shared.deleteCookie(c)
                }
            }
        }
        
        // 2. 彻底清除 WebKit 中的所有相关网站数据（Cookies、LocalStorage、IndexedDB、ServiceWorkers、WebSQL 等），防止会话静默复活
        let store = WKWebsiteDataStore.default()
        let dataTypes = WKWebsiteDataStore.allWebsiteDataTypes()
        store.fetchDataRecords(ofTypes: dataTypes) { records in
            let targets = records.filter { r in
                let name = r.displayName.lowercased()
                return name.contains("douyin") || name.contains("bytedance") || name.contains("snssdk") || name.contains("amemv") || name.contains("iesdouyin")
            }
            if !targets.isEmpty {
                store.removeData(ofTypes: dataTypes, for: targets, completionHandler: {
                    print("🧹 [DouyinService] 已彻底清除 WebKit 存储记录: \(targets.map { $0.displayName })")
                })
            }
        }
        
        // 3. 同时遍历 WebKit httpCookieStore 删除所有匹配的 Cookie
        store.httpCookieStore.getAllCookies { cookies in
            for c in cookies {
                let domain = c.domain.lowercased()
                if domain.contains("douyin") || domain.contains("bytedance") || domain.contains("snssdk") || domain.contains("amemv") || domain.contains("iesdouyin") {
                    store.httpCookieStore.delete(c, completionHandler: nil)
                }
            }
        }
    }
    
    private func fetchCleanTTWID(forceRefresh: Bool) async -> String? {
        guard let regUrl = URL(string: "https://ttwid.bytedance.com/ttwid/union/register/") else { return nil }
        
        var regReq = URLRequest(url: regUrl)
        regReq.httpMethod = "POST"
        regReq.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        regReq.setValue(ABogus.defaultUA, forHTTPHeaderField: "User-Agent")
        let payload = """
        {"region":"cn","aid":1768,"needFid":false,"service":"www.ixigua.com","migrate_info":{"ticket":"","source":"node"},"cbUrlProtocol":"https","union":true}
        """
        regReq.httpBody = payload.data(using: .utf8)
        regReq.httpShouldHandleCookies = false
        regReq.timeoutInterval = 8
        
        // 优先系统网络（支持系统代理/默认网络）
        do {
            let (_, response) = try await performResilientData(for: regReq, forceDirect: false)
            if let httpRes = response as? HTTPURLResponse,
               let fields = httpRes.allHeaderFields as? [String: String] {
                let cookies = HTTPCookie.cookies(withResponseHeaderFields: fields, for: regUrl)
                if let ttwid = cookies.first(where: { $0.name == "ttwid" })?.value, !ttwid.isEmpty {
                    return ttwid
                }
            }
        } catch {
            print("[-] [DouyinService] 注册 ttwid 系统路由异常: \(error.localizedDescription)，尝试直连...")
        }
        
        // 强制直连国内节点兜底
        if let (_, response) = try? await performResilientData(for: regReq, forceDirect: true),
           let httpRes = response as? HTTPURLResponse,
           let fields = httpRes.allHeaderFields as? [String: String] {
            let cookies = HTTPCookie.cookies(withResponseHeaderFields: fields, for: regUrl)
            if let ttwid = cookies.first(where: { $0.name == "ttwid" })?.value, !ttwid.isEmpty {
                return ttwid
            }
        }
        
        return nil
    }
    
    // MARK: - 3. 动态生成客户端特征与虚假 msToken
    private func generateFalseMsToken() -> String {
        let chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_"
        var res = ""
        for _ in 0..<182 {
            res.append(chars.randomElement()!)
        }
        return res + "=="
    }
    
    /// 动态生成客户端特征与网络指纹微扰动参数，消除高频连续请求时因固定硬件特征引发的 WAF 频控撞车
    private func generateParams(awemeId: String, attempt: Int) -> String {
        let screenPresets: [(w: Int, h: Int)] = [
            (1920, 1080),
            (2560, 1440),
            (1680, 1050),
            (1440, 900),
            (2880, 1800)
        ]
        let screen = screenPresets[(attempt - 1) % screenPresets.count]
        let cpuCores = [12, 10, 8, 14, 16][(attempt - 1) % 5]
        let devMemory = [8, 16, 32][(attempt - 1) % 3]
        let rtt = Int.random(in: 60...120)
        let downlink = String(format: "%.1f", Double.random(in: 8.5...15.0))
        let msToken = generateFalseMsToken()
        
        return "device_platform=webapp&aid=6383&channel=channel_pc_web&pc_client_type=1&publish_video_strategy_type=2&pc_libra_divert=Mac&version_code=290100&version_name=29.1.0&cookie_enabled=true&screen_width=\(screen.w)&screen_height=\(screen.h)&browser_language=zh-CN&browser_platform=MacIntel&browser_name=Chrome&browser_version=130.0.0.0&browser_online=true&engine_name=Blink&engine_version=130.0.0.0&os_name=Mac%20OS&os_version=10.15.7&cpu_core_num=\(cpuCores)&device_memory=\(devMemory)&platform=PC&downlink=\(downlink)&effective_type=4g&round_trip_time=\(rtt)&msToken=\(msToken)&aweme_id=\(awemeId)"
    }
    
    // MARK: - 4. 核心解析逻辑（内置多级网络阶梯容灾与凭据智能自愈机制）
    func parse(input: String) async throws -> (mediaType: String, streams: [VideoStream]?, images: [ImageItem]?, metadata: [String: String]) {
        let awemeId = try await resolveAwemeId(from: input)
        
        var lastError: Error?
        let maxAttempts = 5
        let hasCustom = !(UserDefaults.standard.string(forKey: "SaveTik_CustomCookie") ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        
        for attempt in 1...maxAttempts {
            do {
                let forceDirect: Bool
                let cookieMode: CookieMode
                let attemptDesc: String
                
                if hasCustom {
                    switch attempt {
                    case 1:
                        forceDirect = false
                        cookieMode = .preferCustom(minimal: false)
                        attemptDesc = "用户专属凭据 (系统网络)"
                    case 2:
                        // 凭据偶发频控或连接抖动时，保持用户登录身份，重置链路连接并微调指纹重试
                        forceDirect = false
                        cookieMode = .preferCustom(minimal: false)
                        attemptDesc = "用户专属凭据 (链路重置与动态指纹)"
                    case 3:
                        // 自愈重试：精简剔除可能过期的辅助 Token，仅保留核心登录 Session，彻底避开 Token 轮换脱节
                        forceDirect = false
                        cookieMode = .preferCustom(minimal: true)
                        attemptDesc = "用户核心凭据净化自愈 (系统网络)"
                    case 4:
                        // 强制绕过本地代理或异常隧道，直连国内骨干 CDN
                        forceDirect = true
                        cookieMode = .preferCustom(minimal: false)
                        attemptDesc = "用户专属凭据 (直连国内节点兜底)"
                    default: // 5
                        forceDirect = true
                        cookieMode = .preferCustom(minimal: true)
                        attemptDesc = "用户核心凭据 (直连终极重试)"
                    }
                } else {
                    switch attempt {
                    case 1:
                        forceDirect = false
                        cookieMode = .forceVisitor(forceRefresh: false)
                        attemptDesc = "访客凭证 (系统网络)"
                    case 2:
                        forceDirect = false
                        cookieMode = .forceVisitor(forceRefresh: true)
                        attemptDesc = "刷新访客凭据 (系统网络)"
                    case 3:
                        forceDirect = true
                        cookieMode = .forceVisitor(forceRefresh: false)
                        attemptDesc = "访客凭据 (直连国内节点)"
                    case 4:
                        forceDirect = true
                        cookieMode = .forceVisitor(forceRefresh: true)
                        attemptDesc = "刷新访客凭据 (直连国内节点)"
                    default: // 5
                        forceDirect = false
                        cookieMode = .forceVisitor(forceRefresh: true)
                        attemptDesc = "访客模式终极重试"
                    }
                }
                
                print("🔄 [DouyinService] 发起第 \(attempt)/\(maxAttempts) 次解析请求 [\(attemptDesc)]...")
                
                let cookies = await getEffectiveCookies(mode: cookieMode)
                let params = generateParams(awemeId: awemeId, attempt: attempt)
                
                let ab = ABogus()
                let abogus = ab.generateABogus(params: params)
                let fullUrlStr = "https://www.douyin.com/aweme/v1/web/aweme/detail/?\(params)&a_bogus=\(abogus)"
                
                guard let endpoint = URL(string: fullUrlStr) else {
                    throw NSError(domain: "DouyinService", code: -1, userInfo: [NSLocalizedDescriptionKey: "构建请求 URL 失败"])
                }
                
                var request = URLRequest(url: endpoint)
                request.setValue(ABogus.defaultUA, forHTTPHeaderField: "User-Agent")
                request.setValue("https://www.douyin.com/", forHTTPHeaderField: "Referer")
                if !cookies.isEmpty {
                    request.setValue(cookies, forHTTPHeaderField: "Cookie")
                }
                request.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
                request.setValue("zh-CN,zh;q=0.9,en;q=0.8", forHTTPHeaderField: "Accept-Language")
                request.setValue("\"macOS\"", forHTTPHeaderField: "sec-ch-ua-platform")
                request.setValue("\"Chromium\";v=\"130\", \"Google Chrome\";v=\"130\", \"Not?A_Brand\";v=\"99\"", forHTTPHeaderField: "sec-ch-ua")
                request.setValue("?0", forHTTPHeaderField: "sec-ch-ua-mobile")
                request.setValue("empty", forHTTPHeaderField: "sec-fetch-dest")
                request.setValue("cors", forHTTPHeaderField: "sec-fetch-mode")
                request.setValue("same-origin", forHTTPHeaderField: "sec-fetch-site")
                request.httpShouldHandleCookies = false
                request.timeoutInterval = 12
                
                let (data, response) = try await performResilientData(for: request, forceDirect: forceDirect)
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw NSError(domain: "DouyinService", code: -1, userInfo: [NSLocalizedDescriptionKey: "无效的网络响应"])
                }
                
                // 若遭遇 403 (频控/CDN/账号风控拦截)，断开被污染的链路并切换策略
                if httpResponse.statusCode == 403 {
                    print("⚠️ [DouyinService] 遇到 403 拦截 (尝试 \(attempt)/\(maxAttempts): \(attemptDesc))，断开已污染连接并切换下一策略...")
                    resetSessions()
                    
                    if attempt < maxAttempts {
                        let backoffSeconds = 0.3 + Double(attempt) * 0.2
                        try await Task.sleep(nanoseconds: UInt64(backoffSeconds * 1_000_000_000))
                        continue
                    } else {
                        let tip = hasCustom
                            ? "抖音安全校验限制 (403)，您的登录凭证可能已在远端失效或当前 IP 受到临时频控，建议稍候 1-2 分钟重试或重新扫码登录。"
                            : "抖音节点安全校验限制 (403)：当前网络环境需登录抖音账号后方可解析，请点击右上角登录账号。"
                        throw NSError(domain: "DouyinService", code: 403, userInfo: [NSLocalizedDescriptionKey: tip])
                    }
                }
                
                guard httpResponse.statusCode == 200 else {
                    throw NSError(domain: "DouyinService", code: -1, userInfo: [NSLocalizedDescriptionKey: "网络请求异常，状态码: \(httpResponse.statusCode)"])
                }
                
                // 动态同步响应中的新 Token（如 odin_tt / ttwid 轮换）
                Self.updateCookiesFromResponse(httpResponse, targetUrl: endpoint)
                
                guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    throw NSError(domain: "DouyinService", code: -1, userInfo: [NSLocalizedDescriptionKey: "解析返回数据失败 (非合法 JSON)"])
                }
                
                guard let awemeDetail = json["aweme_detail"] as? [String: Any] else {
                    if let filterDetail = json["filter_detail"] as? [String: Any],
                       let reason = filterDetail["filter_reason"] as? String, reason.contains("story") {
                        throw NSError(domain: "DouyinService", code: -1, userInfo: [NSLocalizedDescriptionKey: "该内容为日常快拍，抖音网页端接口限制无法访问"])
                    }
                    throw NSError(domain: "DouyinService", code: -1, userInfo: [NSLocalizedDescriptionKey: "未能获取到作品详情，作品可能已被删除或设为私密"])
                }
                
                if attempt >= 2 && hasCustom {
                    print("💡 [DouyinService] 前序链路曾受阻，已通过阶梯自愈策略与动态特征扰动在第 \(attempt) 次成功解析！")
                }
                
                return try extractParsedData(awemeDetail: awemeDetail)
            } catch {
                lastError = error
                if (error as NSError).code == 403 && attempt >= maxAttempts {
                    break
                }
                resetSessions()
                if attempt < maxAttempts {
                    let backoffSeconds = 0.3 + Double(attempt) * 0.2
                    try await Task.sleep(nanoseconds: UInt64(backoffSeconds * 1_000_000_000))
                    continue
                }
            }
        }
        
        throw lastError ?? NSError(domain: "DouyinService", code: -1, userInfo: [NSLocalizedDescriptionKey: "请求失败，请稍后重试"])
    }
    
    // MARK: - 5. 解析作品流与元数据
    private func extractParsedData(awemeDetail: [String: Any]) throws -> (mediaType: String, streams: [VideoStream]?, images: [ImageItem]?, metadata: [String: String]) {
        let author = awemeDetail["author"] as? [String: Any]
        let nickname = author?["nickname"] as? String ?? "unknown"
        
        let createTimeTs = awemeDetail["create_time"] as? Int ?? 0
        let date = Date(timeIntervalSince1970: TimeInterval(createTimeTs))
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let createTimeString = formatter.string(from: date)
        
        let metadata = [
            "nickname": nickname,
            "create_time": createTimeString,
            "user_agent": ABogus.defaultUA
        ]
        
        // 判断是否为图文或 Live 图
        if let rawImages = awemeDetail["images"] as? [[String: Any]], !rawImages.isEmpty {
            var parsedImages = [ImageItem]()
            var isLivePhoto = false
            
            for img in rawImages {
                let livePhotoType = img["live_photo_type"] as? Int ?? (img["livePhotoType"] as? Int ?? 0)
                var liveVideoUrls = [String]()
                
                if let videoData = img["video"] as? [String: Any] {
                    if let playAddr = videoData["play_addr"] as? [String: Any],
                       let uList = playAddr["url_list"] as? [String] {
                        liveVideoUrls = uList
                    } else if let bitRateList = videoData["bit_rate"] as? [[String: Any]], !bitRateList.isEmpty {
                        if let pa = bitRateList[0]["play_addr"] as? [String: Any],
                           let uList = pa["url_list"] as? [String] {
                            liveVideoUrls = uList
                        }
                    }
                }
                
                let isThisLive = (livePhotoType == 1) || !liveVideoUrls.isEmpty
                if isThisLive { isLivePhoto = true }
                
                let urlList = (img["url_list"] as? [String]) ?? (img["urlList"] as? [String]) ?? []
                var targetJpegUrl: String? = nil
                
                for u in urlList.reversed() {
                    if let path = URL(string: u)?.path.lowercased(), path.hasSuffix(".jpeg") {
                        targetJpegUrl = u
                        break
                    }
                }
                if targetJpegUrl == nil, let last = urlList.last {
                    targetJpegUrl = last
                }
                
                guard let finalImageUrl = targetJpegUrl else { continue }
                let width = img["width"] as? Int ?? 0
                let height = img["height"] as? Int ?? 0
                let liveUrl = (isThisLive && !liveVideoUrls.isEmpty) ? liveVideoUrls.first : nil
                
                parsedImages.append(ImageItem(
                    imageUrl: finalImageUrl,
                    width: width,
                    height: height,
                    liveVideoUrl: liveUrl
                ))
            }
            
            let mediaType = isLivePhoto ? "live_photo" : "image"
            return (mediaType, nil, parsedImages, metadata)
        }
        
        // 视频流解析
        let videoData = (awemeDetail["video"] as? [String: Any]) ?? [:]
        let bitRateList = (videoData["bit_rate"] as? [[String: Any]]) ?? []
        
        var streamMap = [String: VideoStream]()
        
        for item in bitRateList {
            let playAddr = (item["play_addr"] as? [String: Any]) ?? (item["playAddr"] as? [String: Any]) ?? [:]
            let urls = (playAddr["url_list"] as? [String]) ?? (playAddr["urlList"] as? [String]) ?? []
            guard !urls.isEmpty else { continue }
            
            let fileHash = (playAddr["file_hash"] as? String) ?? (playAddr["fileHash"] as? String) ?? (item["playAddrFileHash"] as? String) ?? "\(item["bit_rate"] ?? item["bitRate"] ?? 0)"
            let urlKey = (playAddr["url_key"] as? String) ?? (playAddr["urlKey"] as? String) ?? ""
            let encoding = urlKey.contains("_bytevc1_") ? "H265" : "H264"
            
            let width = (playAddr["width"] as? Int) ?? (item["width"] as? Int) ?? 0
            let height = (playAddr["height"] as? Int) ?? (item["height"] as? Int) ?? 0
            let bitRate = (item["bit_rate"] as? Int) ?? (item["bitRate"] as? Int) ?? 0
            let dataSize = (playAddr["data_size"] as? Int) ?? (playAddr["dataSize"] as? Int) ?? 0
            let fps = (item["FPS"] as? Int) ?? (item["fps"] as? Int) ?? 0
            
            let hdrBit = String(describing: item["HDR_bit"] ?? "")
            let hdrType = String(describing: item["HDR_type"] ?? "")
            let isHDR = (hdrBit == "10" && hdrType == "1")
            
            if let existing = streamMap[fileHash] {
                var combinedUrls = existing.urlList
                for u in urls {
                    if !combinedUrls.contains(u) { combinedUrls.append(u) }
                }
                streamMap[fileHash] = VideoStream(
                    nickname: nickname,
                    create_time: createTimeString,
                    width: width,
                    height: height,
                    encoding: encoding,
                    bitRate: bitRate,
                    dataSize: dataSize,
                    fps: fps,
                    isHDR: isHDR,
                    urlList: combinedUrls
                )
            } else {
                streamMap[fileHash] = VideoStream(
                    nickname: nickname,
                    create_time: createTimeString,
                    width: width,
                    height: height,
                    encoding: encoding,
                    bitRate: bitRate,
                    dataSize: dataSize,
                    fps: fps,
                    isHDR: isHDR,
                    urlList: urls
                )
            }
        }
        
        let streams = Array(streamMap.values).sorted { $0.bitRate > $1.bitRate }
        print("✅ [DouyinService] 原始下发流数: \(bitRateList.count), 去重解析后可用视频源: \(streams.count) 个")
        for (i, s) in streams.enumerated() {
            print("   [\(i)] \(s.width)x\(s.height) | \(s.encoding) | br=\(s.bitRate)")
        }
        return ("video", streams, nil, metadata)
    }
}

// MARK: - API 服务主类 (纯 Swift 原生实现，替换原 Python FastAPI + DrissionPage 后端)
nonisolated class APIService: @unchecked Sendable {
    static let shared = APIService()
    
    var baseURL = "native"
    
    private let statusQueue = DispatchQueue(label: "com.savetik.apiview.status", attributes: .concurrent)
    private var _taskStatusDB: [String: (status: String, timestamp: Date)] = [:]
    
    func setPort(_ port: UInt16) {
        self.baseURL = "native"
        print("✅ Swift 原生引擎就绪")
    }
    
    func parse(url: String) async throws -> ParseDataContainer {
        let result = try await DouyinService.shared.parse(input: url)
        return ParseDataContainer(
            mediaType: result.mediaType,
            metadata: result.metadata,
            streams: result.streams,
            imageData: result.images
        )
    }
    
    func download(stream: VideoStream, metadata: [String: String]?) async throws -> String {
        let taskId = UUID().uuidString
        setStatus(taskId: taskId, status: "downloading")
        
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self = self else { return }
            do {
                try await self.performVideoDownload(stream: stream, metadata: metadata)
                self.setStatus(taskId: taskId, status: "completed")
            } catch {
                print("[-] 原生视频下载失败: \(error)")
                self.setStatus(taskId: taskId, status: "failed")
            }
        }
        
        return taskId
    }
    
    func download(imageItem: ImageItem, metadata: [String: String]?) async throws -> String {
        let taskId = UUID().uuidString
        setStatus(taskId: taskId, status: "completed")
        return taskId
    }
    
    func checkStatus(taskId: String) async throws -> String {
        return getStatus(for: taskId)
    }
    
    func clearBackendMemory() async {
        statusQueue.async(flags: .barrier) {
            self._taskStatusDB.removeAll()
        }
    }
    
    nonisolated private func getStatus(for taskId: String) -> String {
        statusQueue.sync {
            _taskStatusDB[taskId]?.status ?? "completed"
        }
    }
    
    nonisolated private func setStatus(taskId: String, status: String) {
        statusQueue.async(flags: .barrier) {
            self._taskStatusDB[taskId] = (status, Date())
            let now = Date()
            self._taskStatusDB = self._taskStatusDB.filter { now.timeIntervalSince($0.value.timestamp) < 300 }
        }
    }
    
    private func performVideoDownload(stream: VideoStream, metadata: [String: String]?) async throws {
        let nickname = metadata?["nickname"] ?? "unknown"
        let createTime = metadata?["create_time"] ?? "unknown"
        let resP = min(stream.width, stream.height)
        let fps = stream.fps
        let encoding = stream.encoding
        let bitRate = stream.bitRate
        let hdrTag = stream.isHDR ? "_HDR" : ""
        
        let rawFilename = "\(nickname)_\(createTime)_\(resP)p_\(fps)fps_\(encoding)_\(bitRate)\(hdrTag).mp4"
        let safeFilename = rawFilename.replacingOccurrences(of: "[<>:\"/\\\\|?*]", with: "_", options: .regularExpression).trimmingCharacters(in: .whitespaces)
        
        guard let firstUrlStr = stream.urlList.first, let downloadUrl = URL(string: firstUrlStr) else {
            throw NSError(domain: "APIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "无可用视频下载地址"])
        }
        
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let saveDir = homeDir.appendingPathComponent("Downloads/SaveTik_KZ")
        try FileManager.default.createDirectory(at: saveDir, withIntermediateDirectories: true)
        let destinationURL = saveDir.appendingPathComponent(safeFilename)
        
        var request = URLRequest(url: downloadUrl)
        request.setValue("https://www.douyin.com/", forHTTPHeaderField: "Referer")
        request.setValue(ABogus.defaultUA, forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 60
        
        let (tempURL, response) = try await DouyinService.shared.performResilientDownload(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw NSError(domain: "APIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "视频下载失败，HTTP状态码: \((response as? HTTPURLResponse)?.statusCode ?? -1)"])
        }
        
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }
        try FileManager.default.moveItem(at: tempURL, to: destinationURL)
        print("✅ 视频下载成功: \(destinationURL.path)")
    }
}
