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
            self.browserFp = "\(innerW)|\(innerH)|\(outerW)|\(outerH)|0|\(screenY)|0|0|\(sizeW)|\(sizeH)|\(availW)|\(availH)|\(innerW)|\(innerH)|24|24|Win32"
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
        
        let (_, response) = try await URLSession.shared.data(for: request)
        if let finalURL = response.url?.absoluteString,
           let awemeId = matchDigitsId(in: finalURL) {
            return awemeId
        }
        
        throw NSError(domain: "DouyinService", code: -1, userInfo: [NSLocalizedDescriptionKey: "解析失败：无法获取目标作品 ID"])
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
    
    private var cachedVisitorCookie: String = ""
    private var lastCookieFetchTime: Date = .distantPast
    
    // MARK: - 2. 获取有效 Cookie（支持用户自定义 Cookie，或自动获取具备 ttwid/UIFID 的防拦截访客 Cookie）
    func getEffectiveCookies(forceRefresh: Bool = false) async -> String {
        // 1. 如果用户在 UserDefaults 中配置了自定义 Cookie，优先使用用户 Cookie
        if let custom = UserDefaults.standard.string(forKey: "SaveTik_CustomCookie")?.trimmingCharacters(in: .whitespacesAndNewlines), !custom.isEmpty {
            return custom
        }
        
        // 2. 检查缓存的访客 Cookie（有效保留 2 小时）
        if !forceRefresh && !cachedVisitorCookie.isEmpty && Date().timeIntervalSince(lastCookieFetchTime) < 7200 {
            return cachedVisitorCookie
        }
        
        // 3. 从抖音首页与 ttwid 接口动态拉取完整防拦截 Cookie (含 ttwid, enter_pc_once, UIFID, DASH/HEVC能力)
        var cookieDict = [String: String]()
        cookieDict["enter_pc_once"] = "1"
        cookieDict["is_dash_user"] = "1"
        cookieDict["hevc_supported"] = "true"
        
        if let liveUrl = URL(string: "https://live.douyin.com/") {
            var req = URLRequest(url: liveUrl)
            req.setValue(ABogus.defaultUA, forHTTPHeaderField: "User-Agent")
            req.timeoutInterval = 8
            _ = try? await URLSession.shared.data(for: req)
            
            if let cookies = HTTPCookieStorage.shared.cookies(for: liveUrl) {
                for c in cookies {
                    cookieDict[c.name] = c.value
                }
            }
        }
        
        if let homeUrl = URL(string: "https://www.douyin.com/") {
            var req = URLRequest(url: homeUrl)
            req.setValue(ABogus.defaultUA, forHTTPHeaderField: "User-Agent")
            req.timeoutInterval = 8
            _ = try? await URLSession.shared.data(for: req)
            
            if let cookies = HTTPCookieStorage.shared.cookies(for: homeUrl) {
                for c in cookies {
                    if cookieDict[c.name] == nil {
                        cookieDict[c.name] = c.value
                    }
                }
            }
        }
        
        // 遍历所有 .douyin.com 域下的 Cookie (确保获取到 UIFID_TEMP, UIFID, odin_tt, ttwid)
        if let allCookies = HTTPCookieStorage.shared.cookies {
            for c in allCookies where c.domain.contains("douyin.com") {
                if cookieDict[c.name] == nil {
                    cookieDict[c.name] = c.value
                }
            }
        }
        
        // 如果缺少 ttwid，通过专用注册接口补充
        if cookieDict["ttwid"] == nil {
            if let regUrl = URL(string: "https://ttwid.bytedance.com/ttwid/union/register/") {
                var regReq = URLRequest(url: regUrl)
                regReq.httpMethod = "POST"
                regReq.setValue("application/json", forHTTPHeaderField: "Content-Type")
                regReq.setValue(ABogus.defaultUA, forHTTPHeaderField: "User-Agent")
                let payload = """
                {"region":"cn","aid":1768,"needFid":false,"service":"www.ixigua.com","migrate_info":{"ticket":"","source":"node"},"cbUrlProtocol":"https","union":true}
                """
                regReq.httpBody = payload.data(using: .utf8)
                _ = try? await URLSession.shared.data(for: regReq)
                if let regCookies = HTTPCookieStorage.shared.cookies(for: regUrl) {
                    for c in regCookies {
                        if c.name == "ttwid" {
                            cookieDict["ttwid"] = c.value
                            break
                        }
                    }
                }
            }
        }
        
        // 如果获取到 UIFID_TEMP，同步赋值 UIFID 满足 ArgusSecurityPlugin 安全网关校验
        if let uTemp = cookieDict["UIFID_TEMP"] ?? cookieDict["uifid_temp"] {
            cookieDict["UIFID"] = uTemp
        }
        
        let fullCookie = cookieDict.map { "\($0.key)=\($0.value);" }.joined(separator: " ")
        if !fullCookie.isEmpty {
            self.cachedVisitorCookie = fullCookie
            self.lastCookieFetchTime = Date()
        }
        return self.cachedVisitorCookie
    }
    
    // MARK: - 3. 生成虚假 msToken
    private func generateFalseMsToken() -> String {
        let chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_"
        var res = ""
        for _ in 0..<182 {
            res.append(chars.randomElement()!)
        }
        return res + "=="
    }
    
    // MARK: - 4. 核心解析逻辑（内置自动重试与反抖动机制）
    func parse(input: String) async throws -> (mediaType: String, streams: [VideoStream]?, images: [ImageItem]?, metadata: [String: String]) {
        let awemeId = try await resolveAwemeId(from: input)
        
        var lastError: Error?
        let maxAttempts = 3
        
        for attempt in 1...maxAttempts {
            do {
                let cookies = await getEffectiveCookies(forceRefresh: (attempt > 1))
                let msToken = generateFalseMsToken()
                
                // 提取 UIFID 供 URL 参数及请求头复用
                var uifidVal = ""
                if let uifidRange = cookies.range(of: "UIFID=") {
                    let sub = cookies[uifidRange.upperBound...]
                    uifidVal = String(sub.prefix(while: { $0 != ";" }))
                }
                
                var params = "device_platform=webapp&aid=6383&channel=channel_pc_web&aweme_id=\(awemeId)&request_source=600&origin_type=video_page&update_version_code=170400&pc_client_type=1&pc_libra_divert=Mac&support_h265=1&support_dash=1&cpu_core_num=10&version_code=190500&version_name=19.5.0&cookie_enabled=true&screen_width=1920&screen_height=1080&browser_language=zh-CN&browser_platform=MacIntel&browser_name=Chrome&browser_version=130.0.0.0&browser_online=true&engine_name=Blink&engine_version=130.0.0.0&os_name=Mac%20OS&os_version=10.15.7&device_memory=16&platform=PC&downlink=10&effective_type=4g&round_trip_time=100&msToken=\(msToken)"
                if !uifidVal.isEmpty {
                    params += "&uifid=\(uifidVal)"
                }
                
                let ab = ABogus()
                let abogus = ab.generateABogus(params: params)
                let fullUrlStr = "https://www.douyin.com/aweme/v1/web/aweme/detail/?\(params)&a_bogus=\(abogus)"
                
                guard let endpoint = URL(string: fullUrlStr) else {
                    throw NSError(domain: "DouyinService", code: -1, userInfo: [NSLocalizedDescriptionKey: "构建请求 URL 失败"])
                }
                
                var request = URLRequest(url: endpoint)
                request.setValue(ABogus.defaultUA, forHTTPHeaderField: "User-Agent")
                request.setValue("https://www.douyin.com/video/\(awemeId)", forHTTPHeaderField: "Referer")
                if !cookies.isEmpty {
                    request.setValue(cookies, forHTTPHeaderField: "Cookie")
                }
                if !uifidVal.isEmpty {
                    request.setValue(uifidVal, forHTTPHeaderField: "uifid")
                }
                request.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
                request.setValue("zh-CN,zh;q=0.9,en;q=0.8", forHTTPHeaderField: "Accept-Language")
                request.setValue("\"macOS\"", forHTTPHeaderField: "sec-ch-ua-platform")
                request.timeoutInterval = 12
                
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw NSError(domain: "DouyinService", code: -1, userInfo: [NSLocalizedDescriptionKey: "无效的网络响应"])
                }
                
                // 若遭遇 403 (常见于特定 CDN 节点风控拦截)，自动刷新凭证与签名并重试
                if httpResponse.statusCode == 403 {
                    if attempt < maxAttempts {
                        try await Task.sleep(nanoseconds: 120_000_000 * UInt64(attempt))
                        continue
                    } else {
                        throw NSError(domain: "DouyinService", code: 403, userInfo: [NSLocalizedDescriptionKey: "抖音节点安全校验限制 (403)，请稍后重试"])
                    }
                }
                
                guard httpResponse.statusCode == 200 else {
                    throw NSError(domain: "DouyinService", code: -1, userInfo: [NSLocalizedDescriptionKey: "网络请求异常，状态码: \(httpResponse.statusCode)"])
                }
                
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
                
                return try extractParsedData(awemeDetail: awemeDetail)
            } catch {
                lastError = error
                if attempt < maxAttempts {
                    try await Task.sleep(nanoseconds: 100_000_000 * UInt64(attempt))
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
        
        let (tempURL, response) = try await URLSession.shared.download(for: request)
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
