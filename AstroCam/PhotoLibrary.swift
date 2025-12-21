import Foundation
import Photos

final class PhotoLibrary {
    static let shared = PhotoLibrary()
    private let albumName = "AstroCam"

    private init() {}

    func requestAddPermission(completion: @escaping (Bool) -> Void) {
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        switch status {
        case .authorized, .limited:
            completion(true)
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { newStatus in
                DispatchQueue.main.async {
                    completion(newStatus == .authorized || newStatus == .limited)
                }
            }
        default:
            completion(false)
        }
    }

    func savePhotoData(_ data: Data, completion: @escaping (Result<Void, Error>) -> Void) {
        ensureAlbum { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let album):
                PHPhotoLibrary.shared().performChanges({
                    let request = PHAssetCreationRequest.forAsset()
                    let options = PHAssetResourceCreationOptions()
                    request.addResource(with: .photo, data: data, options: options)
                    if let album = album,
                       let placeholder = request.placeholderForCreatedAsset {
                        let albumChangeRequest = PHAssetCollectionChangeRequest(for: album)
                        let fastEnumeration = NSArray(object: placeholder)
                        albumChangeRequest?.addAssets(fastEnumeration)
                    }
                }, completionHandler: { success, error in
                    DispatchQueue.main.async {
                        if let error = error {
                            completion(.failure(error))
                        } else {
                            completion(.success(()))
                        }
                    }
                })
            }
        }
    }

    private func ensureAlbum(completion: @escaping (Result<PHAssetCollection?, Error>) -> Void) {
        if let album = fetchAlbum() {
            completion(.success(album))
            return
        }

        var placeholder: PHObjectPlaceholder?
        PHPhotoLibrary.shared().performChanges({
            let request = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: self.albumName)
            placeholder = request.placeholderForCreatedAssetCollection
        }, completionHandler: { success, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(error))
                } else if let placeholder = placeholder {
                    let collection = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [placeholder.localIdentifier], options: nil).firstObject
                    completion(.success(collection))
                } else {
                    completion(.success(nil))
                }
            }
        })
    }

    private func fetchAlbum() -> PHAssetCollection? {
        let fetch = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .albumRegular, options: nil)
        var result: PHAssetCollection?
        fetch.enumerateObjects { collection, _, stop in
            if collection.localizedTitle == self.albumName {
                result = collection
                stop.pointee = true
            }
        }
        return result
    }
}
