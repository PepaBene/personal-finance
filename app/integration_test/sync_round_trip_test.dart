// Phase 0 vertical-slice integration test (scaffold).
//
// The exit criteria (docs/08, docs/13 §13) require proving a transaction
// round-trips: created on device A, encrypted locally, and converging on device
// B via PowerSync. That needs a live (or local) Supabase + PowerSync stack and
// two authenticated clients, so it runs against a configured test backend
// rather than in the unit-test job.
//
// This file documents the intended assertions and keeps the integration_test
// harness wired; the live two-device assertion is enabled once a test backend
// is provisioned (supabase/README.md).

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 0 vertical slice', () {
    testWidgets(
      'create a transaction offline → it converges on a second device',
      (tester) async {
        // TODO(phase0): with a configured test backend —
        //   1. sign in client A, unlock, create one transaction;
        //   2. assert it persists to the local encrypted DB;
        //   3. sign in client B with the same account;
        //   4. assert the transaction appears within a few seconds (FR-SYNC-05);
        //   5. go offline, edit on A, reconnect, assert convergence (LWW).
      },
      skip: true,
    );
  });
}
