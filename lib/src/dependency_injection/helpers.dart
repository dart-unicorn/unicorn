part of 'dependency_injection.dart';

class ServiceDescriptor {
  const ServiceDescriptor(
    this.serviceType,
    this.serviceImplementationType,
    this.lifetime,
    this.factory,
  );

  final Type serviceType;

  final Type serviceImplementationType;

  final ServiceLifetime lifetime;

  final ServiceFactoryFunc<dynamic> factory;

  bool isInScope(ServiceLifetime lifetime) => this.lifetime == lifetime;

  bool isInSingletonScope() => isInScope(ServiceLifetime.singleton);

  bool isInTransientScope() => isInScope(ServiceLifetime.transient);

  bool isInRequestScope() => isInScope(ServiceLifetime.request);

  ServiceInstance createService(ISubRequestContext resolver) {
    var object = factory(resolver);

    return ServiceInstance(this, object);
  }
}

class ServiceInstance {
  const ServiceInstance(this.descriptor, this.dartObject);

  final ServiceDescriptor descriptor;

  final dynamic dartObject;

  static bool _hasSameDescriptor(
    ServiceDescriptor descriptor,
    ServiceDescriptor other,
  ) =>
      (descriptor.serviceType == other.serviceType &&
          descriptor.lifetime == descriptor.lifetime);

  bool hasSameDescriptor(ServiceDescriptor descriptor) =>
      _hasSameDescriptor(this.descriptor, descriptor);
}

class ServiceDescriptorCollection extends IterableBase<ServiceDescriptor> {
  ServiceDescriptorCollection();

  final List<ServiceDescriptor> _descriptors = <ServiceDescriptor>[];

  @override
  Iterator<ServiceDescriptor> get iterator => _descriptors.iterator;

  void addDescriptor({
    required Type serviceType,
    required Type serviceImplmenetationType,
    required ServiceLifetime lifetime,
    required ServiceFactoryFunc<dynamic> factory,
  }) {
    _descriptors.add(ServiceDescriptor(
      serviceType,
      serviceImplmenetationType,
      lifetime,
      factory,
    ));
  }

  void remove(ServiceDescriptor descriptor) {
    _descriptors.remove(descriptor);
  }

  bool anyHasServiceType(Type serviceType) {
    return _descriptors
        .any((descriptor) => descriptor.serviceType == serviceType);
  }

  ServiceDescriptor? getByIdentifier(Type identifier) {
    try {
      return _descriptors
          .firstWhere((descriptor) => descriptor.serviceType == identifier);
    } on StateError {
      return null;
    }
  }
}

class ServiceInstanceCollection extends IterableBase<dynamic> {
  ServiceInstanceCollection();

  final List<ServiceInstance> _services = <ServiceInstance>[];

  @override
  Iterator get iterator => _services.iterator;

  void add(ServiceInstance instance) {
    _services.add(instance);
  }

  void remove(ServiceInstance service) {
    _services.remove(service);
  }

  ServiceInstance? getByDescriptor(ServiceDescriptor descriptor) {
    try {
      return _services
          .firstWhere((service) => service.hasSameDescriptor(descriptor));
    } on StateError {
      return null;
    }
  }

  void removeByDescriptor(ServiceDescriptor descriptor) {
    _services.removeWhere((service) => service.hasSameDescriptor(descriptor));
  }
}

extension ServiceRegistrarExtensions on IServiceCollection {
  void addTransient<TService, TServiceImplementation>({
    required ServiceFactoryFunc<TService> factory,
  }) {
    addService(lifetime: ServiceLifetime.transient, factory: factory);
  }

  void addSingleton<TService, TServiceImplementation>({
    required ServiceFactoryFunc<TService> factory,
  }) {
    addService(lifetime: ServiceLifetime.singleton, factory: factory);
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

// TODO(coocoa): This is a temporary solution and unstable. Consider to be
//  removed in the future.
extension SubRequestResolverFuncExtensions on SubRequestResolverFunc {
  ISubRequestContext toSubRequestContext() =>
      SubRequestResolverFuncAdpater.fromFunc(this);
}
