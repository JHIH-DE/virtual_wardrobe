//
//  SharedMedia.swift
//  ShareExtension
//
//  Vendored from receive_sharing_intent 1.9.0's
//  ios/receive_sharing_intent/Sources/receive_sharing_intent/ReceiveSharingIntentPlugin.swift
//  — just the part RSIShareViewController itself needs (the shared-storage
//  keys + the SharedMediaFile/SharedMediaType model), with the Flutter
//  plugin-registration class (ReceiveSharingIntentPlugin, `import Flutter`)
//  left out entirely. That class is what Runner links via the real
//  receive_sharing_intent Swift package; this extension target links
//  nothing from the package at all — see RSIShareViewController.swift's own
//  header comment for why. The string values below MUST stay byte-identical
//  to the package's own copy (both sides read/write the same App Group
//  UserDefaults keys), so treat this file as read-only unless
//  receive_sharing_intent's upstream source actually changes them.
//

import Foundation
import UniformTypeIdentifiers

public let kSchemePrefix = "ShareMedia"
public let kUserDefaultsKey = "ShareKey"
public let kUserDefaultsMessageKey = "ShareMessageKey"
public let kAppGroupIdKey = "AppGroupId"

public class SharedMediaFile: Codable {
    var path: String
    var mimeType: String?
    var thumbnail: String? // video thumbnail
    var duration: Double? // video duration in milliseconds
    var message: String? // post message
    var type: SharedMediaType


    public init(
        path: String,
        mimeType: String? = nil,
        thumbnail: String? = nil,
        duration: Double? = nil,
        message: String?=nil,
        type: SharedMediaType) {
            self.path = path
            self.mimeType = mimeType
            self.thumbnail = thumbnail
            self.duration = duration
            self.message = message
            self.type = type
        }
}

public enum SharedMediaType: String, Codable, CaseIterable {
    case image
    case video
    case text
    case file
    case url

    public var toUTTypeIdentifier: String {
        if #available(iOS 14.0, *) {
            switch self {
            case .image:
                return UTType.image.identifier
            case .video:
                return UTType.movie.identifier
            case .text:
                return UTType.text.identifier
            case .file:
                return UTType.fileURL.identifier
            case .url:
                return UTType.url.identifier
            }
        }
        switch self {
        case .image:
            return "public.image"
        case .video:
            return "public.movie"
        case .text:
            return "public.text"
        case .file:
            return "public.file-url"
        case .url:
            return "public.url"
        }
    }
}
