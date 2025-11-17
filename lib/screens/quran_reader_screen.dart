import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/surah_metadata.dart';
import '../providers/quran_provider.dart';
import '../models/quran_models.dart';
import '../services/quran_service.dart';

class QuranReaderScreen extends StatefulWidget {
  const QuranReaderScreen({
    super.key,
    this.initialSurah,
    this.initialAyah,
  });

  final String? initialSurah;
  final int? initialAyah;

  @override
  State<QuranReaderScreen> createState() => _QuranReaderScreenState();
}

class _QuranReaderScreenState extends State<QuranReaderScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  int? _selectedSurah;
  int? _selectedAyah;
  String _searchQuery = '';
  bool _showSearch = false;
  bool _showSurahList = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialSurah != null && mounted) {
        final surahNumber = _resolveSurahNumber(widget.initialSurah!);
        if (surahNumber != null) {
          setState(() {
            _selectedSurah = surahNumber;
            _selectedAyah = widget.initialAyah;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  QuranService get _quranService {
    final quranProvider = context.read<QuranProvider>();
    return quranProvider.service;
  }

  void _scrollToAyah(int ayahNumber) {
    // Calculate approximate position (this is a simple estimation)
    final surah = _quranService.getSurah(_selectedSurah!);
    if (surah == null) return;

    final ayahIndex = surah.verses.indexWhere((a) => a.ayahNumber == ayahNumber);
    if (ayahIndex == -1) return;

    // Estimate scroll position (each ayah is roughly 100 pixels)
    final estimatedPosition = ayahIndex * 100.0;
    _scrollController.animateTo(
      estimatedPosition.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  List<int> _getFilteredSurahs() {
    if (_searchQuery.isEmpty) {
      return List.generate(114, (i) => i + 1);
    }
    return List.generate(114, (i) => i + 1).where((index) {
      final englishName = kSurahNamesEnglish[index - 1].toLowerCase();
      final transliterated = kSurahNamesTransliterated[index - 1].toLowerCase();
      final numberMatch = index.toString().contains(_searchQuery);
      return englishName.contains(_searchQuery) ||
          transliterated.contains(_searchQuery) ||
          numberMatch;
    }).toList();
  }

  int? _resolveSurahNumber(String input) {
    final normalized = input.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (normalized.isEmpty) return null;

    final numeric = int.tryParse(normalized);
    if (numeric != null && numeric >= 1 && numeric <= 114) {
      return numeric;
    }

    for (var i = 0; i < kSurahNamesEnglish.length; i++) {
      final index = i + 1;
      final english = kSurahNamesEnglish[i].toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      final transliterated = kSurahNamesTransliterated[i].toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      if (english.contains(normalized) || transliterated.contains(normalized)) {
        return index;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final quranProvider = context.watch<QuranProvider>();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (!quranProvider.isLoaded) {
      return Scaffold(
        body: Container(
          color: colorScheme.surface,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  quranProvider.isLoading
                      ? 'Loading Qur\'an...'
                      : 'Qur\'an data unavailable',
                  style: theme.textTheme.bodyLarge,
                ),
              ],
            ),
          ),
        ),
      );
    }

    final surah = _selectedSurah != null
        ? quranProvider.service.getSurah(_selectedSurah!)
        : null;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      extendBodyBehindAppBar: false,
      body: Column(
        children: [
          // Top bar with search and controls - extends to top
          Container(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: MediaQuery.of(context).padding.top + 8,
              bottom: 8,
            ),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'Exit',
                ),
                  Expanded(
                    child: _showSearch
                        ? TextField(
                            controller: _searchController,
                            autofocus: true,
                            decoration: InputDecoration(
                              hintText: surah != null
                                  ? 'Search ayah number or text...'
                                  : 'Search surah name or number...',
                              border: InputBorder.none,
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {
                                    _showSearch = false;
                                  });
                                },
                              ),
                            ),
                            onSubmitted: (value) {
                              if (surah != null && value.isNotEmpty) {
                                final ayahNum = int.tryParse(value.trim());
                                if (ayahNum != null && ayahNum >= 1) {
                                  setState(() {
                                    _selectedAyah = ayahNum;
                                    _showSearch = false;
                                  });
                                  _scrollToAyah(ayahNum);
                                }
                              }
                            },
                          )
                        : Text(
                            surah != null
                                ? 'Surah ${surah.englishName}'
                                : 'Select a Surah',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                  IconButton(
                    icon: Icon(_showSearch ? Icons.search_off : Icons.search),
                    onPressed: () {
                      setState(() {
                        _showSearch = !_showSearch;
                        if (!_showSearch) {
                          _searchController.clear();
                        }
                      });
                    },
                    tooltip: 'Search',
                  ),
                  IconButton(
                    icon: Icon(_showSurahList ? Icons.menu_book : Icons.list),
                    onPressed: () {
                      setState(() {
                        _showSurahList = !_showSurahList;
                      });
                    },
                    tooltip: 'Surah list',
                  ),
                ],
              ),
            ),

          // Content area
          Expanded(
            child: _showSurahList
                ? _buildSurahList(theme, colorScheme)
                : surah == null
                    ? _buildSurahSelector(theme, colorScheme)
                    : _buildQuranContent(surah, theme, colorScheme),
          ),
        ],
      ),
    );
  }

  Widget _buildSurahSelector(
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    final filteredSurahs = _getFilteredSurahs();

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredSurahs.length,
      itemBuilder: (context, index) {
        final surahNumber = filteredSurahs[index];
        final englishName = kSurahNamesEnglish[surahNumber - 1];
        final transliterated = kSurahNamesTransliterated[surahNumber - 1];
              final surah = _quranService.getSurah(surahNumber);
        final verseCount = surah?.verses.length ?? 0;

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: colorScheme.primaryContainer,
              child: Text(
                '$surahNumber',
                style: TextStyle(
                  color: colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(englishName),
            subtitle: Text('$transliterated • $verseCount verses'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              setState(() {
                _selectedSurah = surahNumber;
                _selectedAyah = null;
                _showSurahList = false;
              });
            },
          ),
        );
      },
    );
  }

  Widget _buildSurahList(
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    final filteredSurahs = _getFilteredSurahs();

    return Column(
      children: [
        if (_searchQuery.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              '${filteredSurahs.length} surah${filteredSurahs.length != 1 ? 's' : ''} found',
              style: theme.textTheme.bodySmall,
            ),
          ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: filteredSurahs.length,
            itemBuilder: (context, index) {
              final surahNumber = filteredSurahs[index];
              final englishName = kSurahNamesEnglish[surahNumber - 1];
              final transliterated = kSurahNamesTransliterated[surahNumber - 1];
              final surah = _quranService.getSurah(surahNumber);
              final verseCount = surah?.verses.length ?? 0;

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: colorScheme.primaryContainer,
                    child: Text(
                      '$surahNumber',
                      style: TextStyle(
                        color: colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(englishName),
                  subtitle: Text('$transliterated • $verseCount verses'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    setState(() {
                      _selectedSurah = surahNumber;
                      _selectedAyah = null;
                      _showSurahList = false;
                    });
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildQuranContent(
    Surah surah,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    final verses = surah.verses;
    final filteredVerses = _searchQuery.isEmpty
        ? verses
        : verses.where((ayah) {
            final ayahText = ayah.text.toLowerCase();
            final ayahNumber = ayah.ayahNumber.toString();
            return ayahText.contains(_searchQuery) ||
                ayahNumber.contains(_searchQuery);
          }).toList();

    if (filteredVerses.isEmpty && _searchQuery.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              'No verses found',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Try a different search term',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return Scrollbar(
      controller: _scrollController,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(24),
        itemCount: filteredVerses.length,
        itemBuilder: (context, index) {
          final ayah = filteredVerses[index];
          final isHighlighted = _selectedAyah == ayah.ayahNumber;

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isHighlighted
                            ? colorScheme.primaryContainer
                            : colorScheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${ayah.ayahNumber}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isHighlighted
                              ? colorScheme.onPrimaryContainer
                              : colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    if (index < filteredVerses.length - 1)
                      Container(
                        width: 40,
                        height: 1,
                        color: colorScheme.outlineVariant,
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isHighlighted
                        ? colorScheme.primaryContainer.withOpacity(0.3)
                        : null,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SelectableText(
                    ayah.text,
                    textDirection: ui.TextDirection.rtl,
                    textAlign: TextAlign.right,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      height: 2.0,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

