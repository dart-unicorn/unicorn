part of 'dependency_injection.dart';

class ServiceContainer implements IServiceContainer {
  ServiceContainer();

  final ServiceDescriptorCollection _descriptors =
      ServiceDescriptorCollection();

  final ServiceInstanceCollection _servicesInSingletonScope =
      ServiceInstanceCollection();

  @override
  void addService<TService, TServiceImplementation>({
    required ServiceLifetime lifetime,
    required ServiceFactoryFunc<TService> factory,
  }) {
    _descriptors.addDescriptor(
      serviceType: TService,
      serviceImplmenetationType: TServiceImplementation,
      lifetime: lifetime,
      factory: factory,
    );
  }

  @override
  TService getService<TService>() {
    var servicesInRequestScope = ServiceInstanceCollection();

    return _resolveInternal(
      TService,
      _servicesInSingletonScope,
      servicesInRequestScope,
    ) as TService;
  }

  dynamic _resolveInternal(
    Type serviceType,
    ServiceInstanceCollection servicesInSingletonScope,
    ServiceInstanceCollection servicesInRequestScope,
  ) {
    var descriptor = _requireServiceDescriptorByIdentifier(serviceType);

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

    var service =
        descriptor.createService(resolveSubRequest.toSubRequestContext());

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
