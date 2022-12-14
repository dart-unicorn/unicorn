import 'dart:collection';

typedef AnyService = dynamic;

typedef ServiceResolver = AnyService Function(Type target);

typedef ServiceFactory<T> = T Function(ServiceResolver resolve);

abstract class IServiceContainer {
  void addService<TServiceType, TServiceImplementation>({
    required ServiceLifetime lifetime,
    required ServiceFactory<TServiceType> factory,
  });

  TServiceType resolve<TServiceType>();
}

enum ServiceLifetime {
  singleton,

  transient,

  request,
}

class ServiceContainer implements IServiceContainer {
  ServiceContainer();

  final ServiceDescriptorCollection _descriptors =
      ServiceDescriptorCollection();

  final ServiceInstanceCollection _servicesInSingletonScope =
      ServiceInstanceCollection();

  @override
  void addService<TServiceType, TServiceImplementation>({
    required ServiceLifetime lifetime,
    required ServiceFactory<TServiceType> factory,
  }) {
    _descriptors.add(
      serviceType: TServiceType,
      serviceImplmenetationType: TServiceImplementation,
      lifetime: lifetime,
      factory: factory,
    );
  }

  @override
  TServiceType resolve<TServiceType>() {
    var servicesInRequestScope = ServiceInstanceCollection();

    return _resolveInternal(
      TServiceType,
      _servicesInSingletonScope,
      servicesInRequestScope,
    ) as TServiceType;
  }

  dynamic _resolveInternal(
    Type type,
    ServiceInstanceCollection servicesInSingletonScope,
    ServiceInstanceCollection servicesInRequestScope,
  ) {
    var descriptor = _requireServiceDescriptorByIdentifier(type);

    if (descriptor.isInSingletonScope()) {
      var service = servicesInSingletonScope.getByDescriptor(descriptor);
      if (service != null) {
        return service.dartObject;
      }
    }
    if (descriptor.isInRequestScope()) {
      var service = servicesInRequestScope.getByDescriptor(descriptor);
      if (service != null) {
        return service.dartObject;
      }
    }

    dynamic resolveSubRequest(Type type) {
      return _resolveInternal(
        type,
        servicesInSingletonScope,
        servicesInRequestScope,
      );
    }

    var service = descriptor.createServiceInstance(resolveSubRequest);

    if (descriptor.isInSingletonScope()) {
      servicesInSingletonScope.add(service);
    } else if (descriptor.isInRequestScope()) {
      servicesInRequestScope.add(service);
    }

    return service.dartObject;
  }

  ServiceDescriptor _requireServiceDescriptorByIdentifier(Type identifier) {
    var descriptor = _descriptors.getByIdentifier(identifier);
    if (descriptor == null) {
      throw ServiceNotFoundError.fromServiceIdentifier(identifier);
    }
    return descriptor;
  }
}

class ServiceNotFoundError extends Error {
  ServiceNotFoundError(this.message);

  ServiceNotFoundError.fromServiceIdentifier(Type type)
      : this("service $type not found");

  final String message;

  @override
  String toString() {
    return message;
  }
}

class ServiceDescriptorCollection extends IterableBase<ServiceDescriptor> {
  ServiceDescriptorCollection();

  final List<ServiceDescriptor> _descriptors = <ServiceDescriptor>[];

  @override
  Iterator<ServiceDescriptor> get iterator => _descriptors.iterator;

  void add({
    required Type serviceType,
    required Type serviceImplmenetationType,
    required ServiceLifetime lifetime,
    required ServiceFactory<dynamic> factory,
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

  ServiceDescriptor? getByIdentifier(Type identifier) {
    try {
      return _descriptors
          .firstWhere((descriptor) => descriptor.serviceType == identifier);
    } on StateError {
      return null;
    }
  }
}

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

  final ServiceFactory<dynamic> factory;

  bool isInScope(ServiceLifetime lifetime) => this.lifetime == lifetime;

  bool isInSingletonScope() => isInScope(ServiceLifetime.singleton);

  bool isInTransientScope() => isInScope(ServiceLifetime.transient);

  bool isInRequestScope() => isInScope(ServiceLifetime.request);

  ServiceInstance createServiceInstance(ServiceResolver resolver) {
    var object = factory(resolver);

    return ServiceInstance(this, object);
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

extension ServiceContainerRegisterExtensions on IServiceContainer {
  void addTransient<TServiceType, TServiceImplementation>({
    required ServiceFactory<TServiceType> factory,
  }) {
    addService(lifetime: ServiceLifetime.transient, factory: factory);
  }

  void addSingleton<TServiceType, TServiceImplementation>({
    required ServiceFactory<TServiceType> factory,
  }) {
    addService(lifetime: ServiceLifetime.singleton, factory: factory);
  }
}
