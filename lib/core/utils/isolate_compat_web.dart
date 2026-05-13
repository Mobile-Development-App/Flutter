import 'dart:async';

typedef WorkerEntryPoint<T> = void Function(T message);

class WorkerSendPort {
  const WorkerSendPort();

  void send(Object? message) {
    throw UnsupportedError('Isolates are not supported on web.');
  }
}

class WorkerReceivePort {
  WorkerReceivePort();

  final _controller = StreamController<Object?>.broadcast();

  WorkerSendPort get sendPort => const WorkerSendPort();
  Future<Object?> get first => _controller.stream.first;

  StreamSubscription<Object?> listen(
    void Function(Object? event)? onData,
  ) {
    return _controller.stream.listen(onData);
  }

  void close() {
    _controller.close();
  }
}

class WorkerIsolate {
  const WorkerIsolate();

  void kill({Object? priority}) {}
}

const int isolateImmediate = 0;

WorkerReceivePort newReceivePort() => WorkerReceivePort();

Future<WorkerIsolate> spawnWorker<T>(
  WorkerEntryPoint<T> entryPoint,
  T message, {
  String? debugName,
}) {
  throw UnsupportedError('Isolates are not supported on web.');
}
