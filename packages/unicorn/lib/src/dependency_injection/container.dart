part of 'dependency_injection.dart';

class ServiceContainerBuilder
    implements IServiceContainerBuilder<ServiceContainer> {
  ServiceContainerBuilder();

  // ignore: prefer_final_fields
  List<IServiceContainerUpstream> _upstreams = [];

  // ignore: prefer_final_fields
  IServiceCollection _services = ServiceCollection();

  IServiceVisibilityBehavior? _visibilityBehavior;

  @override
  void addUpstreams(Iterable<IServiceContainerUpstream> upstreams) {
    _upstreams.addAll(upstreams);
  }

  @override
  void configureServices(ConfigureServicesAction action) {
    action.call(_services);
  }

  @override
  void visibilityBehavior(IServiceVisibilityBehavior visibilityBehavior) {
    _visibilityBehavior = visibilityBehavior;
  }

  @override
  ServiceContainer build() {
    return ServiceContainer._internal(
      upstreams: _upstreams,
      services: _services,
      visibilityBehavior: _visibilityBehavior,
    );
  }
}

class ServiceContainer implements IServiceContainer, IServiceContainerUpstream {
  ServiceContainer._internal({
    required IServiceCollection services,
    Iterable<IServiceContainerUpstream>? upstreams,
    IServiceVisibilityBehavior? visibilityBehavior,
  })  : _services = services,
        _upstreams = upstreams ?? const [],
        _visibilityBehavior =
            visibilityBehavior ?? const TransparentVisibility();

  final IServiceCollection _services;

  final Iterable<IServiceContainerUpstream> _upstreams;

  final IServiceVisibilityBehavior _visibilityBehavior;

  final ServiceScope _singletonScope = ServiceScope();

  @override
  IServiceCollection get services => _services;

  @override
  IServiceContainerUpstream createUpstream() => this;

  @override
  IServiceContainer withUpstreams(
    Iterable<IServiceContainerUpstream> upstreams,
  ) {
    return ServiceContainer._internal(
      services: _services,
      upstreams: upstreams,
      visibilityBehavior: _visibilityBehavior,
    );
  }

  @override
  IServiceContainer addUpstreams(
      Iterable<IServiceContainerUpstream> upstreams) {
    return withUpstreams(_upstreams.followedBy(upstreams));
  }

  @override
  TService getService<TService>() {
    return getServiceByType(TService);
  }

  ServiceRequestContext _createServiceRequest(Type serviceType) {
    return ServiceRequestContext.create(
      serviceType: serviceType,
      singletonScope: _singletonScope,
      container: this,
    );
  }

  @override
  AnyService getServiceByType(Type serviceType) {
    final request = _createServiceRequest(serviceType);
    return getServiceForServiceRequest(request);
  }

  @override
  IServiceContainer? tryGetServiceContainerForServiceRequest(
    ServiceRequestContext request,
  ) {
    if (_services.tryGetByServiceType(request.serviceType) != null) {
      return this;
    }

    for (var upstream in _upstreams) {
      final container =
          upstream.tryGetServiceContainerForServiceRequest(request);
      if (container != null) {
        return container;
      }
    }
    return null;
  }

  @override
  AnyService getServiceForServiceRequest(ServiceRequestContext request) {
    return _dispatchAndGetServiceForServiceRequest(request);
  }

  AnyService _dispatchAndGetServiceForServiceRequest(
    ServiceRequestContext request,
  ) {
    final delegatedContainer = tryGetServiceContainerForServiceRequest(request);
    if (delegatedContainer == null) {
      throw ServiceNotFoundError.withServiceType(request.serviceType);
    }

    // If the delegated container is still this, process the request directly.
    //
    // TODO(coocoa): There may be a mistake of abstraction. It seems
    //  causing a dead-lock (at least it is hard to understand) and a
    //  tricky was used a tricky to solve the problem. Consider redesigning
    //  it in the future.
    if (delegatedContainer == this) {
      return _getServiceForServiceRequestInternal(request);
    }

    final delegatedRequest =
        request.delegateToOtherServiceContainer(delegatedContainer);
    return delegatedContainer.getServiceForServiceRequest(delegatedRequest);
  }

