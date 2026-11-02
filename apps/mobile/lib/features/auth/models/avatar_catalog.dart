import 'dart:math';

class AvatarItem {
  final String id;
  final String name;
  final String category; // 'default' | 'female' | 'male'
  final String assetPath;
  final String thumbPath;

  const AvatarItem({
    required this.id,
    required this.name,
    required this.category,
    required this.assetPath,
    required this.thumbPath,
  });
}

class AvatarCatalog {
  static const AvatarItem defaultAvatar = AvatarItem(
    id: 'default_avatar',
    name: 'Royal Blue Mascot',
    category: 'default',
    assetPath: 'assets/avatars/default_avatar.webp',
    thumbPath: 'assets/avatars/default_avatar_thumb.webp',
  );

  static const List<AvatarItem> femaleAvatars = [
    AvatarItem(
      id: 'female_01',
      name: 'Maharani of Jaipur',
      category: 'female',
      assetPath: 'assets/avatars/female_01.webp',
      thumbPath: 'assets/avatars/female_01_thumb.webp',
    ),
    AvatarItem(
      id: 'female_02',
      name: 'Princess of Awadh',
      category: 'female',
      assetPath: 'assets/avatars/female_02.webp',
      thumbPath: 'assets/avatars/female_02_thumb.webp',
    ),
    AvatarItem(
      id: 'female_03',
      name: 'Glamorous Bridal Queen',
      category: 'female',
      assetPath: 'assets/avatars/female_03.webp',
      thumbPath: 'assets/avatars/female_03_thumb.webp',
    ),
    AvatarItem(
      id: 'female_04',
      name: 'Sapphire Sovereign',
      category: 'female',
      assetPath: 'assets/avatars/female_04.webp',
      thumbPath: 'assets/avatars/female_04_thumb.webp',
    ),
    AvatarItem(
      id: 'female_05',
      name: 'Emerald Princess',
      category: 'female',
      assetPath: 'assets/avatars/female_05.webp',
      thumbPath: 'assets/avatars/female_05_thumb.webp',
    ),
    AvatarItem(
      id: 'female_06',
      name: 'Royal Crimson Bride',
      category: 'female',
      assetPath: 'assets/avatars/female_06.webp',
      thumbPath: 'assets/avatars/female_06_thumb.webp',
    ),
    AvatarItem(
      id: 'female_07',
      name: 'Card Master Devi',
      category: 'female',
      assetPath: 'assets/avatars/female_07.webp',
      thumbPath: 'assets/avatars/female_07_thumb.webp',
    ),
    AvatarItem(
      id: 'female_08',
      name: 'Maharani with Golden Cards',
      category: 'female',
      assetPath: 'assets/avatars/female_08.webp',
      thumbPath: 'assets/avatars/female_08_thumb.webp',
    ),
    AvatarItem(
      id: 'female_09',
      name: 'Teal Regal Sultana',
      category: 'female',
      assetPath: 'assets/avatars/female_09.webp',
      thumbPath: 'assets/avatars/female_09_thumb.webp',
    ),
    AvatarItem(
      id: 'female_10',
      name: 'Andean Sun Queen',
      category: 'female',
      assetPath: 'assets/avatars/female_10.webp',
      thumbPath: 'assets/avatars/female_10_thumb.webp',
    ),
    AvatarItem(
      id: 'female_11',
      name: 'Byzantine Empress',
      category: 'female',
      assetPath: 'assets/avatars/female_11.webp',
      thumbPath: 'assets/avatars/female_11_thumb.webp',
    ),
    AvatarItem(
      id: 'female_12',
      name: 'Celtic High Queen',
      category: 'female',
      assetPath: 'assets/avatars/female_12.webp',
      thumbPath: 'assets/avatars/female_12_thumb.webp',
    ),
    AvatarItem(
      id: 'female_13',
      name: 'Emerald Tudor Queen',
      category: 'female',
      assetPath: 'assets/avatars/female_13.webp',
      thumbPath: 'assets/avatars/female_13_thumb.webp',
    ),
    AvatarItem(
      id: 'female_14',
      name: 'Joseon Queen Dowager',
      category: 'female',
      assetPath: 'assets/avatars/female_14.webp',
      thumbPath: 'assets/avatars/female_14_thumb.webp',
    ),
    AvatarItem(
      id: 'female_15',
      name: 'Mughal Maharani',
      category: 'female',
      assetPath: 'assets/avatars/female_15.webp',
      thumbPath: 'assets/avatars/female_15_thumb.webp',
    ),
    AvatarItem(
      id: 'female_16',
      name: 'Regal Nubian Queen',
      category: 'female',
      assetPath: 'assets/avatars/female_16.webp',
      thumbPath: 'assets/avatars/female_16_thumb.webp',
    ),
    AvatarItem(
      id: 'female_17',
      name: 'Persian Velvet Queen',
      category: 'female',
      assetPath: 'assets/avatars/female_17.webp',
      thumbPath: 'assets/avatars/female_17_thumb.webp',
    ),
    AvatarItem(
      id: 'female_18',
      name: 'Sapphire Throne Empress',
      category: 'female',
      assetPath: 'assets/avatars/female_18.webp',
      thumbPath: 'assets/avatars/female_18_thumb.webp',
    ),
  ];

