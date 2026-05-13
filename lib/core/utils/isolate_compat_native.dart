import 'dart:isolate' as iso;

typedef WorkerEntryPoint<T> = void Function(T message);
typedef WorkerSendPort = iso.SendPort;
typedef WorkerReceivePort = iso.ReceivePort;
typedef WorkerIsolate = iso.Isolate;

const int isolateImmediate = iso.Isolate.immediate;

WorkerReceivePort newReceivePort() => iso.ReceivePort();

Future<WorkerIsolate> spawnWorker<T>(
  WorkerEntryPoint<T> entryPoint,
  T message, {
  String? debugName,
}) {
  return iso.Isolate.spawn<T>(
    entryPoint,
    message,
    debugName: debugName,
  );
}
