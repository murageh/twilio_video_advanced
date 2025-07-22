import 'dart:async';

class StreamGroup {
  static Stream<T> merge<T>(List<Stream<T>> streams) {
    late StreamController<T> controller;
    List<StreamSubscription<T>> subscriptions = [];

    controller = StreamController<T>(
      onListen: () {
        for (var stream in streams) {
          subscriptions.add(stream.listen(controller.add));
        }
      },
      onCancel: () {
        for (var subscription in subscriptions) {
          subscription.cancel();
        }
      },
    );

    return controller.stream;
  }
}
