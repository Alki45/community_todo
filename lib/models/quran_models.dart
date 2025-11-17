class Ayah {
  const Ayah({
    required this.surahNumber,
    required this.ayahNumber,
    required this.text,
  });

  final int surahNumber;
  final int ayahNumber;
  final String text;
}

class Surah {
  const Surah({
    required this.index,
    required this.arabicName,
    required this.englishName,
    required this.verses,
  });

  final int index;
  final String arabicName;
  final String englishName;
  final List<Ayah> verses;
}







