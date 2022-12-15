import 'package:unicorn/src/dependency_injection/dependency_injection.dart';

abstract class IModule {
  bool get global;

  Iterable<IModule> get imports;

  Iterable<Type> get exports;

  void configureServices(IServiceCollection services);
}

class ModuleMechanism {
  const ModuleMechanism._static();

  static ModuleContext compileModule(IModule module) {
    var compiler = ModuleCompiler(module);
    return compiler.compile();
  }
}

class ModuleCompiler {
  ModuleCompiler(this.module);

  final IModule module;

  ModuleContext compile() {
    return _compileEach(module);
  }

  ModuleContext _compileEach(IModule module) {
    return ModuleContext(
      module: module,
      imports: module.imports.map(_compileEach),
    );
  }
}

class ModuleContext {
  ModuleContext({
    required IModule module,
    required Iterable<ModuleContext> imports,
  })  : _module = module,
        _imports = imports;

  final IModule _module;

  IModule get module => _module;

  Type get moduleType => module.runtimeType;

  bool get global => module.global;

  Iterable<IModule> get importedModules => module.imports;

  Iterable<Type> get importedServices =>
      module.imports.expand((import) => import.exports);

  Iterable<Type> get exportedServices => module.exports;

  final Iterable<ModuleContext> _imports;

  Iterable<ModuleContext> get imports => _imports;

  bool isExportedService(Type serviceType) {
    return exportedServices.contains(serviceType);
  }

  bool isImportedService(Type serviceType) {
    return importedServices.contains(serviceType);
  }

  IServiceContainer configureAndCreateServiceContainer(
    ConfigureServiceContainerBuilderAction action,
  ) {
    final builder = ServiceContainerBuilder();

    for (var dependency in imports) {
      final container = dependency.configureAndCreateServiceContainer(action);
      builder.addUpstream(container.createUpstream());
    }

    builder.configureServices(
      (services) => module.configureServices(services),
    );
    builder.addService((service) {
      service
        ..bind<IModule>()
        ..implementationWithType(moduleType)
        ..inSingletonScope()
        ..useFactory((_) => module);
    });
    builder.addService((service) {
      service
        ..bind<ModuleContext>()
        ..implementation<ModuleContext>()
        ..inSingletonScope()
        ..useFactory((_) => this);
    });
    builder.visibilityBehavior(ModuleControlledVisibility(this));

    return builder.build();
  }
}

class ModuleControlledVisibility implements IServiceVisibilityBehavior {
  const ModuleControlledVisibility(
    ModuleContext owner,
  ) : _owner = owner;

  final ModuleContext _owner;

  final Iterable<Type> _bypassedServices = const [IModule, ModuleContext];

  bool _isBypassedService(Type serviceType) {
    return _bypassedServices.contains(serviceType);
  }

  ModuleContext _getOwnerFromServiceContainer(IServiceContainer container) {
    return container.getService<ModuleContext>();
  }

  ModuleContext _getOwnerFromRequest(ServiceRequestContext request) {
    return _getOwnerFromServiceContainer(request.originContainer);
  }

  bool _isRequiredFromSameModule(ServiceRequestContext request) {
    // each module is corresponds an unique container.
    return request.originContainer == request.delegatedContainer;
  }

  @override
  bool isVisibleFor(ServiceRequestContext request) {
    // DON'T touch this. This is critical, and may cause dead-loop.
    if (_isBypassedService(request.serviceType)) {
      return true;
    }

    if (_isRequiredFromSameModule(request)) {
      return true;
    }

    final actualOwner = _getOwnerFromRequest(request);
    if (actualOwner.isImportedService(request.serviceType)) {
      return true;
    }

    return false;
  }
}

extension ServiceContainerForModuleExtensions on IServiceContainer {
  IServiceContainer applyModuleSupportWithRootModule(ModuleContext module) {
    return module.configureAndCreateServiceContainer(
      (builder) {
        builder.addUpstream(createUpstream());
      },
    );
  }
}

typedef ConfigureServicesFunc = void Function(IServiceCollection);

class DynamicModuleBuilder {
  DynamicModuleBuilder._internal();

  factory DynamicModuleBuilder() => DynamicModuleBuilder._internal();

  bool _global = false;

  List<IModule> _imports = [];

  List<Type> _exports = [];

  ConfigureServicesFunc _configureServices = (_) {};

  void markAsGlobal() {
    _global = true;
  }

  void markAsLocal() {
    _global = false;
  }

  void withImports(Iterable<IModule> imports) {
    _imports = List.from(imports);
  }

  void addImport(IModule import) {
    _imports.add(import);
  }

  void addImports(Iterable<IModule> imports) {
    _imports.addAll(imports);
  }

  void withExports(Iterable<Type> exports) {
    _exports = List.from(exports);
  }

  void addExport(Type export) {
    _exports.add(export);
  }

  void addExports(Iterable<Type> exports) {
    _exports.addAll(exports);
  }

  void configureServices(
    ConfigureServicesFunc configureServices,
  ) {
    _configureServices = configureServices;
  }

  DynamicModule build() {
    _checkForBuild();

    return DynamicModule._internal(
      global: _global,
      imports: _imports,
      exports: _exports,
      configureServices: _configureServices,
    );
  }

  void _checkForBuild() {}
}

class DynamicModule implements IModule {
  const DynamicModule._internal({
    required this.global,
    required this.imports,
    required this.exports,
    required ConfigureServicesFunc configureServices,
  }) : _configureServices = configureServices;

  static DynamicModuleBuilder builder() => DynamicModuleBuilder();

  @override
  final bool global;

  @override
  final Iterable<IModule> imports;

  @override
  final Iterable<Type> exports;

  final ConfigureServicesFunc _configureServices;

  @override
  void configureServices(IServiceCollection services) {
    _configureServices(services);
  }
}
