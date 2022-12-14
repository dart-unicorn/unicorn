part of 'dependency_injection.dart';

enum ServiceLifetime {
  singleton,

  transient,

  request,
}

typedef AnyService = dynamic;

abstract class IServiceCollection implements Iterable<ServiceDescriptor> {
  void add(ServiceDescriptor descriptor);
}

abstract class IServiceProvider {
  TService getService<TService>();
}

typedef ConfigureServiceContainerBuilderAction = void Function(
  IServiceContainerBuilder builder,
);

typedef ConfigureServicesAction = void Function(IServiceCollection services);

abstract class IServiceContainerBuilder<TServiceContainer> {
  void addUpstreams(Iterable<IServiceContainerUpstream> upstreams);

  void configureServices(ConfigureServicesAction action);

  void visibilityBehavior(IServiceVisibilityBehavior visibilityBehavior);

  TServiceContainer build();
}

abstract class IServiceContainer implements IServiceProvider {
  IServiceCollection get services;

  IServiceContainerUpstream createUpstream();

  IServiceContainer withUpstreams(
    Iterable<IServiceContainerUpstream> upstreams,
  );

  IServiceContainer addUpstreams(
    Iterable<IServiceContainerUpstream> upstreams,
  );

  AnyService getServiceByType(Type serviceType);

  AnyService getServiceForServiceRequest(ServiceRequestContext request);
}

abstract class IServiceContainerUpstream {
  IServiceContainer? tryGetServiceContainerForServiceRequest(
    ServiceRequestContext request,
  );
}

abstract class IServiceVisibilityBehavior {
  bool isVisibleFor(ServiceRequestContext request);
}

class TransparentVisibility implements IServiceVisibilityBehavior {
  const TransparentVisibility();

  @override
  bool isVisibleFor(ServiceRequestContext request) {
    return true;
  }
}

typedef SubRequestResolverFunc = AnyService Function(Type serviceType);

abstract class ISubRequestContext {
  TService require<TService>();
}
