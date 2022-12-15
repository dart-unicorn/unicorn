import 'package:test/test.dart';

import 'package:unicorn/src/dependency_injection/dependency_injection.dart';

/// Story:
/// There is a book store. The manager of the store want to develop a software
/// to accounting the books and stokes.
class BookStore {
  BookStore(this.bookRepository, this.stockService);

  final BookRepository bookRepository;

  final StockService stockService;
}

class StockService {
  StockService(this.bookRepository);

  final BookRepository bookRepository;
}

class BookRepository {}

class Foo {}

class OpaqueVisibility implements IServiceVisibilityBehavior {
  const OpaqueVisibility();

  @override
  bool isVisibleFor(ServiceRequestContext request) {
    return false;
  }
}

ServiceContainer createEmptyServiceContainer() {
  final builder = ServiceContainerBuilder();

  return builder.build();
}

ServiceContainer createServiceContainerWithDependencies({
  IServiceVisibilityBehavior visibilityBehavior = const TransparentVisibility(),
  ServiceLifetime lifetime = ServiceLifetime.transient,
}) {
  final builder = ServiceContainerBuilder();

  builder
    ..configureServices((services) {
      services
        ..addService((service) {
          service
            ..bind<BookStore>()
            ..implementation<BookStore>()
            ..inScope(lifetime)
            ..useFactory((c) => BookStore(c.require(), c.require()));
        })
        ..addService((service) {
          service
            ..bind<StockService>()
            ..implementation<StockService>()
            ..inScope(lifetime)
            ..useFactory((c) => StockService(c.require()));
        })
        ..addService((service) {
          service
            ..bind<BookRepository>()
            ..implementation<BookRepository>()
            ..inScope(lifetime)
            ..useFactory((c) => BookRepository());
        });
    })
    ..visibilityBehavior(visibilityBehavior);

  return builder.build();
}

void main() {
  group("dependency injection", () {
    test("should resolve a service without dependencies", () {
      var container = createServiceContainerWithDependencies();

      var bookStore = container.getService<BookRepository>();

      expect(bookStore, isA<BookRepository>());
    });

    test("should resolve a service with its dependencies", () {
      var container = createServiceContainerWithDependencies();

      var bookStore = container.getService<BookStore>();

      expect(bookStore, isA<BookStore>());
    });

    test(
      "should throw ServiceNotFoundError if the service is not added",
      () {
        var container = createServiceContainerWithDependencies();

        expect(
          () => container.getService<Foo>(),
          throwsA(isA<ServiceNotFoundError>()),
        );
      },
    );

    test(
      "should resolve a service with transient lifetime",
      () {
        var container = createServiceContainerWithDependencies(
          lifetime: ServiceLifetime.transient,
        );

        var firstResolved = container.getService<BookStore>();
        var secondResolved = container.getService<BookStore>();

        expect(
          firstResolved,
          isNot(equals(secondResolved)),
        );
      },
    );

    test(
      "should resolve a service with singleton lifetime",
      () {
        var container = createServiceContainerWithDependencies(
          lifetime: ServiceLifetime.singleton,
        );

        var firstResolved = container.getService<BookStore>();
        var secondResolved = container.getService<BookStore>();

        expect(
          firstResolved,
          equals(secondResolved),
        );
      },
    );

    test(
      "should resolve a service with request lifetime",
      () {
        var container = createServiceContainerWithDependencies(
          lifetime: ServiceLifetime.request,
        );

        var firstResolved = container.getService<BookStore>();
        var secondResolved = container.getService<BookStore>();

        expect(
          firstResolved,
          isNot(equals(secondResolved)),
        );
        expect(
          firstResolved.bookRepository,
          equals(firstResolved.stockService.bookRepository),
        );
      },
    );

    test(
      "should lookup from parent container if the service not added into",
      () {
        var parent = createServiceContainerWithDependencies(
          lifetime: ServiceLifetime.request,
        );
        var child = createEmptyServiceContainer().withUpstream(parent);

        expect(child.getService<BookRepository>(), isA<BookRepository>());
      },
    );

    test(
      "should control under service visibility behavior",
      () {
        var opaque = createServiceContainerWithDependencies(
          visibilityBehavior: OpaqueVisibility(),
        );
        var transparent = createServiceContainerWithDependencies(
          visibilityBehavior: TransparentVisibility(),
        );

        expect(
          () => opaque.getService<BookRepository>(),
          throwsA(isA<ServiceNotFoundError>()),
        );
        expect(transparent.getService<BookRepository>(), isA<BookRepository>());
      },
    );
  });
}
