import 'package:test/test.dart';
import 'package:unicorn/src/dependency_injection/dependency_injection.dart';
import 'package:unicorn/src/modular/modular.dart';

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

class BookStoreModule implements IModule {
  const BookStoreModule();

  @override
  bool get global => false;

  @override
  Iterable<IModule> get imports => const [];

  @override
  Iterable<Type> get exports => const [BookStore];

  @override
  void configureServices(IServiceCollection services) {
    services
      ..addService((service) {
        service
          ..bind<BookStore>()
          ..implementation<BookStore>()
          ..inTransientScope()
          ..useFactory((c) => BookStore(c.require(), c.require()));
      })
      ..addService((service) {
        service
          ..bind<StockService>()
          ..implementation<StockService>()
          ..inTransientScope()
          ..useFactory((c) => StockService(c.require()));
      })
      ..addService((service) {
        service
          ..bind<BookRepository>()
          ..implementation<BookRepository>()
          ..inTransientScope()
          ..useFactory((c) => BookRepository());
      });
  }
}

class WithTransitiveExportedDependency {
  WithTransitiveExportedDependency(BookStore bookStore);
}

class WithTransitiveUnexportedDependency {
  WithTransitiveUnexportedDependency(BookRepository bookRepository);
}

class TransitiveDependencyModule implements IModule {
  const TransitiveDependencyModule();

  @override
  bool get global => false;

  @override
  Iterable<IModule> get imports => const [
        BookStoreModule(),
      ];

  @override
  Iterable<Type> get exports => const [
        WithTransitiveExportedDependency,
        WithTransitiveUnexportedDependency,
      ];

  @override
  void configureServices(IServiceCollection services) {
    services.addService((service) {
      service
        ..bind<WithTransitiveUnexportedDependency>()
        ..implementation<WithTransitiveUnexportedDependency>()
        ..inTransientScope()
        ..useFactory((c) => WithTransitiveUnexportedDependency(c.require()));
    });
    services.addService((service) {
      service
        ..bind<WithTransitiveExportedDependency>()
        ..implementation<WithTransitiveExportedDependency>()
        ..inTransientScope()
        ..useFactory((c) => WithTransitiveExportedDependency(c.require()));
    });
  }
}

class AppModule implements IModule {
  const AppModule();

  @override
  bool get global => false;

  @override
  Iterable<IModule> get imports => const [BookStoreModule()];

  @override
  Iterable<Type> get exports => const [];

  @override
  void configureServices(IServiceCollection services) {}
}

void main() {
  group("module mechanism", () {
    test("should compile with correct dependency relationship", () {
      var module = AppModule();
      var compiler = ModuleCompiler(module);
      var context = compiler.compile();

      expect(
        context.imports.map((dependency) => dependency.module.runtimeType),
        equals(module.imports.map((dependency) => dependency.runtimeType)),
      );
    });

    group("dependency injection", () {
      test(
        "should resolve a service that exported in module",
        () {
          IServiceContainer container = ServiceContainerBuilder().build();
          var module = ModuleMechanism.compileModule(BookStoreModule());

          container = container.applyModuleSupportWithRootModule(module);

          expect(container.getService<BookStore>(), isA<BookStore>());
        },
      );

      test(
        "should throw ServiceNotFoundError if the service was not exported in module",
        () {
          IServiceContainer container = ServiceContainerBuilder().build();
          var module = ModuleMechanism.compileModule(AppModule());

          container = container.applyModuleSupportWithRootModule(module);

          expect(
            () => container.getService<BookRepository>(),
            throwsA(isA<ServiceNotFoundError>()),
          );
        },
      );

      test(
        "should resolve a service if the service transitively depends on an exported service",
        () {
          IServiceContainer container = ServiceContainerBuilder().build();
          var module =
              ModuleMechanism.compileModule(TransitiveDependencyModule());

          container = container.applyModuleSupportWithRootModule(module);

          expect(
            container.getService<WithTransitiveExportedDependency>(),
            isA<WithTransitiveExportedDependency>(),
          );
        },
      );

      test(
        "should throw ServiceNotFoundError if a service transitively depends on an unexported service",
        () {
          IServiceContainer container = ServiceContainerBuilder().build();
          var module =
              ModuleMechanism.compileModule(TransitiveDependencyModule());

          container = container.applyModuleSupportWithRootModule(module);

          expect(
            () => container.getService<WithTransitiveUnexportedDependency>(),
            throwsA(isA<ServiceNotFoundError>()),
          );
        },
      );
    });
  });
}
