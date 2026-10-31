// Licensed under the Apache License, Version 2.0
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:otel_mercury/otel_mercury.dart';

/// Traces Mercury calls with OpenTelemetry.
///
/// `otel_mercury` depends on the OpenTelemetry API only, so the application
/// initializes an SDK once at startup. Wrap each Mercury call in
/// [tracedMercury]; the `invoke` callback makes the real call and reports what
/// came back, which is recorded on the span.
Future<void> main() async {
  await OTel.initialize(serviceName: 'mercury-example');

  // Wraps a Mercury API call in a CLIENT span.
  final mercuryId = await tracedMercury<String>(
    operation: 'accounts.transactions.send',
    invoke: () async {
      // Make the Mercury call here, then report what it returned.
      const id = 'mercury_8f3a2c';
      return const MercuryCallResult(
          value: id,
          result: MercuryResult(
              accountId: 'account_8f3a2c',
              transactionId: 'transaction_8f3a2c',
              paymentMethod: 'ach',
              kind: 'payment',
              status: 'pending',
              amountMinor: 1999,
              currency: 'usd',
              statusCode: 201));
    },
  );
  OTelLog.info('tracedMercury accounts.transactions.send returned $mercuryId');

  // Calls that should not be traced, such as health checks, run inside
  // runWithoutMercuryInstrumentationAsync.
  await runWithoutMercuryInstrumentationAsync(
    () => tracedMercury<String>(
      operation: 'accounts.transactions.send',
      invoke: () async {
        const id = 'mercury_8f3a2c';
        return const MercuryCallResult(
            value: id,
            result: MercuryResult(
                accountId: 'account_8f3a2c',
                transactionId: 'transaction_8f3a2c',
                paymentMethod: 'ach',
                kind: 'payment',
                status: 'pending',
                amountMinor: 1999,
                currency: 'usd',
                statusCode: 201));
      },
    ),
  );

  await OTel.shutdown();
}
