import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/session/backend_providers.dart';
import '../domain/profile_repository.dart';
import 'api_profile_repository.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) => pickRepository(ref, ApiProfileRepository.new));
