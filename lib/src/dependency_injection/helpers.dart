part of 'dependency_injection.dart';

typedef ServiceFactoryFunc<T> = T Function(ISubRequestContext context);

class ServiceDescriptor {
  const ServiceDescriptor({
    required this.serviceType,
    required this.serviceImplementation,
    required this.lifetime,
    required this.factory,
  });

  final Type serviceType;

  final Type serviceImplementation;

  final ServiceLifetime lifetime;

  final ServiceFactoryFunc<dynamic> factory;

  bool shouldAddServiceIntoSingletonScope() =>
      lifetime == ServiceLifetime.singleton;

  bool shouldAddIntoTransientScope() => lifetime == ServiceLifetime.transient;

  bool shouldAddServiceIntoRequestScope() =>
      lifetime == ServiceLifetime.request;

  ServiceObject createService(ISubRequestContext resolver) {
    var object = factory(resolver);

    return ServiceObject(this, object);
  }
}

class ServiceDescriptorBuilder {
  late Type _serviceType;

  late Type? _serviceImplementation;

  late ServiceLifetime _lifetime;

  late ServiceFactoryFunc _factory;

  void bind<TService>() {
    _serviceType = TService;
  }

  void bindWithType(Type serviceType) {
    _serviceType = serviceType;
  }

  void implementation<TServiceImplementation>() {
    _serviceImplementation = TServiceImplementation;
  }

  void implementationWithType(Type serviceImplementation) {
    _serviceImplementation = serviceImplementation;
  }

  void inScope(ServiceLifetime lifetime) {
    _lifetime = lifetime;
  }

  void inTransientScope() {
    _lifetime = ServiceLifetime.transient;
  }

  void inSingletonScope() {
    _lifetime = ServiceLifetime.singleton;
  }

  void inRequestScope() {
    _lifetime = ServiceLifetime.request;
  }

  void useFactory<TService>(ServiceFactoryFunc<TService> factory) {
    _factory = factory;
  }

  ServiceDescriptor build() {
    _checkForBuild();

    return ServiceDescriptor(
      serviceType: _serviceType,
      serviceImplementation: _serviceImplementation ?? _serviceType,
      lifetime: _lifetime,
      factory: _factory,
    );
  }

  void _checkForBuild() {
    // Use `late` keyword to prevent misconfigure.
  }
}

typedef ServiceDescriptorBuildAction = void Function(
  ServiceDescriptorBuilder service,
);

class ServiceObject {
  const ServiceObject(this.descriptor, this.runtimeObject);

  final ServiceDescriptor descriptor;

  final dynamic runtimeObject;

  static bool _hasSameDescriptor(
    ServiceDescriptor descriptor,
    ServiceDescriptor other,
  ) =>
      (descriptor.serviceType == other.serviceType &&
          descriptor.lifetime == descriptor.lifetime);

  bool hasSameDescriptor(ServiceDescriptor descriptor) =>
      _hasSameDescriptor(this.descriptor, descriptor);
}

class ServiceCollection extends IterableBase<ServiceDescriptor>
    implements IServiceCollection {
  ServiceCollection();

  final List<ServiceDescriptor> _descriptors = <ServiceDescriptor>[];

  @override
  Iterator<ServiceDescriptor> get iterator => _descriptors.iterator;

  @override
  void add(ServiceDescriptor descriptor) {
    _descriptors.add(descriptor);
  }
}

class ServiceScope extends IterableBase<ServiceObject> {
  ServiceScope();

  final List<ServiceObject> _services = <ServiceObject>[];

  @override
  Iterator<ServiceObject> get iterator => _services.iterator;

  void addService(ServiceObject serviceObject) {
    _services.add(serviceObject);
  }

  void removeService(ServiceObject serviceObject) {
    _services.remove(serviceObject);
  }

  ServiceObject? tryGetService(ServiceDescriptor descriptor) {
    try {
      return _services
          .firstWhere((service) => service.hasSameDescriptor(descriptor));
    } on StateError {
      return null;
    }
  }

  void removeServiceByDescriptor(ServiceDescriptor descriptor) {
    _services.removeWhere((service) => service.hasSameDescriptor(descriptor));
  }
}

extension ServiceDescriptorBuildActionExtensions
    on ServiceDescriptorBuildAction {
  ServiceDescriptor buildServiceDescriptor() {
    final builder = ServiceDescriptorBuilder();
    this.call(builder);

    return builder.build();
  }
}

extension ServiceCollectionExtensions on IServiceCollection {
  void addService(ServiceDescriptorBuildAction action) {
    add(action.buildServiceDescriptor());
  }

  bool containsByServiceType(Type serviceType) {
    return any((descriptor) => descriptor.serviceType == serviceType);
  }

  ServiceDescriptor? tryGetByServiceType(Type serviceType) {
    try {
      return firstWhere((descriptor) => descriptor.serviceType == serviceType);
    } on StateError {
      return null;
    }
  }
}

extension ServiceContainerBuilderExtensions on IServiceContainerBuilder {
  void addService(ServiceDescriptorBuildAction action) {
    configureServices((services) {
      services.addService(action);
    });
  }

  void addUpstream(IServiceContainerUpstream upstream) {
    addUpstreams([upstream]);
  }
}

extension ServiceContainerExtensions on IServiceContainer {
  IServiceContainer withUpstream(IServiceContainerUpstream upstream) {
    return withUpstreams([upstream]);
  }

  IServiceContainer addUpstream(IServiceContainerUpstream upstream) {
    return addUpstreams([upstream]);
  }
}

class SubRequestResolverFuncAdpater implements ISubRequestContext {
  const SubRequestResolverFuncAdpater._internal(this._resolveSubRequest);

  factory SubRequestResolverFuncAdpater.fromFunc(
    SubRequestResolverFunc resolveSubRequest,
  ) =>
      SubRequestResolverFuncAdpater._internal(resolveSubRequest);

  final SubRequestResolverFunc _resolveSubRequest;

  @override
  TService require<TService>() {
    return _resolveSubRequest(TService);
  }
}
