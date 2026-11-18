import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Audio buffer manager tailored for flutter_soloud.
///
/// Downloads and caches high-fidelity 320kbps audio streams into clean local files.
/// SoLoud parses the complete container (MP4/AAC/MP3) without moov atom corruption or buffer underruns.
abstract class AudioStreamBufferManager {
  Future<File> prepareStreamBuffer(String streamUrl, {required String songId});
  void prefetchNextTrack(String streamUrl, {required String songId});
  Future<void> clearBuffer();
}

class AudioStreamBufferManagerImpl implements AudioStreamBufferManager {
  final http.Client client;
  final Map<String, File> _activeBuffers = {};

  AudioStreamBufferManagerImpl({required this.client});

  @override
  Future<File> prepareStreamBuffer(
    String streamUrl, {
    required String songId,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final bufferDir = Directory('${tempDir.path}/dilse_stream_buffer');
    if (!await bufferDir.exists()) {
      await bufferDir.create(recursive: true);
    }

    final sanitizedId = songId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final bufferFile = File('${bufferDir.path}/$sanitizedId.mp4');

    // If already fully buffered, return immediately
    if (await bufferFile.exists() && await bufferFile.length() > 100 * 1024) {
      debugPrint(
        '[BufferManager] Serving cached stream for $songId: ${bufferFile.path}',
      );
      return bufferFile;
    }

    debugPrint('[BufferManager] Downloading stream: $streamUrl');
    final response = await client.get(Uri.parse(streamUrl));

    if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
      await bufferFile.writeAsBytes(response.bodyBytes, flush: true);
      _activeBuffers[songId] = bufferFile;
      debugPrint(
        '[BufferManager] Buffered ${response.bodyBytes.length} bytes to ${bufferFile.path}',
      );
      return bufferFile;
    } else {
      throw Exception(
        'Failed to buffer audio from $streamUrl (HTTP ${response.statusCode})',
      );
    }
  }

  @override
  void prefetchNextTrack(String streamUrl, {required String songId}) {
    prepareStreamBuffer(streamUrl, songId: songId).catchError((e) {
      debugPrint('[BufferManager] Prefetch error for $songId: $e');
      return File('');
    });
  }

  @override
  Future<void> clearBuffer() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final bufferDir = Directory('${tempDir.path}/dilse_stream_buffer');
      if (await bufferDir.exists()) {
        await bufferDir.delete(recursive: true);
      }
      _activeBuffers.clear();
    } catch (_) {}
  }
}
