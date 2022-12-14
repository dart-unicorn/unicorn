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

    container.registerService<Foo, Foo>(
      scope: Scope.transient,
      factory: (_) => Foo(),
    );
  }

  @override
  void run() {
    for (var i = 0; i < N; i++) {
      container.resolve<Foo>();
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

    container.registerService<Foo, Foo>(
      scope: Scope.transient,
      factory: (_) => Foo(),
    );
    container.registerService<Bar, Bar>(
      scope: Scope.transient,
      factory: (request) => Bar(request(Foo)),
    );
  }

  @override
  void run() {
    for (var i = 0; i < N; i++) {
      container.resolve<Bar>();
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

    container.registerService<Foo, Foo>(
      scope: Scope.transient,
      factory: (_) => Foo(),
    );
    container.registerService<Bar, Bar>(
      scope: Scope.transient,
      factory: (request) => Bar(request(Foo)),
    );
    container.registerService<Baz, Baz>(
      scope: Scope.transient,
      factory: (_) => Baz(),
    );
    container.registerService<Qux, Qux>(
      scope: Scope.transient,
      factory: (request) => Qux(request(Foo), request(Bar), request(Baz)),
    );
  }

  @override
  void run() {
    for (var i = 0; i < N; i++) {
      container.resolve<Qux>();
    }
  }
}

void main() {
  ResolveOneHasNoDependencies().report();
  ResolveOneHasOneDependencies().report();
  ResolveOneHasThreeDependencies().report();
}
