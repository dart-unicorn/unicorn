part of 'dependency_injection.dart';

enum ServiceLifetime {
  singleton,

  transient,

  request,
}

typedef AnyService = dynamic;

typedef ServiceFactoryFunc<T> = T Function(ISubRequestContext context);

abstract class IServiceCollection {
  void addService<TService, TServiceImplementation>({
    required ServiceLifetime lifetime,
    required ServiceFactoryFunc<TService> factory,
  });
}

abstract class IServiceProvider {
  TService getService<TService>();
}

abstract class IServiceContainer
    implements IServiceCollection, IServiceProvider {}

typedef SubRequestResolverFunc = AnyService Function(Type serviceType);

abstract class ISubRequestContext {
  TService require<TService>();
}
