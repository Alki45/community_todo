import 'dart:collection';

import 'package:flutter/services.dart';
import 'package:xml/xml.dart';

import '../data/surah_metadata.dart';
import '../models/quran_models.dart';

class QuranService {
  QuranService({this.assetPath = 'assets/quran/quran-uthmani.xml'});

  final String assetPath;

  final Map<int, Surah> _surahsByIndex = {};
  final Map<String, int> _nameLookup = {};
  bool _isLoaded = false;
  String? _errorMessage;

  bool get isLoaded => _isLoaded;
  String? get errorMessage => _errorMessage;

  Future<void> load() async {
    if (_isLoaded) {
      return;
    }

    try {
      final raw = await rootBundle.loadString(assetPath);
      final document = XmlDocument.parse(raw);
      _populateNameLookup();

      for (final sura in document.findAllElements('sura')) {
        final indexAttr =
            sura.getAttribute('index') ?? sura.getAttribute('sura');
        if (indexAttr == null) {
          continue;
        }
        final index = int.tryParse(indexAttr);
        if (index == null) {
          continue;
        }

        final arabicName =
            sura.getAttribute('name') ?? sura.getAttribute('arabic') ?? '';
        final englishName = _englishNameForIndex(index);

        final verses = <Ayah>[];
        for (final aya in sura.findElements('aya')) {
          final ayahAttr =
              aya.getAttribute('index') ?? aya.getAttribute('aya') ?? '';
          final ayahNumber = int.tryParse(ayahAttr);
          if (ayahNumber == null) {
            continue;
          }
          final textAttribute = aya.getAttribute('text');
          final text = (textAttribute ?? aya.innerText).trim();
          verses.add(
            Ayah(surahNumber: index, ayahNumber: ayahNumber, text: text),
          );
        }

        _surahsByIndex[index] = Surah(
          index: index,
          arabicName: arabicName,
          englishName: englishName,
          verses: UnmodifiableListView(verses),
        );
      }

      // Some Tanzil exports flatten the structure without <sura/> nodes.
      // If nothing was parsed, try alternative structure: <aya sura="1" aya="1" text="...">
      if (_surahsByIndex.isEmpty) {
        final versesBySurah = <int, List<Ayah>>{};
        for (final aya in document.findAllElements('aya')) {
          final suraAttr = aya.getAttribute('sura');
          final ayahAttr = aya.getAttribute('aya');
          final surahNumber = int.tryParse(suraAttr ?? '');
          final ayahNumber = int.tryParse(ayahAttr ?? '');
          if (surahNumber == null || ayahNumber == null) {
            continue;
          }
          final text = aya.getAttribute('text') ?? aya.innerText.trim();
          versesBySurah
              .putIfAbsent(surahNumber, () => [])
              .add(
                Ayah(
                  surahNumber: surahNumber,
                  ayahNumber: ayahNumber,
                  text: text,
                ),
              );
        }

        versesBySurah.forEach((index, verses) {
          _surahsByIndex[index] = Surah(
            index: index,
            arabicName: '',
            englishName: _englishNameForIndex(index),
            verses: UnmodifiableListView(verses),
          );
        });
      }

      _isLoaded = _surahsByIndex.isNotEmpty;
      _errorMessage = _isLoaded
          ? null
          : 'Unable to parse Qur\'an dataset from $assetPath';
    } catch (error) {
      _errorMessage = error.toString();
    }
  }

  Surah? getSurah(int index) => _surahsByIndex[index];

  List<Ayah> versesForRange(String surahNameOrNumber, String range) {
    final surahNumber = _resolveSurahNumber(surahNameOrNumber);
    if (surahNumber == null) {
      return const [];
    }
    final surah = _surahsByIndex[surahNumber];
    if (surah == null) {
      return const [];
    }

    final bounds = range.split('-').map((part) => part.trim()).toList();
    final start = int.tryParse(bounds.elementAt(0)) ?? 1;
    final end = bounds.length > 1 ? int.tryParse(bounds.elementAt(1)) : null;

    final normalizedStart = start < 1 ? 1 : start;
    final cappedEnd = end == null || end < normalizedStart
        ? normalizedStart
        : (end > surah.verses.length ? surah.verses.length : end);

    return surah.verses
        .where(
          (ayah) =>
              ayah.ayahNumber >= normalizedStart &&
              ayah.ayahNumber <= cappedEnd,
        )
        .toList(growable: false);
  }

  String joinedAyahText(
    String surahNameOrNumber,
    String range, {
    int? maxAyat,
  }) {
    final verses = versesForRange(surahNameOrNumber, range);
    if (verses.isEmpty) {
      return '';
    }
    final limited = maxAyat == null
        ? verses
        : verses.take(maxAyat).toList(growable: false);
    final buffer = StringBuffer();
    for (final ayah in limited) {
      if (buffer.isNotEmpty) {
        buffer.write(' ');
      }
      buffer.write(ayah.text);
    }
    if (maxAyat != null && verses.length > maxAyat) {
      buffer.write(' …');
    }
    return buffer.toString();
  }

  int? _resolveSurahNumber(String input) {
    final normalized = _normalize(input);
    if (normalized.isEmpty) {
      return null;
    }

    final numeric = int.tryParse(normalized);
    if (numeric != null && numeric >= 1 && numeric <= 114) {
      return numeric;
    }

    return _nameLookup[normalized];
  }

  void _populateNameLookup() {
    _nameLookup.clear();
    for (var i = 0; i < kSurahNamesEnglish.length; i++) {
      final index = i + 1;
      final english = kSurahNamesEnglish[i];
      final transliterated = kSurahNamesTransliterated[i];
      _nameLookup[_normalize(english)] = index;
      _nameLookup[_normalize(transliterated)] = index;
      _nameLookup[_normalize('$index $english')] = index;
    }
  }

  String _englishNameForIndex(int index) {
    if (index >= 1 && index <= kSurahNamesEnglish.length) {
      return kSurahNamesEnglish[index - 1];
    }
    return 'Surah $index';
  }

  String _normalize(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
}