  static const List<AvatarItem> maleAvatars = [
    AvatarItem(
      id: 'male_01',
      name: 'Prince of Hyderabad',
      category: 'male',
      assetPath: 'assets/avatars/male_01.webp',
      thumbPath: 'assets/avatars/male_01_thumb.webp',
    ),
    AvatarItem(
      id: 'male_02',
      name: 'Royal Diamond Raja',
      category: 'male',
      assetPath: 'assets/avatars/male_02.webp',
      thumbPath: 'assets/avatars/male_02_thumb.webp',
    ),
    AvatarItem(
      id: 'male_03',
      name: 'Imperial Golden Prince',
      category: 'male',
      assetPath: 'assets/avatars/male_03.webp',
      thumbPath: 'assets/avatars/male_03_thumb.webp',
    ),
    AvatarItem(
      id: 'male_04',
      name: 'Golden Card King',
      category: 'male',
      assetPath: 'assets/avatars/male_04.webp',
      thumbPath: 'assets/avatars/male_04_thumb.webp',
    ),
    AvatarItem(
      id: 'male_05',
      name: 'Regal Sapphire Nawab',
      category: 'male',
      assetPath: 'assets/avatars/male_05.webp',
      thumbPath: 'assets/avatars/male_05_thumb.webp',
    ),
    AvatarItem(
      id: 'male_06',
      name: 'Royal Spades King',
      category: 'male',
      assetPath: 'assets/avatars/male_06.webp',
      thumbPath: 'assets/avatars/male_06_thumb.webp',
    ),
    AvatarItem(
      id: 'male_07',
      name: 'High-Stakes Gambler',
      category: 'male',
      assetPath: 'assets/avatars/male_07.webp',
      thumbPath: 'assets/avatars/male_07_thumb.webp',
    ),
    AvatarItem(
      id: 'male_08',
      name: 'Han Dynasty Sovereign',
      category: 'male',
      assetPath: 'assets/avatars/male_08.webp',
      thumbPath: 'assets/avatars/male_08_thumb.webp',
    ),
    AvatarItem(
      id: 'male_09',
      name: 'Nordic Grand Duke',
      category: 'male',
      assetPath: 'assets/avatars/male_09.webp',
      thumbPath: 'assets/avatars/male_09_thumb.webp',
    ),
    AvatarItem(
      id: 'male_10',
      name: 'Ottoman Sultan',
      category: 'male',
      assetPath: 'assets/avatars/male_10.webp',
      thumbPath: 'assets/avatars/male_10_thumb.webp',
    ),
    AvatarItem(
      id: 'male_11',
      name: 'Persian Shah',
      category: 'male',
      assetPath: 'assets/avatars/male_11.webp',
      thumbPath: 'assets/avatars/male_11_thumb.webp',
    ),
    AvatarItem(
      id: 'male_12',
      name: 'Polynesian Ariki',
      category: 'male',
      assetPath: 'assets/avatars/male_12.webp',
      thumbPath: 'assets/avatars/male_12_thumb.webp',
    ),
    AvatarItem(
      id: 'male_13',
      name: 'Rajput Maharaja',
      category: 'male',
      assetPath: 'assets/avatars/male_13.webp',
      thumbPath: 'assets/avatars/male_13_thumb.webp',
    ),
    AvatarItem(
      id: 'male_14',
      name: 'Slavic Tsar',
      category: 'male',
      assetPath: 'assets/avatars/male_14.webp',
      thumbPath: 'assets/avatars/male_14_thumb.webp',
    ),
    AvatarItem(
      id: 'male_15',
      name: 'Venetian Doge',
      category: 'male',
      assetPath: 'assets/avatars/male_15.webp',
      thumbPath: 'assets/avatars/male_15_thumb.webp',
    ),
    AvatarItem(
      id: 'male_16',
      name: 'Yoruba Oba',
      category: 'male',
      assetPath: 'assets/avatars/male_16.webp',
      thumbPath: 'assets/avatars/male_16_thumb.webp',
    ),
    AvatarItem(
      id: 'male_17',
      name: 'Persian Nobleman',
      category: 'male',
      assetPath: 'assets/avatars/male_17.webp',
      thumbPath: 'assets/avatars/male_17_thumb.webp',
    ),
    AvatarItem(
      id: 'male_18',
      name: 'Polynesian Warrior King',
      category: 'male',
      assetPath: 'assets/avatars/male_18.webp',
      thumbPath: 'assets/avatars/male_18_thumb.webp',
    ),
    AvatarItem(
      id: 'male_19',
      name: 'Aztec Gold Ruler',
      category: 'male',
      assetPath: 'assets/avatars/male_19.webp',
      thumbPath: 'assets/avatars/male_19_thumb.webp',
    ),
    AvatarItem(
      id: 'male_20',
      name: 'Imperial Uniform King',
      category: 'male',
      assetPath: 'assets/avatars/male_20.webp',
      thumbPath: 'assets/avatars/male_20_thumb.webp',
    ),
    AvatarItem(
      id: 'male_21',
      name: 'Hanfu Emperor',
      category: 'male',
      assetPath: 'assets/avatars/male_21.webp',
      thumbPath: 'assets/avatars/male_21_thumb.webp',
    ),
    AvatarItem(
      id: 'male_22',
      name: 'Emerald Maharaja',
      category: 'male',
      assetPath: 'assets/avatars/male_22.webp',
      thumbPath: 'assets/avatars/male_22_thumb.webp',
    ),
    AvatarItem(
      id: 'male_23',
      name: 'Crimson Monarch',
      category: 'male',
      assetPath: 'assets/avatars/male_23.webp',
      thumbPath: 'assets/avatars/male_23_thumb.webp',
    ),
    AvatarItem(
      id: 'male_24',
      name: 'Ottoman Sultan Portrait',
      category: 'male',
      assetPath: 'assets/avatars/male_24.webp',
      thumbPath: 'assets/avatars/male_24_thumb.webp',
    ),
    AvatarItem(
      id: 'male_25',
      name: 'Yoruba Golden King',
      category: 'male',
      assetPath: 'assets/avatars/male_25.webp',
      thumbPath: 'assets/avatars/male_25_thumb.webp',
    ),
    AvatarItem(
      id: 'male_26',
      name: 'Renaissance Nobleman',
      category: 'male',
      assetPath: 'assets/avatars/male_26.webp',
      thumbPath: 'assets/avatars/male_26_thumb.webp',
    ),
  ];

