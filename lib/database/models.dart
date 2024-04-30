import 'dart:async';

class ModelHolder<T> {
  T? _content;
  Future<T?> Function() getModelInstance;
  bool getModelInstanceExecuted = false;
  ModelHolder({required this.getModelInstance, T? content}) {
    _content = content;
    getModelInstanceExecuted = content != null;
  }
  Future<T?> get instance async {
    if (getModelInstanceExecuted) return _content;
    return await getModelInstance();
  }
}
