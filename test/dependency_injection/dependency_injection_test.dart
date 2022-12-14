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

void addDependencies(
  ServiceContainer container, {
  ServiceLifetime lifetime = ServiceLifetime.transient,
}) {
  container.addService<BookRepository, BookRepository>(
    lifetime: lifetime,
    factory: (_) => BookRepository(),
  );
  container.addService<StockService, StockService>(
    lifetime: lifetime,
    factory: (r) => StockService(r.require<BookRepository>()),
  );
  container.addService<BookStore, BookStore>(
    lifetime: lifetime,
    factory: (r) => BookStore(
      r.require<BookRepository>(),
      r.require<StockService>(),
    ),
  );
}

void main() {
  group("dependency injection", () {
    test("should resolve a service without dependencies", () {
      var container = ServiceContainer();
      addDependencies(container);

      var bookStore = container.getService<BookRepository>();

      expect(bookStore, isA<BookRepository>());
    });

    test("should resolve a service with its dependencies", () {
      var container = ServiceContainer();
      addDependencies(container);

      var bookStore = container.getService<BookStore>();

      expect(bookStore, isA<BookStore>());
    });

    test(
      "should throw ServiceAlreadyAddedError if a service was already added",
      () {
        var container = ServiceContainer();
        container.addService<BookRepository, BookRepository>(
          lifetime: ServiceLifetime.transient,
          factory: (_) => BookRepository(),
        );

        expect(
          () {
            container.addService<BookRepository, BookRepository>(
              lifetime: ServiceLifetime.transient,
              factory: (_) => BookRepository(),
            );
          },
          throwsA(isA<ServiceAlreadyAddedError>()),
        );
      },
    );

    test(
      "should throw ServiceNotFoundError if the service is not added",
      () {
        var container = ServiceContainer();

        container.addService<BookRepository, BookRepository>(
          lifetime: ServiceLifetime.transient,
          factory: (request) => BookRepository(),
        );
        container.addService<BookStore, BookStore>(
          lifetime: ServiceLifetime.transient,
          factory: (r) => BookStore(
            r.require<BookRepository>(),
            r.require<StockService>(),
          ),
        );

        expect(
          () => container.getService<BookStore>(),
          throwsA(isA<ServiceNotFoundError>()),
        );
      },
    );

    test(
      "should resolve a service with transient lifetime",
      () {
        var container = ServiceContainer();
        addDependencies(container);

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
        var container = ServiceContainer();
        addDependencies(container, lifetime: ServiceLifetime.singleton);

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
        var container = ServiceContainer();
        addDependencies(container, lifetime: ServiceLifetime.request);

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
  });
}
