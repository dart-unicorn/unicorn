import 'dart:collection';

typedef AnyService = dynamic;

typedef ServiceResolver = AnyService Function(Type target);

typedef ServiceFactory<T> = T Function(ServiceResolver resolve);

abstract class IServiceContainer {
  void registerService<TServiceIdentifier, TServiceTarget>({
    required Scope scope,
    required ServiceFactory<TServiceIdentifier> factory,
  });

  TServiceIdentifier resolve<TServiceIdentifier>();
}

enum Scope {
  singleton,

  transient,

  request,
}

class ServiceContainer implements IServiceContainer {
  ServiceContainer();

  final ServiceDescriptorCollection _serviceDescriptors =
      ServiceDescriptorCollection();

  final ServiceInstanceCollection _servicesInSingletonScope =
      ServiceInstanceCollection();

  @override
  void registerService<TServiceIdentifier, TServiceTarget>({
    required Scope scope,
    required ServiceFactory<TServiceIdentifier> factory,
  }) {
    _serviceDescriptors.add(
      identifier: TServiceIdentifier,
      target: TServiceTarget,
      scope: scope,
      factory: factory,
    );
  }

  @override
  TServiceIdentifier resolve<TServiceIdentifier>() {
    var servicesInRequestScope = ServiceInstanceCollection();

    return _resolveInternal(
      TServiceIdentifier,
      _servicesInSingletonScope,
      servicesInRequestScope,
    ) as TServiceIdentifier;
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
    var descriptor = _serviceDescriptors.getByIdentifier(identifier);
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
    required Type identifier,
    required Type target,
    required Scope scope,
    required ServiceFactory<dynamic> factory,
  }) {
    _descriptors.add(ServiceDescriptor(identifier, target, scope, factory));
  }

  void remove(ServiceDescriptor descriptor) {
    _descriptors.remove(descriptor);
  }

  ServiceDescriptor? getByIdentifier(Type identifier) {
    try {
      return _descriptors
          .firstWhere((descriptor) => descriptor.identifier == identifier);
    } on StateError {
      return null;
    }
  }
}

class ServiceDescriptor {
  const ServiceDescriptor(
    this.identifier,
    this.target,
    this.scope,
    this.factory,
  );

  final Type identifier;

  final Type target;

  final Scope scope;

  final ServiceFactory<dynamic> factory;

  bool isInScope(Scope scope) => this.scope == scope;

  bool isInSingletonScope() => isInScope(Scope.singleton);

  bool isInTransientScope() => isInScope(Scope.transient);

  bool isInRequestScope() => isInScope(Scope.request);

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
      (descriptor.identifier == other.identifier &&
          descriptor.scope == descriptor.scope);

  bool hasSameDescriptor(ServiceDescriptor descriptor) =>
      _hasSameDescriptor(this.descriptor, descriptor);
}
