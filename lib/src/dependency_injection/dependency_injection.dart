import 'dart:collection';

typedef ServiceResolver<T> = T Function(Type target);

typedef ServiceFactory<T> = T Function(ServiceResolver<dynamic> resolve);

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

  final ServiceBindingCollection _serviceBindings = ServiceBindingCollection();

  final ServiceInstanceCollection _servicesInSingletonScope =
      ServiceInstanceCollection();

  @override
  void registerService<TServiceIdentifier, TServiceTarget>({
    required Scope scope,
    required ServiceFactory<TServiceIdentifier> factory,
  }) {
    _serviceBindings.add(
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
    var binding = _requireServiceBindingByIdentifier(type);

    if (binding.isInSingletonScope()) {
      var service = servicesInSingletonScope.getByBinding(binding);
      if (service != null) {
        return service.dartObject;
      }
    }
    if (binding.isInRequestScope()) {
      var service = servicesInRequestScope.getByBinding(binding);
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

    var service = binding.createServiceInstance(resolveSubRequest);

    if (binding.isInSingletonScope()) {
      servicesInSingletonScope.add(service);
    } else if (binding.isInRequestScope()) {
      servicesInRequestScope.add(service);
    }

    return service.dartObject;
  }

  ServiceBinding _requireServiceBindingByIdentifier(Type identifier) {
    var binding = _serviceBindings.getByIdentifier(identifier);
    if (binding == null) {
      throw ServiceNotFoundError.fromServiceIdentifier(identifier);
    }
    return binding;
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

class ServiceBindingCollection extends IterableBase<ServiceBinding> {
  ServiceBindingCollection();

  final List<ServiceBinding> _bindings = <ServiceBinding>[];

  @override
  Iterator<ServiceBinding> get iterator => _bindings.iterator;

  void add({
    required Type identifier,
    required Type target,
    required Scope scope,
    required ServiceFactory<dynamic> factory,
  }) {
    _bindings.add(ServiceBinding(identifier, target, scope, factory));
  }

  void remove(ServiceBinding binding) {
    _bindings.remove(binding);
  }

  ServiceBinding? getByIdentifier(Type identifier) {
    try {
      return _bindings
          .firstWhere((binding) => binding.identifier == identifier);
    } on StateError {
      return null;
    }
  }
}

class ServiceBinding {
  const ServiceBinding(
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

  ServiceInstance createServiceInstance(
    ServiceResolver<dynamic> resolver,
  ) {
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

  ServiceInstance? getByBinding(ServiceBinding binding) {
    try {
      return _services.firstWhere((service) => service.hasSameBinding(binding));
    } on StateError {
      return null;
    }
  }

  void removeByBinding(ServiceBinding binding) {
    _services.removeWhere((service) => service.hasSameBinding(binding));
  }
}

class ServiceInstance {
  const ServiceInstance(this.binding, this.dartObject);

  final ServiceBinding binding;

  final dynamic dartObject;

  static bool _hasSameBinding(ServiceBinding binding, ServiceBinding other) =>
      binding.identifier == other.identifier && binding.scope == binding.scope;

  bool hasSameBinding(ServiceBinding binding) =>
      _hasSameBinding(this.binding, binding);
}
