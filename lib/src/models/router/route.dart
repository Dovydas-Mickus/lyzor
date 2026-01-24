import 'package:lyzor/src/lyzor_base.dart';
import 'package:lyzor/src/lyzor_middleware.dart';

class Route {
  final Handler handler;
  final List<Middleware> middlewares;
  final String method;

  Route use(Middleware middleware) {
    middlewares.add(middleware);
    return this;
  }

  Route(this.method, this.handler, this.middlewares);
}
