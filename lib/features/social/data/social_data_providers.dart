import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/session/backend_providers.dart';
import '../domain/social_repository.dart';
import 'api_social_repository.dart';

final socialRepositoryProvider = Provider<SocialRepository>((ref) => pickRepository(ref, ApiSocialRepository.new));