  static List<AvatarItem> get all => [
    defaultAvatar,
    ...femaleAvatars,
    ...maleAvatars,
  ];

  /// Find avatar item by id or asset path
  static AvatarItem? find(String? photoURL) {
    if (photoURL == null || photoURL.isEmpty) return null;
    for (final item in all) {
      if (item.id == photoURL || item.assetPath == photoURL || item.thumbPath == photoURL) {
        return item;
      }
    }
    return null;
  }

  /// Whether a photoURL string represents a preset avatar or a custom uploaded photo
  static bool isPreset(String? photoURL) {
    return find(photoURL) != null;
  }

  /// Whether a photoURL string is a custom photo (e.g. data:image/base64 or http URL)
  static bool isCustomPhoto(String? photoURL) {
    if (photoURL == null || photoURL.isEmpty) return false;
    if (photoURL.startsWith('http://') ||
        photoURL.startsWith('https://') ||
        photoURL.startsWith('data:image')) {
      return true;
    }
    return !isPreset(photoURL);
  }

  /// Get appropriate asset path for table seating
  static String getFullAssetPath(String? photoURL) {
    final item = find(photoURL);
    if (item != null) return item.assetPath;
    return defaultAvatar.assetPath;
  }

  /// Get appropriate thumbnail path for profile circles and picker grids
  static String getThumbAssetPath(String? photoURL) {
    final item = find(photoURL);
    if (item != null) return item.thumbPath;
    return defaultAvatar.thumbPath;
  }

  /// Select a random avatar (e.g. when user hasn't chosen one)
  static AvatarItem getRandom([String? gender]) {
    final rand = Random();
    if (gender == 'female') {
      return femaleAvatars[rand.nextInt(femaleAvatars.length)];
    } else if (gender == 'male') {
      return maleAvatars[rand.nextInt(maleAvatars.length)];
    }
    // Random from all excluding default
    final combined = [...femaleAvatars, ...maleAvatars];
    return combined[rand.nextInt(combined.length)];
  }
}

