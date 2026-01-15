typedef ValidationRule = String? Function(dynamic value);

class Validator {
  final Map<String, List<ValidationRule>> rules;

  Validator(this.rules);

  Map<String, List<String>> validate(Map<String, dynamic> data) {
    final errors = <String, List<String>>{};

    rules.forEach((field, fieldRules) {
      final value = data[field];
      for (final rule in fieldRules) {
        final error = rule(value);
        if (error != null) {
          errors.putIfAbsent(field, () => []).add(error);
        }
      }
    });

    return errors;
  }
}

class Rules {
  static ValidationRule isRequired([String msg = 'This field is required']) =>
      (v) => (v == null || (v is String && v.trim().isEmpty)) ? msg : null;

  static ValidationRule isEmail([String msg = 'Invalid email address']) => (v) {
    if (v == null || v is! String) return null;
    final emailRegex = RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$');
    return emailRegex.hasMatch(v) ? null : msg;
  };

  static ValidationRule minLength(int min, [String? msg]) => (v) {
    if (v == null || v is! String) return null;
    return v.length < min ? (msg ?? 'Minimum length is $min') : null;
  };

  static ValidationRule isInt([String msg = 'Must be an integer']) =>
      (v) => v is int || (v is String && int.tryParse(v) != null) ? null : msg;
}
