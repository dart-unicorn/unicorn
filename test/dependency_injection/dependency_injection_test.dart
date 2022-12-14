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
    factory: (request) => BookRepository(),
  );
  container.addService<StockService, StockService>(
    lifetime: lifetime,
    factory: (request) => StockService(request(BookRepository)),
  );
  container.addService<BookStore, BookStore>(
    lifetime: lifetime,
    factory: (request) =>
        BookStore(request(BookRepository), request(StockService)),
  );
}

void main() {
  test("should resolve", () {
    var container = ServiceContainer();
    addDependencies(container);

    var bookStore = container.getService<BookStore>();

    expect(bookStore, isA<BookStore>());
  });

  test("should throw ServiceNotFoundError", () {
    var container = ServiceContainer();

    container.addService<BookRepository, BookRepository>(
      lifetime: ServiceLifetime.transient,
      factory: (request) => BookRepository(),
    );
    container.addService<BookStore, BookStore>(
      lifetime: ServiceLifetime.transient,
      factory: (request) =>
          BookStore(request(BookRepository), request(StockService)),
    );

    expect(
      () => container.getService<BookStore>(),
      throwsA(isA<ServiceNotFoundError>()),
    );
  });

  test("should resolve in transient lifetime", () {
    var container = ServiceContainer();
    addDependencies(container);

    var firstResolved = container.getService<BookStore>();
    var secondResolved = container.getService<BookStore>();

    expect(
      firstResolved,
      isNot(equals(secondResolved)),
    );
  });

  test("should resolve in singleton lifetime", () {
    var container = ServiceContainer();
    addDependencies(container, lifetime: ServiceLifetime.singleton);

    var firstResolved = container.getService<BookStore>();
    var secondResolved = container.getService<BookStore>();

    expect(
      firstResolved,
      equals(secondResolved),
    );
  });

  test("should resolve in request lifetime", () {
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
  });
}
