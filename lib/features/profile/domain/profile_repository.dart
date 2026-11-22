import '../../social/domain/social_entities.dart';

/// Only the fields that are set are changed.
class ProfileUpdate {
  const ProfileUpdate({
    this.name,
    this.handle,
    this.bio,
    this.birthday,
    this.clearBirthday = false,
    this.favoriteFoods,
    this.favoriteCategoryIds,
  });

  final String? name;
  final String? handle;
  final String? bio;
  final DateTime? birthday;
  final bool clearBirthday;
  final List<String>? favoriteFoods;
  final List<String>? favoriteCategoryIds;
}

abstract interface class ProfileRepository {
  Future<AppUser> updateProfile(ProfileUpdate update);
}
