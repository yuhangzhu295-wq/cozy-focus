// The driver for the frame-time harness. Standard integration_test driver; the
// numbers come back through `binding.reportData`, which this writes out.
import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver();
