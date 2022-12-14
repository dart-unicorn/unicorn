part of 'dependency_injection.dart';

class ServiceContainer implements IServiceContainer {
  ServiceContainer();

  final ServiceDescriptorCollection _descriptors =
      ServiceDescriptorCollection();

  final ServiceScope _singletonScope = ServiceScope();

  @override
  void addService<TService, TServiceImplementation>({
    required ServiceLifetime lifetime,
    required ServiceFactoryFunc<TService> factory,
  }) {
    if (_descriptors.containsByServiceType(TService)) {
      throw ServiceAlreadyAddedError.withServiceType(TService);
    }
    _descriptors.addDescriptor(
      serviceType: TService,
      serviceImplmenetationType: TServiceImplementation,
      lifetime: lifetime,
      factory: factory,
    );
  }

  @override
  TService getService<TService>() {
    var requestScope = ServiceScope();

    return _resolveInternal(
      TService,
      _singletonScope,
      requestScope,
    ) as TService;
  }

  dynamic _resolveInternal(
    Type serviceType,
    ServiceScope singletonScope,
    ServiceScope requestScope,
  ) {
    var serviceDescriptor = _requireServiceDescriptorByIdentifier(serviceType);

    if (serviceDescriptor.isInSingletonScope()) {
      var service = singletonScope.getByDescriptor(serviceDescriptor);
      if (service != null) {
        return service.runtimeObject;
      }
    }
    if (serviceDescriptor.isInRequestScope()) {
      var serviceObject = requestScope.getByDescriptor(serviceDescriptor);
      if (serviceObject != null) {
        return serviceObject.runtimeObject;
      }
    }

    dynamic resolveSubRequest(Type type) {
      return _resolveInternal(
        type,
        singletonScope,
        requestScope,
      );
    }

    var serviceObject = serviceDescriptor
        .createService(resolveSubRequest.toSubRequestContext());

    if (serviceDescriptor.isInSingletonScope()) {
      singletonScope.add(serviceObject);
    } else if (serviceDescriptor.isInRequestScope()) {
      requestScope.add(serviceObject);
    }

    return serviceObject.runtimeObject;
  }

  ServiceDescriptor _requireServiceDescriptorByIdentifier(Type identifier) {
    var descriptor = _descriptors.getByIdentifier(identifier);
    if (descriptor == null) {
      throw ServiceNotFoundError.withServiceType(identifier);
    }
    return descriptor;
  }
}

class DependencyInjectionError extends Error {
  DependencyInjectionError(this.message);

  final String message;

  @override
  String toString() {
    return message;
  }
}

class ServiceNotFoundError extends DependencyInjectionError {
  ServiceNotFoundError(String message) : super(message);

  factory ServiceNotFoundError.withServiceType(Type serviceType) =>
      ServiceNotFoundError("Service $serviceType not found in DI container");
}

class ServiceAlreadyAddedError extends DependencyInjectionError {
  ServiceAlreadyAddedError(String message) : super(message);

  factory ServiceAlreadyAddedError.withServiceType(Type type) =>
      ServiceAlreadyAddedError(
          "Service $type was already added into DI container");
}
