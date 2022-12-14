import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:unicorn/src/dependency_injection/dependency_injection.dart';

class Foo {
  Foo();
}

class Bar {
  Bar(Foo foo);
}

class Baz {
  Baz();
}

class Qux {
  Qux(Foo foo, Bar bar, Baz baz);
}

class ResolveOneHasNoDependencies extends BenchmarkBase {
  ResolveOneHasNoDependencies() : super("ResolveOneHasNoDependencies x100k");

  static const N = 100000;

  late ServiceContainer container;

  @override
  void setup() {
    container = ServiceContainer();

    container.addService<Foo, Foo>(
      lifetime: ServiceLifetime.transient,
      factory: (_) => Foo(),
    );
  }

  @override
  void run() {
    for (var i = 0; i < N; i++) {
      container.getService<Foo>();
    }
  }
}

class ResolveOneHasOneDependencies extends BenchmarkBase {
  ResolveOneHasOneDependencies() : super("ResolveOneHasOneDependencies x100k");

  static const N = 100000;

  late ServiceContainer container;

  @override
  void setup() {
    container = ServiceContainer();

    container.addService<Foo, Foo>(
      lifetime: ServiceLifetime.transient,
      factory: (_) => Foo(),
    );
    container.addService<Bar, Bar>(
      lifetime: ServiceLifetime.transient,
      factory: (request) => Bar(request(Foo)),
    );
  }

  @override
  void run() {
    for (var i = 0; i < N; i++) {
      container.getService<Bar>();
    }
  }
}

class ResolveOneHasThreeDependencies extends BenchmarkBase {
  ResolveOneHasThreeDependencies()
      : super("ResolveOneHasThreeDependencies x100k");

  static const N = 100000;

  late ServiceContainer container;

  @override
  void setup() {
    container = ServiceContainer();

    container.addService<Foo, Foo>(
      lifetime: ServiceLifetime.transient,
      factory: (_) => Foo(),
    );
    container.addService<Bar, Bar>(
      lifetime: ServiceLifetime.transient,
      factory: (request) => Bar(request(Foo)),
    );
    container.addService<Baz, Baz>(
      lifetime: ServiceLifetime.transient,
      factory: (_) => Baz(),
    );
    container.addService<Qux, Qux>(
      lifetime: ServiceLifetime.transient,
      factory: (request) => Qux(request(Foo), request(Bar), request(Baz)),
    );
  }

  @override
  void run() {
    for (var i = 0; i < N; i++) {
      container.getService<Qux>();
    }
  }
}

void main() {
  ResolveOneHasNoDependencies().report();
  ResolveOneHasOneDependencies().report();
  ResolveOneHasThreeDependencies().report();
}
