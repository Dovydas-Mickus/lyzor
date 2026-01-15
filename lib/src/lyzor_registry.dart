class Registry {
  final Map<Type, dynamic> _services = {};

  void register<T>(T service) {
    _services[T] = service;
  }

  T get<T>() {
    final service = _services[T];
    if (service == null) {
      throw Exception('Service of type $T not found. Did you forget to call app.provide<$T>(service)?');
    }
    return service as T;
  }
}
