class MotionVibrationService {
  MotionVibrationService._();
  static final MotionVibrationService shared = MotionVibrationService._();

  bool get isActive => false;

  Future<void> start() async {}

  Future<void> stop() async {}

  Future<void> vibrateOnAlert() async {}
}
