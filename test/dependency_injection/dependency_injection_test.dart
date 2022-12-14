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
  Scope scope = Scope.transient,
}) {
  container.registerService<BookRepository, BookRepository>(
    scope: scope,
    factory: (request) => BookRepository(),
  );
  container.registerService<StockService, StockService>(
    scope: scope,
    factory: (request) => StockService(request(BookRepository)),
  );
  container.registerService<BookStore, BookStore>(
    scope: scope,
    factory: (request) =>
        BookStore(request(BookRepository), request(StockService)),
  );
}

void main() {
  test("should resolve", () {
    var container = ServiceContainer();
    addDependencies(container);

    var bookStore = container.resolve<BookStore>();

    expect(bookStore, isA<BookStore>());
  });

  test("should throw ServiceNotFoundError", () {
    var container = ServiceContainer();

    container.registerService<BookRepository, BookRepository>(
      scope: Scope.transient,
      factory: (request) => BookRepository(),
    );
    container.registerService<BookStore, BookStore>(
      scope: Scope.transient,
      factory: (request) =>
          BookStore(request(BookRepository), request(StockService)),
    );

    expect(
      () => container.resolve<BookStore>(),
      throwsA(isA<ServiceNotFoundError>()),
    );
  });

  test("should resolve in transient scope", () {
    var container = ServiceContainer();
    addDependencies(container);

    var firstResolved = container.resolve<BookStore>();
    var secondResolved = container.resolve<BookStore>();

    expect(
      firstResolved,
      isNot(equals(secondResolved)),
    );
  });

  test("should resolve in singleton scope", () {
    var container = ServiceContainer();
    addDependencies(container, scope: Scope.singleton);

    var firstResolved = container.resolve<BookStore>();
    var secondResolved = container.resolve<BookStore>();

    expect(
      firstResolved,
      equals(secondResolved),
    );
  });

  test("should resolve in request scope", () {
    var container = ServiceContainer();
    addDependencies(container, scope: Scope.request);

    var firstResolved = container.resolve<BookStore>();
    var secondResolved = container.resolve<BookStore>();

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
