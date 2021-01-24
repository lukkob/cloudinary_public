import 'package:cloudinary/cloudinary.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import './cloudinary_response.dart';
import '../cloudinary.dart';

/// The base class for this package
class Cloudinary {
  /// Cloudinary api base url
  static const _baseUrl = 'https://api.cloudinary.com/v1_1';

  /// To cache all the uploaded files in the current class instance
  Map<String, CloudinaryResponse> _uploadedFiles = {};

  /// Cloud name from Cloudinary
  final String _cloudName;

  /// Upload preset from Cloudinary
  final String _uploadPreset;

  /// Defaults to false
  final bool cache;

  /// The Dio client to be used to upload files
  Dio dioClient;

  Cloudinary(
    this._cloudName,
    this._uploadPreset, {
    this.cache = false,
    this.dioClient,
  }) {
    /// set default dio client
    dioClient ??= Dio();
  }

  CloudinaryImage getImage(String publicId) {
    return CloudinaryImage.fromPublicId(_cloudName, publicId);
  }

  /// Upload multiple files together
  Future<List<CloudinaryResponse>> uploadFiles(
    List<CloudinaryFile> files, {
    String uploadPreset,
    List<String> folderNames,
  }) {
    return Future.wait(
      files.map(
        (file) => uploadFile(file,
            uploadPreset: uploadPreset, folderNames: folderNames),
      ),
    );
  }

  /// Upload the cloudinary file to using the public api
  /// Override the default upload preset (when [Cloudinary] is instantiated) with this one (if specified).
  Future<CloudinaryResponse> uploadFile(
    CloudinaryFile file, {
    String uploadPreset,
    List<String> folderNames,
  }) async {
    if (cache) {
      assert(file.identifier != null, 'identifier is required for caching');

      if (_uploadedFiles.containsKey(file.identifier))
        return _uploadedFiles[file.identifier].enableCache();
    }

    FormData formData = FormData.fromMap({
      'file': file.toMultipartFile() ?? file.url,
      'upload_preset': uploadPreset ?? _uploadPreset,
    });

    if (folderNames != null && folderNames.isNotEmpty) {
      formData.fields
          .add(MapEntry<String, String>('folder', folderNames.join('/')));
      formData.fields.add(MapEntry<String, String>(
          'public_id', folderNames.join('/') + '/' + file.identifier));
    } else {
      formData.fields
          .add(MapEntry<String, String>('public_id', file.identifier));
    }

    if (file.tags != null && file.tags.isNotEmpty) {
      formData.fields
          .add(MapEntry<String, String>('tags', file.tags.join(',')));
    }

    /// throws DioError
    final res = await dioClient.post(
      '$_baseUrl/$_cloudName/'
      '${describeEnum(file.resourceType).toLowerCase()}'
      '/upload',
      data: formData,
    );

    final cloudinaryResponse = CloudinaryResponse.fromMap(res.data);

    if (cache) {
      /// Temporary cache for this class instance
      _uploadedFiles[file.identifier] = cloudinaryResponse;
    }
    return cloudinaryResponse;
  }

  /// Upload the file using [uploadFile]
  Future<CloudinaryResponse> uploadFutureFile(
    Future<CloudinaryFile> file, {
    String uploadPreset,
    List<String> folderNames,
  }) async {
    return uploadFile(await file,
        uploadPreset: uploadPreset, folderNames: folderNames);
  }

  /// Upload multiple files using simultaneously [uploadFutureFile]
  Future<List<CloudinaryResponse>> multiUpload(
    List<Future<CloudinaryFile>> files, {
    String uploadPreset,
    List<String> folderNames,
  }) async {
    return Future.wait(
      files.map(
        (file) => uploadFutureFile(file,
            uploadPreset: uploadPreset, folderNames: folderNames),
      ),
    );
  }
}
