import 'package:flutter/foundation.dart';

import '../models/quran_models.dart';
import '../services/quran_service.dart';

class QuranProvider extends ChangeNotifier {
  QuranProvider({required QuranService service}) : _service = service {
    _init();
  }

  QuranService _service;
  bool _isLoading = false;
  bool _hasTriedLoading = false;

  bool get isLoading => _isLoading;
  bool get isLoaded => _service.isLoaded;
  String? get errorMessage => _service.errorMessage;

  void updateService(QuranService service) {
    if (!identical(_service, service)) {
      _service = service;
      if (!_service.isLoaded && !_isLoading) {
        _init();
      }
    }
  }

  Future<void> _init() async {
    if (_isLoading || _service.isLoaded) {
      return;
    }
    _isLoading = true;
    _hasTriedLoading = true;
    notifyListeners();

    await _service.load();

    _isLoading = false;
    notifyListeners();
  }

  List<Ayah> versesForRange(String surahName, String ayahRange) {
    if (!_service.isLoaded) {
      return const [];
    }
    return _service.versesForRange(surahName, ayahRange);
  }

  String verseText(
    String surahName,
    String ayahRange, {
    int maxAyat = 5,
  }) {
    if (!_service.isLoaded) {
      return '';
    }
    return _service.joinedAyahText(
      surahName,
      ayahRange,
      maxAyat: maxAyat,
    );
  }

  bool get attemptedLoad => _hasTriedLoading;
  
  QuranService get service => _service;
}







