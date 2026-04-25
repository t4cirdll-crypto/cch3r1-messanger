import '../constants/app_strings.dart';
import 'username_mapper.dart';

/// Валидаторы полей для TextFormField.
class Validators {
  const Validators._();

  static String? username(String? value) {
    final String v = (value ?? '').trim();
    if (v.isEmpty) return AppStrings.errorUsernameRequired;
    if (!UsernameMapper.isValid(v)) return AppStrings.errorUsernameFormat;
    return null;
  }

  static String? password(String? value) {
    final String v = value ?? '';
    if (v.isEmpty) return AppStrings.errorPasswordRequired;
    if (v.length < 6) return AppStrings.errorPasswordShort;
    return null;
  }

  static String? Function(String?) passwordMatch(String Function() other) {
    return (String? value) {
      if ((value ?? '') != other()) return AppStrings.errorPasswordsMismatch;
      return null;
    };
  }

  static String? nonEmpty(String? value) {
    return (value ?? '').trim().isEmpty ? 'Поле обязательно' : null;
  }
}
