/// Базовый use-case. Презентационный слой вызывает `.call(params)`.
///
/// Ошибки прокидываются через `throw Failure`/`Exception` и обрабатываются
/// в AsyncNotifier-ах через `AsyncValue.guard`.
abstract class UseCase<R, Params> {
  const UseCase();
  Future<R> call(Params params);
}

/// Маркер для use-case без параметров.
class NoParams {
  const NoParams();
}
