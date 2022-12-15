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

ServiceContainer createServiceContainerWithDependencies() {
  final builder = ServiceContainerBuilder();
  builder.configureServices((services) {
    services.addService((service) {
      service
        ..bind<Foo>()
        ..implementation<Foo>()
        ..inTransientScope()
        ..useFactory((_) => Foo());
    });
    services.addService((service) {
      service
        ..bind<Bar>()
        ..implementation<Bar>()
        ..inTransientScope()
        ..useFactory((c) => Bar(c.require<Foo>()));
    });
    services.addService((service) {
      service
        ..bind<Baz>()
        ..implementation<Baz>()
        ..inTransientScope()
        ..useFactory((_) => Baz());
    });
    services.addService((service) {
      service
        ..bind<Qux>()
        ..implementation<Qux>()
        ..inTransientScope()
        ..useFactory(
            (c) => Qux(c.require<Foo>(), c.require<Bar>(), c.require<Baz>()));
    });
  });
  return builder.build();
}

class ResolveOneHasNoDependencies extends BenchmarkBase {
  ResolveOneHasNoDependencies() : super("ResolveOneHasNoDependencies x100k");

  static const N = 100000;

  late ServiceContainer container;

  @override
  void setup() {
    container = createServiceContainerWithDependencies();
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
    container = createServiceContainerWithDependencies();
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
    container = createServiceContainerWithDependencies();
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