  AnyService _getServiceForServiceRequestInternal(
    ServiceRequestContext request,
  ) {
    if (!_visibilityBehavior.isVisibleFor(request)) {
      throw ServiceNotFoundError.withServiceType(request.serviceType);
    }

    final descriptor = _services.tryGetByServiceType(request.serviceType);
    if (descriptor == null) {
      throw ServiceNotFoundError.withServiceType(request.serviceType);
    }

    if (descriptor.shouldAddServiceIntoSingletonScope()) {
      final serviceObject = request.tryGetServiceFromSingletonScope(descriptor);
      if (serviceObject != null) {
        return serviceObject.runtimeObject;
      }
    }
    if (descriptor.shouldAddServiceIntoRequestScope()) {
      final serviceObject = request.tryGetServiceFromRequestScope(descriptor);
      if (serviceObject != null) {
        return serviceObject.runtimeObject;
      }
    }

    AnyService getServiceForSubRequest(Type serviceType) {
      final subRequest = request.createSubRequest(
        serviceType: serviceType,
        container: this,
      );

      return getServiceForServiceRequest(subRequest);
    }

    final serviceObject = descriptor.createService(
      SubRequestResolverFuncAdpater.fromFunc(getServiceForSubRequest),
    );

    if (descriptor.shouldAddServiceIntoSingletonScope()) {
      request.addServiceIntoSingletonScope(serviceObject);
    } else if (descriptor.shouldAddServiceIntoRequestScope()) {
      request.addServiceIntoRequestScope(serviceObject);
    }

    return serviceObject.runtimeObject;
  }
}

class ServiceRequestContext {
  const ServiceRequestContext._internal({
    required this.serviceType,
    required this.singletonScope,
    required this.requestScope,
    required this.delegatedContainer,
    required this.originContainer,
    this.previous,
  });

  factory ServiceRequestContext.create({
    required Type serviceType,
    required ServiceScope singletonScope,
    required IServiceContainer container,
  }) =>
      ServiceRequestContext._internal(
        serviceType: serviceType,
        singletonScope: singletonScope,
        requestScope: ServiceScope(),
        delegatedContainer: container,
        originContainer: container,
      );

  final ServiceRequestContext? previous;

  final Type serviceType;

  final ServiceScope singletonScope;

  final ServiceScope requestScope;

  final IServiceContainer delegatedContainer;

  final IServiceContainer originContainer;

  ServiceRequestContext createSubRequest({
    required Type serviceType,
    required IServiceContainer container,
  }) {
    return ServiceRequestContext._internal(
      previous: this,
      serviceType: serviceType,
      singletonScope: singletonScope,
      requestScope: requestScope,
      delegatedContainer: container,
      originContainer: container,
    );
  }

  bool isSubRequest() => previous != null;

  ServiceRequestContext delegateToOtherServiceContainer(
    IServiceContainer delegatedContainer,
  ) {
    return ServiceRequestContext._internal(
      previous: previous,
      serviceType: serviceType,
      singletonScope: singletonScope,
      requestScope: requestScope,
      delegatedContainer: delegatedContainer,
      originContainer: originContainer,
    );
  }

  ServiceObject? tryGetServiceFromSingletonScope(
    ServiceDescriptor descriptor,
  ) {
    return singletonScope.tryGetService(descriptor);
  }

  ServiceObject? tryGetServiceFromRequestScope(ServiceDescriptor descriptor) {
    return requestScope.tryGetService(descriptor);
  }

  void addServiceIntoSingletonScope(ServiceObject serviceObject) {
    singletonScope.addService(serviceObject);
  }

  void addServiceIntoRequestScope(ServiceObject serviceObject) {
    requestScope.addService(serviceObject);
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
