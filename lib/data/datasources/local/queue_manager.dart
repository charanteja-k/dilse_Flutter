import 'dart:math';
import '../../models/song_model.dart';

enum RepeatMode { off, all, one }

/// Pure queue controller logic for managing playback queues.
/// Follows strict MVVM: zero Flutter UI dependencies, zero singletons.
class QueueManager {
  final List<SongModel> _originalQueue = [];
  final List<SongModel> _currentQueue = [];
  int _currentIndex = -1;
  bool _isShuffled = false;
  RepeatMode _repeatMode = RepeatMode.off;

  List<SongModel> get currentQueue => List.unmodifiable(_currentQueue);
  List<SongModel> get originalQueue => List.unmodifiable(_originalQueue);
  int get currentIndex => _currentIndex;
  bool get isShuffled => _isShuffled;
  RepeatMode get repeatMode => _repeatMode;

  SongModel? get currentSong {
    if (_currentIndex >= 0 && _currentIndex < _currentQueue.length) {
      return _currentQueue[_currentIndex];
    }
    return null;
  }

  bool get hasNext {
    if (_repeatMode == RepeatMode.one || _repeatMode == RepeatMode.all) return true;
    return _currentIndex + 1 < _currentQueue.length;
  }

  bool get hasPrevious {
    if (_repeatMode == RepeatMode.one || _repeatMode == RepeatMode.all) return true;
    return _currentIndex - 1 >= 0;
  }

  void setQueue(List<SongModel> songs, {int initialIndex = 0}) {
    _originalQueue.clear();
    _originalQueue.addAll(songs);
    _currentQueue.clear();
    _currentQueue.addAll(songs);

    _isShuffled = false;
    if (_currentQueue.isNotEmpty) {
      _currentIndex = initialIndex.clamp(0, _currentQueue.length - 1);
    } else {
      _currentIndex = -1;
    }
  }

  void addTrack(SongModel song) {
    _originalQueue.add(song);
    _currentQueue.add(song);
    if (_currentIndex == -1) {
      _currentIndex = 0;
    }
  }

  void addTracks(List<SongModel> songs) {
    _originalQueue.addAll(songs);
    _currentQueue.addAll(songs);
    if (_currentIndex == -1 && _currentQueue.isNotEmpty) {
      _currentIndex = 0;
    }
  }

  SongModel? skipToNext() {
    if (_currentQueue.isEmpty) return null;

    if (_repeatMode == RepeatMode.one) {
      return currentSong;
    }

    if (_currentIndex + 1 < _currentQueue.length) {
      _currentIndex++;
      return currentSong;
    } else if (_repeatMode == RepeatMode.all) {
      _currentIndex = 0;
      return currentSong;
    }

    return null;
  }

  SongModel? skipToPrevious() {
    if (_currentQueue.isEmpty) return null;

    if (_repeatMode == RepeatMode.one) {
      return currentSong;
    }

    if (_currentIndex - 1 >= 0) {
      _currentIndex--;
      return currentSong;
    } else if (_repeatMode == RepeatMode.all) {
      _currentIndex = _currentQueue.length - 1;
      return currentSong;
    }

    return null;
  }

  SongModel? skipToIndex(int index) {
    if (index >= 0 && index < _currentQueue.length) {
      _currentIndex = index;
      return currentSong;
    }
    return null;
  }

  SongModel? removeAt(int index) {
    if (index < 0 || index >= _currentQueue.length) return null;
    final removed = _currentQueue.removeAt(index);
    _originalQueue.remove(removed);

    if (_currentQueue.isEmpty) {
      _currentIndex = -1;
    } else if (index < _currentIndex) {
      _currentIndex--;
    } else if (index == _currentIndex) {
      if (_currentIndex >= _currentQueue.length) {
        _currentIndex = _currentQueue.length - 1;
      }
    }
    return removed;
  }

  void reorder(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _currentQueue.length) return;
    if (newIndex < 0 || newIndex > _currentQueue.length) return;

    final adjustedNewIndex = oldIndex < newIndex ? newIndex - 1 : newIndex;
    final song = _currentQueue.removeAt(oldIndex);
    _currentQueue.insert(adjustedNewIndex, song);

    if (_currentIndex == oldIndex) {
      _currentIndex = adjustedNewIndex;
    } else if (_currentIndex > oldIndex && _currentIndex <= adjustedNewIndex) {
      _currentIndex--;
    } else if (_currentIndex < oldIndex && _currentIndex >= adjustedNewIndex) {
      _currentIndex++;
    }
  }

  void toggleShuffle() {
    if (_currentQueue.isEmpty) return;

    final activeSong = currentSong;
    _isShuffled = !_isShuffled;

    if (_isShuffled) {
      final songsToShuffle = List<SongModel>.from(_originalQueue);
      if (activeSong != null) {
        songsToShuffle.remove(activeSong);
        songsToShuffle.shuffle(Random());
        _currentQueue.clear();
        _currentQueue.add(activeSong);
        _currentQueue.addAll(songsToShuffle);
        _currentIndex = 0;
      } else {
        songsToShuffle.shuffle(Random());
        _currentQueue.clear();
        _currentQueue.addAll(songsToShuffle);
        _currentIndex = 0;
      }
    } else {
      _currentQueue.clear();
      _currentQueue.addAll(_originalQueue);
      if (activeSong != null) {
        _currentIndex = _currentQueue.indexOf(activeSong);
      }
    }
  }

  void setRepeatMode(RepeatMode mode) {
    _repeatMode = mode;
  }

  void toggleRepeatMode() {
    switch (_repeatMode) {
      case RepeatMode.off:
        _repeatMode = RepeatMode.all;
        break;
      case RepeatMode.all:
        _repeatMode = RepeatMode.one;
        break;
      case RepeatMode.one:
        _repeatMode = RepeatMode.off;
        break;
    }
  }

  void clear() {
    _originalQueue.clear();
    _currentQueue.clear();
    _currentIndex = -1;
    _isShuffled = false;
    _repeatMode = RepeatMode.off;
  }
}